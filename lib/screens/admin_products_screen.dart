import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ===========================================================================
// PRODUCT MODEL
// ===========================================================================
class Product {
  String id;
  String name;
  String category;
  double price;
  int stock;
  String? imageUrl;
  XFile? localImageFile;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.imageUrl,
    this.localImageFile,
  });
}

// ===========================================================================
// MAIN ADMIN PRODUCTS SCREEN
// ===========================================================================
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String _selectedCategory = 'All';

  // Sample Product Inventory List
  final List<Product> _products = [
    Product(
      id: 'P001',
      name: 'Tarpaulin Printing (13oz)',
      category: 'Tarpaulin',
      price: 15.00,
      stock: 500,
      imageUrl: 'https://via.placeholder.com/150',
    ),
    Product(
      id: 'P002',
      name: 'Vinyl Sticker - Waterproof',
      category: 'Stickers',
      price: 45.00,
      stock: 250,
      imageUrl: 'https://via.placeholder.com/150',
    ),
    Product(
      id: 'P003',
      name: 'PVC ID Card with Lanyard',
      category: 'Cards & Badges',
      price: 50.00,
      stock: 120,
      imageUrl: 'https://via.placeholder.com/150',
    ),
    Product(
      id: 'P004',
      name: 'A4 Document Print (B&W)',
      category: 'Documents',
      price: 3.00,
      stock: 5000,
      imageUrl: 'https://via.placeholder.com/150',
    ),
    Product(
      id: 'P005',
      name: 'Custom Cotton Shirt (DTF)',
      category: 'Apparel',
      price: 180.00,
      stock: 45,
      imageUrl: 'https://via.placeholder.com/150',
    ),
  ];

  final List<String> _categories = [
    'All',
    'Documents',
    'Tarpaulin',
    'Stickers',
    'Cards & Badges',
    'Apparel',
  ];

  // ===========================================================================
  // ADD / EDIT PRODUCT MODAL SHEET WITH PHOTO IMPORT
  // ===========================================================================
  void _showEditProductModal(BuildContext context, {Product? product}) {
    final isEditing = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(text: product?.price.toString() ?? '');
    final stockController = TextEditingController(text: product?.stock.toString() ?? '');
    String selectedCat = product?.category ?? _categories[1];
    XFile? pickedImage = product?.localImageFile;

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickProductImage(ImageSource source) async {
              try {
                final XFile? image = await _imagePicker.pickImage(
                  source: source,
                  imageQuality: 85,
                  maxWidth: 800,
                );
                if (image != null) {
                  setModalState(() {
                    pickedImage = image;
                  });
                }
              } catch (e) {
                debugPrint('Image picking error: $e');
              }
            }

            void showImageSourceSelector() {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF0F172A),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            pickProductImage(ImageSource.gallery);
                          },
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Color(0xFF1E293B),
                                child: Icon(Icons.photo_library_rounded, color: Color(0xFF818CF8)),
                              ),
                              SizedBox(height: 8),
                              Text('Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            pickProductImage(ImageSource.camera);
                          },
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Color(0xFF1E293B),
                                child: Icon(Icons.camera_alt_rounded, color: Color(0xFF38BDF8)),
                              ),
                              SizedBox(height: 8),
                              Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                ),
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEditing ? 'Edit Product Details' : 'Add New Inventory Product',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Image Picker Box
                        Center(
                          child: GestureDetector(
                            onTap: showImageSourceSelector,
                            child: Stack(
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D1224),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: pickedImage != null
                                        ? (kIsWeb
                                        ? Image.network(pickedImage!.path, fit: BoxFit.cover)
                                        : Image.file(File(pickedImage!.path), fit: BoxFit.cover))
                                        : (product?.imageUrl != null
                                        ? Image.network(
                                      product!.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 40,
                                        color: Color(0xFF64748B),
                                      ),
                                    )
                                        : const Icon(
                                      Icons.add_photo_alternate_rounded,
                                      size: 40,
                                      color: Color(0xFF64748B),
                                    )),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4F46E5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text('Tap to upload product photo', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ),
                        const SizedBox(height: 16),

                        // Product Name Field
                        const Text('Product Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. Glossy Sticker Pack',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF0D1224),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a product name' : null,
                        ),
                        const SizedBox(height: 14),

                        // Category Dropdown
                        const Text('Product Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF0D1224),
                          value: selectedCat,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0D1224),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                          ),
                          items: _categories
                              .where((c) => c != 'All')
                              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => selectedCat = v);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Price and Stock row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Unit Price (₱)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1))),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: priceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      filled: true,
                                      fillColor: const Color(0xFF0D1224),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Enter price';
                                      if (double.tryParse(v.trim()) == null) return 'Invalid price';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Current Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1))),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: stockController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      filled: true,
                                      fillColor: const Color(0xFF0D1224),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Enter stock';
                                      final stock = int.tryParse(v.trim());
                                      if (stock == null) return 'Invalid stock';
                                      if (stock < 0) return 'Cannot be negative';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Save / Update Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                if (isEditing) {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      backgroundColor: const Color(0xFF0F172A),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
                                      title: Row(
                                        children: const [
                                          Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5)),
                                          SizedBox(width: 8),
                                          Text('Confirm Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ],
                                      ),
                                      content: const Text('Are you sure you want to save the changes made to this product?', style: TextStyle(color: Color(0xFF94A3B8))),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c, false),
                                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                                          onPressed: () => Navigator.pop(c, true),
                                          child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                }

                                setState(() {
                                  if (isEditing) {
                                    product.name = nameController.text.trim();
                                    product.category = selectedCat;
                                    product.price = double.parse(priceController.text.trim());
                                    product.stock = int.parse(stockController.text.trim());
                                    product.localImageFile = pickedImage;
                                  } else {
                                    _products.add(
                                      Product(
                                        id: 'P00${_products.length + 1}',
                                        name: nameController.text.trim(),
                                        category: selectedCat,
                                        price: double.parse(priceController.text.trim()),
                                        stock: int.parse(stockController.text.trim()),
                                        localImageFile: pickedImage,
                                        imageUrl: pickedImage == null ? 'https://via.placeholder.com/150' : null,
                                      ),
                                    );
                                  }
                                });

                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEditing ? 'Product updated successfully!' : 'Product added successfully!'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text(
                              isEditing ? 'Save Changes' : 'Add Product',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // MAIN ADMIN PRODUCT LIST UI BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final filteredProducts = _selectedCategory == 'All'
        ? _products
        : _products.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      appBar: AppBar(
        title: const Text('Inventory & Products', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF070A14),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E293B)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_rounded, color: Colors.white),
            onPressed: () => _showEditProductModal(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Tabs
          Container(
            height: 54,
            color: const Color(0xFF0B0E1B),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFF4F46E5),
                    backgroundColor: const Color(0xFF0D1224),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isSelected ? Colors.transparent : const Color(0xFF1E293B)),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // Product List
          Expanded(
            child: filteredProducts.isEmpty
                ? const Center(
              child: Text('No products available in this category.', style: TextStyle(color: Color(0xFF94A3B8))),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1224),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      // Product Image Display
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: product.localImageFile != null
                              ? (kIsWeb
                              ? Image.network(product.localImageFile!.path, fit: BoxFit.cover)
                              : Image.file(File(product.localImageFile!.path), fit: BoxFit.cover))
                              : Image.network(
                            product.imageUrl ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported_rounded, color: Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Product Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${product.category} • Stock: ${product.stock}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons (Edit & Delete)
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF818CF8), size: 24),
                        onPressed: () => _showEditProductModal(context, product: product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF43F5E), size: 22),
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
                                  Text('Confirm Delete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                              content: Text('Are you sure you want to delete "${product.name}"? This action cannot be undone.', style: const TextStyle(color: Color(0xFF94A3B8))),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            setState(() {
                              _products.removeWhere((p) => p.id == product.id);
                            });
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleted "${product.name}"'),
                                backgroundColor: const Color(0xFFF43F5E),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}