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
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final Map<String, int> _cart = {};
  List<QueryDocumentSnapshot> _allDocs = [];

  // --- PAGINATION STATE ---
  int _currentPage = 1;
  final int _itemsPerPage = 6;

  String _selectedPaymentMethod = 'GCash';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _cartTotalItems => _cart.values.fold(0, (acc, qty) => acc + qty);


  // --- ADMIN FUNCTION: Add New Product ---
  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    String category = 'notebooks';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: const [
            Icon(Icons.add_box_rounded, color: Color(0xFF818CF8)),
            SizedBox(width: 8),
            Text("Add Store Item", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Product Name",
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  hintText: "e.g., A4 Paper Pack",
                  hintStyle: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Price (₱)",
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  hintText: "50.0",
                  hintStyle: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Initial Stock",
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  hintText: "100",
                  hintStyle: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF0F172A),
                    initialValue: category,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: "Category",
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'notebooks', child: Text('Notebooks & Paper')),
                      DropdownMenuItem(value: 'pens', child: Text('Pens & Writing')),
                      DropdownMenuItem(value: 'art', child: Text('Art & Office Supplies')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => category = val);
                    },
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            onPressed: () async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text) ?? 0.0;
              final stock = int.tryParse(stockController.text) ?? 0;

              if (name.isNotEmpty) {
                await _db.collection('products').add({
                  'name': name,
                  'price': price,
                  'stock': stock,
                  'category': category,
                  'createdAt': FieldValue.serverTimestamp(),
                });
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
    final nameController = TextEditingController(text: data['name'] ?? '');
    final priceController = TextEditingController(text: (data['price'] ?? 0).toString());
    final stockController = TextEditingController(text: (data['stock'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: const Text("Edit Inventory Stock", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: "Product Name", labelStyle: TextStyle(color: Color(0xFF94A3B8))),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: "Price (₱)", labelStyle: TextStyle(color: Color(0xFF94A3B8))),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: "Current Stock Level", labelStyle: TextStyle(color: Color(0xFF94A3B8))),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      int current = int.tryParse(stockController.text) ?? 0;
                      stockController.text = (current + 10).toString();
                    },
                    icon: const Icon(Icons.add, size: 14, color: Color(0xFF818CF8)),
                    label: const Text("+10 Stock", style: TextStyle(color: Color(0xFF818CF8), fontSize: 11)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1E293B))),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      int current = int.tryParse(stockController.text) ?? 0;
                      stockController.text = (current + 50).toString();
                    },
                    icon: const Icon(Icons.add, size: 14, color: Color(0xFF818CF8)),
                    label: const Text("+50 Stock", style: TextStyle(color: Color(0xFF818CF8), fontSize: 11)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1E293B))),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFF43F5E)),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
                  title: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E)),
                      SizedBox(width: 8),
                      Text("Confirm Delete", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  content: const Text("Are you sure you want to delete this product? This action cannot be undone.", style: TextStyle(color: Color(0xFF94A3B8))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _db.collection('products').doc(docId).delete();
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Product deleted successfully!"), backgroundColor: Color(0xFFF43F5E)),
                );
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
                  title: const Text("Confirm Stock Update", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  content: Text("Save new stock level (${stockController.text}) for '${nameController.text}'?", style: const TextStyle(color: Color(0xFF94A3B8))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text("Confirm & Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _db.collection('products').doc(docId).update({
                  'name': nameController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0.0,
                  'stock': int.tryParse(stockController.text) ?? 0,
                });
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Product updated successfully!"), backgroundColor: Color(0xFF10B981)),
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
    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      body: Column(
        children: [
          // Search & Category Bar
          Container(
            color: const Color(0xFF0B0E1B),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentPage = 1;
                  }),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: widget.isAdmin ? "Search inventory database..." : "Search store items...",
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                    filled: true,
                    fillColor: const Color(0xFF0D1224),
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
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_cart_outlined, size: 20, color: Color(0xFF818CF8)),
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
                                color: Color(0xFF4F46E5),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                '$_cartTotalItems',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
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
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFF43F5E)),
                          SizedBox(height: 8),
                          Text('Nabigo sa pagkonekta sa inventory database.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                          Text('Pakisuri ang iyong koneksyon sa internet.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
                }

                final docs = snapshot.data?.docs ?? [];
                _allDocs = docs;

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final category = (data['category'] ?? '').toString().toLowerCase();

                  final matchesSearch = name.contains(_searchQuery.toLowerCase());
                  final matchesCategory = _selectedCategory == 'all' || category == _selectedCategory;

                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF334155)),
                        const SizedBox(height: 8),
                        Text(
                          widget.isAdmin ? "No items in inventory. Tap '+' to add." : "No items available in store.",
                          style: const TextStyle(color: Color(0xFF94A3B8)),
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
                int endIndex = math.min(startIndex + _itemsPerPage, filteredDocs.length);
                final pagedDocs = filteredDocs.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.67,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: pagedDocs.length,
                        itemBuilder: (ctx, idx) {
                          final doc = pagedDocs[idx];
                          final data = doc.data() as Map<String, dynamic>;
                          final prodId = doc.id;
                          final name = data['name'] ?? 'Product';
                          final price = (data['price'] ?? 0).toDouble();
                          final stock = (data['stock'] ?? 0) as int;

                          final isLowStock = stock > 0 && stock <= 12;
                          final isOutOfStock = stock <= 0;
                          final imageUrl = data['imageUrl'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              ProductDetailScreen.showOverviewDialog(
                                context,
                                productId: prodId,
                                productData: data,
                                onAddToCart: (qty) {
                                  setState(() {
                                    _cart[prodId] = (_cart[prodId] ?? 0) + qty;
                                  });
                                },
                                onBuyNow: (qty) {
                                  setState(() {
                                    _cart[prodId] = (_cart[prodId] ?? 0) + qty;
                                  });
                                  _showCartBottomSheet(_allDocs);
                                },
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isLowStock && widget.isAdmin
                                      ? Colors.orangeAccent
                                      : const Color(0xFF1E293B),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Image & Stock Badge
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: imageUrl.toString().isNotEmpty
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Icon(Icons.menu_book_rounded, size: 36, color: Color(0xFF475569)),
                                                    ),
                                                  )
                                                : const Center(
                                                    child: Icon(Icons.menu_book_rounded, size: 36, color: Color(0xFF475569)),
                                                  ),
                                          ),
                                          // Stock Badge Top Right (matching screenshot)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: isOutOfStock
                                                    ? const Color(0xFFEF4444)
                                                    : (isLowStock ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5)),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isOutOfStock
                                                        ? Icons.cancel_outlined
                                                        : (isLowStock ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                                                    size: 10,
                                                    color: isOutOfStock
                                                        ? Colors.white
                                                        : (isLowStock ? const Color(0xFFD97706) : const Color(0xFF059669)),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    isOutOfStock
                                                        ? "Out of Stock"
                                                        : (isLowStock ? "Low Stock" : "In Stock"),
                                                    style: TextStyle(
                                                      color: isOutOfStock
                                                          ? Colors.white
                                                          : (isLowStock ? const Color(0xFFB45309) : const Color(0xFF047857)),
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Product Name
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),

                                  // Available Stock Line (matching screenshot: Available Stock:   10 pcs)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Available Stock:",
                                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                      ),
                                      Text(
                                        "$stock pcs",
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),

                                  // Price Line (matching screenshot: Price:    ₱19.00)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Price:",
                                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      ),
                                      Text(
                                        price > 999999999
                                            ? "₱999,999.00"
                                            : "₱${price.toStringAsFixed(2)}",
                                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // CONTROLS BASED ON ROLE
                                  if (widget.isAdmin) ...[
                                    SizedBox(
                                      width: double.infinity,
                                      height: 32,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF4F46E5),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        onPressed: () => _showEditProductDialog(prodId, data),
                                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                                        label: const Text("Edit / Restock", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ] else ...[
                                    Row(
                                      children: [
                                        // Add to Cart button (dark container, white text, cart icon)
                                        Expanded(
                                          child: SizedBox(
                                            height: 30,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF090D1A),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: EdgeInsets.zero,
                                                side: const BorderSide(color: Color(0xFF334155), width: 0.8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              ),
                                              onPressed: stock > 0
                                                  ? () {
                                                      setState(() {
                                                        _cart[prodId] = (_cart[prodId] ?? 0) + 1;
                                                      });
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text("Added $name to Cart!"),
                                                          backgroundColor: const Color(0xFF10B981),
                                                          duration: const Duration(seconds: 1),
                                                        ),
                                                      );
                                                    }
                                                  : null,
                                              icon: const Icon(Icons.shopping_cart_outlined, size: 12, color: Colors.white),
                                              label: const Text(
                                                "Add to Cart",
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),

                                        // Buy Now button (Blue pill with lightning bolt icon)
                                        Expanded(
                                          child: SizedBox(
                                            height: 30,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2563EB),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              ),
                                              onPressed: stock > 0
                                                  ? () {
                                                      ProductDetailScreen.showOverviewDialog(
                                                        context,
                                                        productId: prodId,
                                                        productData: data,
                                                        onAddToCart: (qty) {
                                                          setState(() {
                                                            _cart[prodId] = (_cart[prodId] ?? 0) + qty;
                                                          });
                                                        },
                                                        onBuyNow: (qty) {
                                                          setState(() {
                                                            _cart[prodId] = (_cart[prodId] ?? 0) + qty;
                                                          });
                                                          _showCartBottomSheet(_allDocs);
                                                        },
                                                      );
                                                    }
                                                  : null,
                                              icon: const Icon(Icons.flash_on_rounded, size: 12, color: Colors.white),
                                              label: const Text(
                                                "Buy Now",
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // PAGINATION CONTROL BOTTOM BAR
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D1224),
                        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                            onPressed: _currentPage > 1
                                ? () => setState(() => _currentPage--)
                                : null,
                          ),
                          Text(
                            "Page $_currentPage of $totalPages (${filteredDocs.length} items)",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
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
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              onPressed: _showAddProductDialog,
              icon: const Icon(Icons.add),
              label: const Text("Add New Product"),
            )
          : null,
    );
  }

  Widget _buildCategoryChip(String catKey, String label) {
    final isSelected = _selectedCategory == catKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : const Color(0xFF94A3B8))),
        selected: isSelected,
        selectedColor: const Color(0xFF4F46E5),
        backgroundColor: const Color(0xFF0D1224),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isSelected ? Colors.transparent : const Color(0xFF1E293B)),
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

  void _showCartBottomSheet(List<QueryDocumentSnapshot> docs) {
    // Build a lookup map from productId -> productData
    final Map<String, Map<String, dynamic>> productMap = {
      for (final d in docs) d.id: d.data() as Map<String, dynamic>,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setBottomSheetState) {
          // Compute totals inside builder so they update with quantity changes
          double total = 0;
          for (final entry in _cart.entries) {
            final data = productMap[entry.key];
            if (data != null) {
              total += (data['price'] ?? 0) * entry.value;
            }
          }

          final cartEntries = _cart.entries
              .where((e) => e.value > 0 && productMap.containsKey(e.key))
              .toList();

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Your Cart",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B)),

                // ── Cart Items ────────────────────────────────────────────
                if (cartEntries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text("Your cart is empty.",
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: cartEntries.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Color(0xFF1E293B), height: 1),
                      itemBuilder: (_, i) {
                        final prodId = cartEntries[i].key;
                        final qty = cartEntries[i].value;
                        final data = productMap[prodId]!;
                        final name = data['name'] ?? 'Product';
                        final price = (data['price'] ?? 0).toDouble();
                        final stock = data['stock'] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              // Product name + unit price
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text("₱${price.toStringAsFixed(2)} each",
                                        style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              // Quantity controls
                              Row(
                                children: [
                                  InkWell(
                                    onTap: qty > 1
                                        ? () {
                                            setBottomSheetState(() =>
                                                _cart[prodId] = qty - 1);
                                            setState(() {});
                                          }
                                        : null,
                                    child: const Icon(Icons.remove_circle_outline,
                                        color: Color(0xFF818CF8), size: 20),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text("$qty",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  InkWell(
                                    onTap: qty < stock
                                        ? () {
                                            setBottomSheetState(() =>
                                                _cart[prodId] = qty + 1);
                                            setState(() {});
                                          }
                                        : null,
                                    child: const Icon(Icons.add_circle_outline,
                                        color: Color(0xFF818CF8), size: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              // Line total
                              SizedBox(
                                width: 72,
                                child: Text(
                                  "₱${(price * qty).toStringAsFixed(2)}",
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                              // Remove item
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Color(0xFFEF4444), size: 18),
                                onPressed: () {
                                  setBottomSheetState(() => _cart.remove(prodId));
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const Divider(color: Color(0xFF1E293B)),

                // ── Payment Method ────────────────────────────────────────
                const Text("Payment Method",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['GCash', 'Paymaya', 'Cash on pickup']
                      .map((method) {
                    final selected = _selectedPaymentMethod == method;
                    return ChoiceChip(
                      label: Text(method,
                          style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF94A3B8))),
                      selected: selected,
                      selectedColor: const Color(0xFF4F46E5),
                      backgroundColor: const Color(0xFF1E293B),
                      onSelected: (_) {
                        setBottomSheetState(
                            () => _selectedPaymentMethod = method);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ── Order Total ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Order Total",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text("₱${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Checkout Button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cartEntries.isEmpty
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: cartEntries.isEmpty
                        ? null
                        : () {
                            setState(() => _cart.clear());
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Order successfully placed! Thank you."),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          },
                    child: const Text("Checkout Order",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}