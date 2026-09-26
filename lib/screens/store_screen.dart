import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.add_box_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text("Add Store Item", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Product Name", hintText: "e.g., A4 Paper Pack"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Price (₱)", hintText: "50.00"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Initial Stock", hintText: "100"),
              ),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: "Category"),
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
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
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
                  SnackBar(content: Text("Added '$name' to Database!")),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Edit Inventory Stock", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Product Name"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Price (₱)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Current Stock Level"),
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
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("+10 Stock"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      int current = int.tryParse(stockController.text) ?? 0;
                      stockController.text = (current + 50).toString();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("+50 Stock"),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            onPressed: () async {
              await _db.collection('products').doc(docId).delete();
              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Deleted item from database.")),
              );
            },
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () async {
              await _db.collection('products').doc(docId).update({
                'name': nameController.text.trim(),
                'price': double.tryParse(priceController.text) ?? 0.0,
                'stock': int.tryParse(stockController.text) ?? 0,
              });
              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Product updated successfully!")),
              );
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
      backgroundColor: const Color(0xFFF8FAFC),
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
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: widget.isAdmin ? "Search inventory database..." : "Search store items...",
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
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
              ],
            ),
          ),

          // Product Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                        const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 8),
                        Text(
                          widget.isAdmin ? "No items in inventory. Tap '+' to add." : "No items available in store.",
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.70,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (ctx, idx) {
                    final doc = filteredDocs[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final prodId = doc.id;
                    final name = data['name'] ?? 'Product';
                    final price = (data['price'] ?? 0).toDouble();
                    final stock = (data['stock'] ?? 0) as int;

                    final isLowStock = stock < 5;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isLowStock && widget.isAdmin ? Colors.orangeAccent : const Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  children: [
                                    const Center(
                                      child: Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF2563EB)),
                                    ),
                                    if (widget.isAdmin)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: stock == 0 ? Colors.red : (isLowStock ? Colors.orange : Colors.green),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            stock == 0 ? "OUT OF STOCK" : "STOCK: $stock",
                                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "₱${price.toStringAsFixed(2)}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13),
                                ),
                                if (!widget.isAdmin)
                                  Text("Stock: $stock", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // --- CONTROLS BASED ON ROLE ---
                            if (widget.isAdmin) ...[
                              // ADMIN CONTROLS: Edit / Restock Button
                              SizedBox(
                                width: double.infinity,
                                height: 32,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () => _showEditProductDialog(prodId, data),
                                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                                  label: const Text("Edit / Restock", style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            ] else ...[
                              // CUSTOMER CONTROLS: Add to Cart Button
                              SizedBox(
                                width: double.infinity,
                                height: 32,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE11D48),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: stock > 0
                                      ? () {
                                    setState(() {
                                      _cart[prodId] = (_cart[prodId] ?? 0) + 1;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Added $name to Cart!")),
                                    );
                                  }
                                      : null,
                                  icon: const Icon(Icons.add_shopping_cart, size: 14),
                                  label: Text(stock > 0 ? "Add to Cart" : "Out of Stock", style: const TextStyle(fontSize: 11)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        onPressed: _showAddProductDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add New Product"),
      )
          : FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE11D48),
        foregroundColor: Colors.white,
        onPressed: () => _showCartBottomSheet(_allDocs),
        icon: const Icon(Icons.shopping_cart),
        label: Text("Cart ($_cartTotalItems)"),
      ),
    );
  }

  Widget _buildCategoryChip(String catKey, String label) {
    final isSelected = _selectedCategory == catKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : const Color(0xFF0F172A))),
        selected: isSelected,
        selectedColor: const Color(0xFF0F172A),
        backgroundColor: const Color(0xFFF1F5F9),
        onSelected: (selected) {
          if (selected) setState(() => _selectedCategory = catKey);
        },
      ),
    );
  }

  void _showCartBottomSheet(List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Your Cart", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text("Total Items: $_cartTotalItems"),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white),
                onPressed: () {
                  setState(() => _cart.clear());
                  Navigator.pop(ctx);
                },
                child: const Text("Checkout Order"),
              ),
            )
          ],
        ),
      ),
    );
  }
}