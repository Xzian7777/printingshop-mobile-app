import '../services/loyalty_api.dart';
import '../services/app_notifications.dart';
import '../services/store_price.dart';
import '../services/order_number_input_formatter.dart';
import '../widgets/store_checkout_sheet.dart';
import '../widgets/store_product_card.dart';
import '../services/order_validation.dart';
import '../theme/dashboard_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/order_workflow.dart' show inventoryPlan;
import '../services/order_reference.dart';
import 'admin_catalog_view.dart' show sharedImage;
import '../services/profile_directory.dart';
import '../services/admin_repository.dart';
import '../services/supabase_storage_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'product_detail_screen.dart';

class StoreScreen extends StatefulWidget {
  final bool isAdmin;
  final String userEmail;

  const StoreScreen({
    super.key,
    this.isAdmin = false,
    this.userEmail = 'Guest Customer',
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String? _loyaltyKey;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final Map<String, int> _cart = {};
  late final Stream<List<ProfileRecord>> _productsStream = watchProducts();
  List<ProfileRecord> _allDocs = [];

  // --- PAGINATION STATE ---
  int _currentPage = 1;
  final int _itemsPerPage = 6;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _cartTotalItems => _cart.values.fold(0, (acc, qty) => acc + qty);

  // --- PLACE ORDER TO FIRESTORE ---
  Future<void> _checkoutCart(
      BuildContext bottomSheetCtx,
      List<MapEntry<String, int>> cartEntries,
      double total,
      StorePaymentDetails payment) async {
    if (widget.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Only customer accounts can place orders. Please use POS for counter sales."),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      Navigator.pop(bottomSheetCtx);
      return;
    }
    final paymentIssue =
        OrderValidation.validatePayment(payment.method, payment.reference);
    if (paymentIssue != null) throw StateError(paymentIssue);
    inventoryPlan({
      'items': cartEntries.map((e) => {'id': e.key, 'qty': e.value}).toList()
    }, {
      for (final doc in _allDocs) doc.id: doc.data()
    });
    // 1. Verify items and live stock before placing order
    final itemsToOrder = <Map<String, dynamic>>[];
    for (final entry in cartEntries) {
      final prodDoc = _allDocs.firstWhere(
        (d) => d.id == entry.key,
        orElse: () => throw Exception("Product ${entry.key} not found"),
      );
      final data = prodDoc.data();
      final currentStock = (data['stock'] as num?)?.toInt() ?? 0;
      final name = (data['name'] ?? 'Product').toString();
      final price = storePrice(data['price']);
      if (price == null)
        throw StateError('The price for $name must be updated by the shop.');

      if (currentStock < entry.value) {
        throw Exception(
            "Insufficient stock for '$name'. Available: $currentStock, Ordered: ${entry.value}");
      }

      itemsToOrder.add({
        'id': entry.key,
        'productId': entry.key,
        'name': name,
        'qty': entry.value,
        'price': price,
      });
    }

    final now = DateTime.now();
    var orderId = generateOrderReference();
    final emailClean = widget.userEmail.trim();
    final customerName =
        emailClean.contains('@') ? emailClean.split('@')[0] : emailClean;
    final itemDescriptions =
        itemsToOrder.map((i) => "${i['name']} (${i['qty']}x)").join(', ');
    final totalCopies =
        itemsToOrder.fold<int>(0, (acc, i) => acc + (i['qty'] as int));
    final currentTotal = itemsToOrder.fold<double>(0,
        (sum, item) => sum + (item['price'] as double) * (item['qty'] as int));
    if (!currentTotal.isFinite || currentTotal <= 0 || currentTotal > 5000000) {
      throw StateError(
          'The order total must be greater than zero and at most 5,000,000.');
    }
    if ((currentTotal - total).abs() > 0.01) {
      throw StateError(
          'Store prices changed. Reopen your cart to review the current total.');
    }

    final orderPayload = {
      'id': orderId,
      'submissionId': _db.collection('orders').doc().id,
      'customerId': FirebaseAuth.instance.currentUser?.uid ?? emailClean,
      'customer': customerName,
      'email': emailClean.contains('@') ? emailClean : '$emailClean@gmail.com',
      'service': 'In-Store: $itemDescriptions',
      'items': itemsToOrder,
      'pages': 1,
      'copies': totalCopies,
      'quantity': totalCopies,
      'paperSize': 'Store Supply',
      'colorMode': 'N/A',
      'sides': 'N/A',
      'total': total,
      'file': 'Store_Receipt.pdf',
      'payment': payment.method,
      'gcashRef': payment.reference,
      'gcashReceiptUrl': payment.receipt == null
          ? ''
          : await SupabaseStorageService.uploadFile(
              file: payment.receipt!,
              originalFilename: payment.receiptName,
              orderId: orderId),
      'merchantAccountNumber': payment.merchantAccount,
      'status': 'Order Submitted',
      'stockDeducted': false,
      'createdAt': now.toIso8601String(),
      'orderDate': "${_formatMonthDayYear(now)} • ${_formatHourMinute(now)}",
    };

    // Write to shared orders collection: artifacts/printcraft-pro/public/data/orders
    final orderRef = _db
        .collection('artifacts')
        .doc('printcraft-pro')
        .collection('public')
        .doc('data')
        .collection('orders')
        .doc(orderId);
    if (payment.pointsUsed > 0) {
      _loyaltyKey ??= LoyaltyApi.submissionId();
      final saved = await LoyaltyApi.submitOrder({...orderPayload, 'submissionId': _loyaltyKey, 'pointsUsed': payment.pointsUsed, 'expectedDiscount': payment.pointsDiscount});
      orderId = saved['orderId'];
      _loyaltyKey = null;
    } else {
    await _db.runTransaction((transaction) async {
      if (payment.method == 'GCash') {
        final merchant = await transaction
            .get(_db.collection('settings').doc('gcash_config'));
        if (merchant.data()?['isActive'] == false ||
            merchant.data()?['accountNumber'] != payment.merchantAccount) {
          throw StateError(
              'GCash details changed. Review the current merchant account before ordering.');
        }
      }
      final existing = await transaction.get(orderRef);
      if (existing.exists) {
        throw StateError(
            'Order reference already exists. Please retry to generate a new reference.');
      }
      transaction.set(orderRef, orderPayload);
      addNewOrderNotification(transaction, _db, orderRef.id, orderPayload);
    });
    }

    if (!mounted) return;
    setState(() => _cart.clear());
    Navigator.pop(bottomSheetCtx);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            "Order #$orderId successfully placed! Pending admin approval."),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  String _formatMonthDayYear(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
  }

  String _formatHourMinute(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return "${hour.toString().padLeft(2, '0')}:$minute $ampm";
  }

  // --- ADMIN FUNCTION: Add New Product ---
  Future<bool> _saveProduct(String id, Map<String, dynamic> data,
      {bool create = false}) async {
    try {
      await AdminRepository().saveProduct(id, data, create: create);
      return true;
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    }
  }

  Widget _productDetailsFields(
          TextEditingController image, TextEditingController description,
          {TextEditingController? category}) =>
      Column(children: [
        if (category != null)
          TextField(
              controller: category,
              maxLength: 50,
              style: const TextStyle(color: Color(0xFF14532D)),
              decoration: const InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: Color(0xFF4B7A5E)))),
        TextField(
            controller: image,
            maxLength: 2000,
            style: const TextStyle(color: Color(0xFF14532D)),
            decoration: const InputDecoration(
                labelText: 'Image URL',
                labelStyle: TextStyle(color: Color(0xFF4B7A5E)))),
        TextButton.icon(
            icon: const Icon(Icons.upload),
            label: const Text('Upload product image'),
            onPressed: () async {
              try {
                final selected = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['png', 'jpg', 'jpeg']);
                if (selected == null || selected.files.single.path == null)
                  return;
                final f = selected.files.single;
                final url = await SupabaseStorageService.uploadFile(
                    file: File(f.path!), originalFilename: f.name);
                if (mounted) image.text = url;
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }),
        TextField(
            controller: description,
            maxLength: 1000,
            maxLines: 3,
            style: const TextStyle(color: Color(0xFF14532D)),
            decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Color(0xFF4B7A5E)))),
      ]);

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final imageController = TextEditingController();
    final descriptionController = TextEditingController();
    String category = 'notebooks';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: Row(
          children: const [
            Icon(Icons.add_box_rounded, color: Color(0xFF15803D)),
            SizedBox(width: 8),
            Text("Add Store Item",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14532D))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Product Name",
                  labelStyle: TextStyle(color: Color(0xFF4B7A5E)),
                  hintText: "e.g., A4 Paper Pack",
                  hintStyle: TextStyle(color: Color(0xFF4B7A5E)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  OrderNumberInputFormatter(
                      maximum: 5000000, allowDecimals: true)
                ],
                style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Price (₱)",
                  labelStyle: TextStyle(color: Color(0xFF4B7A5E)),
                  hintText: "50.0",
                  hintStyle: TextStyle(color: Color(0xFF4B7A5E)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Initial Stock",
                  labelStyle: TextStyle(color: Color(0xFF4B7A5E)),
                  hintText: "100",
                  hintStyle: TextStyle(color: Color(0xFF4B7A5E)),
                ),
              ),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFFF0FDF4),
                    initialValue: category,
                    style:
                        const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: "Category",
                      labelStyle: TextStyle(color: Color(0xFF4B7A5E)),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'notebooks', child: Text('Notebooks & Paper')),
                      DropdownMenuItem(
                          value: 'pens', child: Text('Pens & Writing')),
                      DropdownMenuItem(
                          value: 'art', child: Text('Art & Office Supplies')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => category = val);
                    },
                  );
                },
              ),
              _productDetailsFields(imageController, descriptionController),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF4B7A5E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white),
            onPressed: () async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text);
              final stock = int.tryParse(stockController.text);
              if (name.isEmpty ||
                  price == null ||
                  !price.isFinite ||
                  price < 0 ||
                  price > 5000000 ||
                  stock == null ||
                  stock < 0 ||
                  stock > 100000) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Provide a product name, valid price, and stock from 0 to 100,000.')));
                return;
              }

              if (name.isNotEmpty &&
                  price.isFinite &&
                  price >= 0 &&
                  stock >= 0) {
                final id = _db.collection('products').doc().id;
                if (!await _saveProduct(
                    id,
                    {
                      'name': name,
                      'price': price,
                      'stock': stock,
                      'category': category,
                      'imageUrl': imageController.text.trim(),
                      'desc': descriptionController.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                    },
                    create: true)) return;
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Added '$name' to Database!"),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text("Save Item"),
          ),
        ],
      ),
    );
  }

  // --- ADMIN FUNCTION: Edit / Restock Product ---
  void _showEditProductDialog(String docId, Map<String, dynamic> data) {
    final imageController = TextEditingController(text: data['imageUrl'] ?? '');
    final descriptionController =
        TextEditingController(text: data['desc'] ?? '');
    final categoryController =
        TextEditingController(text: data['category'] ?? '');
    final nameController = TextEditingController(text: data['name'] ?? '');
    final priceController = TextEditingController(
        text: storePrice(data['price'])?.toStringAsFixed(2) ?? '');
    final stockController =
        TextEditingController(text: (data['stock'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: const Text("Edit Inventory Stock",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF14532D))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                decoration: const InputDecoration(
                    labelText: "Product Name",
                    labelStyle: TextStyle(color: Color(0xFF4B7A5E))),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  OrderNumberInputFormatter(
                      maximum: 5000000, allowDecimals: true)
                ],
                style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                decoration: const InputDecoration(
                    labelText: "Price (₱)",
                    labelStyle: TextStyle(color: Color(0xFF4B7A5E))),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                decoration: const InputDecoration(
                    labelText: "Current Stock Level",
                    labelStyle: TextStyle(color: Color(0xFF4B7A5E))),
              ),
              _productDetailsFields(imageController, descriptionController,
                  category: categoryController),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      int current = int.tryParse(stockController.text) ?? 0;
                      stockController.text = (current + 10).toString();
                    },
                    icon: const Icon(Icons.add,
                        size: 14, color: Color(0xFF15803D)),
                    label: const Text("+10 Stock",
                        style:
                            TextStyle(color: Color(0xFF15803D), fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFBBF7D0))),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      int current = int.tryParse(stockController.text) ?? 0;
                      stockController.text = (current + 50).toString();
                    },
                    icon: const Icon(Icons.add,
                        size: 14, color: Color(0xFF15803D)),
                    label: const Text("+50 Stock",
                        style:
                            TextStyle(color: Color(0xFF15803D), fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFBBF7D0))),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: Color(0xFFD97706)),
            tooltip: "Archive Product",
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  double.tryParse(priceController.text) == null ||
                  int.tryParse(stockController.text) == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Provide a name, numeric price and whole-number stock.')));
                return;
              }
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFBBF7D0))),
                  title: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFF43F5E)),
                      SizedBox(width: 8),
                      Text("Archive Product",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF14532D))),
                    ],
                  ),
                  content: const Text(
                      "Move this product to the archive? You can restore it at any time.",
                      style: TextStyle(color: Color(0xFF4B7A5E))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text("Cancel",
                          style: TextStyle(color: Color(0xFF4B7A5E))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706)),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text("Archive",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await AdminRepository().archive('store_product', docId, data);

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Product archived successfully and synced with the website."),
                      backgroundColor: Color(0xFF15803D),
                    ),
                  );
                } catch (err) {
                  debugPrint("Archive error: $err");
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Unable to archive the product. $err"),
                      backgroundColor: const Color(0xFFF43F5E),
                    ),
                  );
                }
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF4B7A5E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFBBF7D0))),
                  title: const Text("Confirm Stock Update",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14532D))),
                  content: Text(
                      "Save new stock level (${stockController.text}) for '${nameController.text}'?",
                      style: const TextStyle(color: Color(0xFF4B7A5E))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text("Cancel",
                          style: TextStyle(color: Color(0xFF4B7A5E))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A)),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text("Confirm & Save",
                          style: TextStyle(
                              color: Color(0xFF14532D),
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (!await _saveProduct(docId, {
                  'name': nameController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0.0,
                  'stock': int.tryParse(stockController.text) ?? 0,
                  'expectedStock': data['stock'],
                  'imageUrl': imageController.text.trim(),
                  'desc': descriptionController.text.trim(),
                  'category': categoryController.text.trim(),
                })) return;
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Product updated successfully!"),
                      backgroundColor: Color(0xFF10B981)),
                );
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Add extra bottom padding so content isn't hidden under FAB + outer nav bar
    final double extraBottom = widget.isAdmin ? 100 : 0;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: MediaQuery.of(context).padding.copyWith(
              bottom: MediaQuery.of(context).padding.bottom + extraBottom,
            ),
        viewPadding: MediaQuery.of(context).viewPadding.copyWith(
              bottom: MediaQuery.of(context).viewPadding.bottom + extraBottom,
            ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FFF9),
        body: Column(
          children: [
            // Search & Category Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    }),
                    style:
                        const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: widget.isAdmin
                          ? "Search inventory database..."
                          : "Search store items...",
                      hintStyle: const TextStyle(
                          fontSize: 12, color: Color(0xFF4B7A5E)),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: Color(0xFF4B7A5E)),
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFBBF7D0))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF16A34A))),
                      filled: true,
                      fillColor: const Color(0xFFFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryChip('all', 'All Supplies'),
                              _buildCategoryChip('notebooks', 'Notebooks'),
                              _buildCategoryChip('pens', 'Pens & Writing'),
                              _buildCategoryChip('art', 'Art Supplies'),
                            ],
                          ),
                        ),
                      ),
                      if (!widget.isAdmin)
                        Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_outlined,
                                  size: 20, color: Color(0xFF15803D)),
                              tooltip: 'Shopping Cart',
                              onPressed: () => _showCartBottomSheet(_allDocs),
                            ),
                            if (_cartTotalItems > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(3.5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                      minWidth: 16, minHeight: 16),
                                  child: Text(
                                    '$_cartTotalItems',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF14532D),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Product Grid & Pagination
            Expanded(
              child: StreamBuilder<List<ProfileRecord>>(
                stream: _productsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.error_outline_rounded,
                                size: 40, color: Color(0xFFF43F5E)),
                            SizedBox(height: 8),
                            Text('Unable to connect to the inventory database.',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A))),
                            Text('Please check your internet connection.',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF4B7A5E))),
                          ],
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF16A34A)));
                  }

                  final docs = snapshot.data ?? [];
                  _allDocs = docs;

                  final filteredDocs = docs.where((doc) {
                    final data = doc.data();
                    // Filter out archived products
                    if (data['archived'] == true) return false;

                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final category =
                        (data['category'] ?? '').toString().toLowerCase();

                    final matchesSearch =
                        name.contains(_searchQuery.toLowerCase());
                    final matchesCategory = _selectedCategory == 'all' ||
                        category == _selectedCategory;

                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 48, color: Color(0xFF334155)),
                          const SizedBox(height: 8),
                          Text(
                            widget.isAdmin
                                ? "No items in inventory. Tap '+' to add."
                                : "No items available in store.",
                            style: const TextStyle(color: Color(0xFF4B7A5E)),
                          ),
                        ],
                      ),
                    );
                  }

                  int totalPages = (filteredDocs.length / _itemsPerPage).ceil();
                  if (totalPages < 1) totalPages = 1;
                  if (_currentPage > totalPages) _currentPage = totalPages;
                  if (_currentPage < 1) _currentPage = 1;

                  int startIndex = (_currentPage - 1) * _itemsPerPage;
                  int endIndex =
                      math.min(startIndex + _itemsPerPage, filteredDocs.length);
                  final pagedDocs = filteredDocs.sublist(startIndex, endIndex);

                  return Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: widget.isAdmin ? 330 : 250,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: pagedDocs.length,
                          itemBuilder: (ctx, idx) {
                            final doc = pagedDocs[idx];
                            final data = doc.data();
                            final prodId = doc.id;
                            final name = data['name'] ?? 'Product';
                            final price =
                                storePrice(data['price']) ?? double.nan;
                            final stock = (data['stock'] ?? 0) as int;

                            final imageUrl = data['imageUrl'] ?? '';

                            void openDetails() {
                              if (widget.isAdmin) {
                                _showEditProductDialog(prodId, data);
                              } else {
                                ProductDetailScreen.showOverviewDialog(context,
                                    productId: prodId,
                                    productData: data,
                                    cartQuantity: _cart[prodId] ?? 0,
                                    onAddToCart: (qty) => setState(() =>
                                        _cart[prodId] =
                                            (_cart[prodId] ?? 0) + qty),
                                    onBuyNow: (qty) {
                                      setState(() => _cart[prodId] = qty);
                                      _showCartBottomSheet(_allDocs);
                                    });
                              }
                            }

                            return StoreProductCard(
                              name: '$name',
                              price: price,
                              stock: stock,
                              admin: widget.isAdmin,
                              image: imageUrl.toString().isNotEmpty
                                  ? sharedImage(imageUrl.toString(),
                                      fit: BoxFit.cover)
                                  : const Center(
                                      child: Icon(Icons.inventory_2_outlined,
                                          size: 36,
                                          color: DashboardTheme.muted)),
                              onOpen: openDetails,
                            );
                          },
                        ),
                      ),

                      // PAGINATION CONTROL BOTTOM BAR
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFFFF),
                          border:
                              Border(top: BorderSide(color: Color(0xFFBBF7D0))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded,
                                  color: Color(0xFF15803D)),
                              onPressed: _currentPage > 1
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            Text(
                              "Page $_currentPage of $totalPages (${filteredDocs.length} items)",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF0F172A)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFF15803D)),
                              onPressed: _currentPage < totalPages
                                  ? () => setState(() => _currentPage++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: widget.isAdmin
            ? FloatingActionButton.extended(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add),
                label: const Text("Add New Product"),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildCategoryChip(String catKey, String label) {
    final isSelected = _selectedCategory == catKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : const Color(0xFF4B7A5E))),
        selected: isSelected,
        selectedColor: const Color(0xFF16A34A),
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: isSelected ? Colors.transparent : const Color(0xFFBBF7D0)),
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedCategory = catKey;
              _currentPage = 1;
            });
          }
        },
      ),
    );
  }

  void _showCartBottomSheet(List<ProfileRecord> docs) {
    final products = {for (final doc in docs) doc.id: doc.data()};
    final merchant = _db
        .collection('settings')
        .doc('gcash_config')
        .snapshots()
        .map((snapshot) => snapshot.data() ?? <String, dynamic>{});
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Theme(
          data: DashboardTheme.light,
          child: StoreCheckoutSheet(
            cart: _cart,
            products: products,
            merchantSettings: merchant,
            onCartChanged: (cart) => setState(() {
              _cart.clear();
              _cart.addAll(cart);
            }),
            onCheckout: _checkoutCart,
          )),
    );
  }
}
