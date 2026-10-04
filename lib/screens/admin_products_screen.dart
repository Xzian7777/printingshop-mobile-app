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
  String? imageUrl; // Para sa online or default image
  XFile? localImageFile; // Para sa na-import na bagong picture mula sa gallery/camera

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
  List<Product> _products = [
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
      name: 'Customized T-Shirt Sublimation',
      category: 'Apparel',
      price: 250.00,
      stock: 80,
      imageUrl: 'https://via.placeholder.com/150',
    ),
  ];

  final List<String> _categories = ['All', 'Tarpaulin', 'Stickers', 'Apparel', 'Documents'];

  // ===========================================================================
  // ADD / EDIT PRODUCT MODAL WITH IMAGE IMPORT FIELD
  // ===========================================================================
  void _showEditProductModal(BuildContext context, {Product? product}) {
    final isEditing = product != null;
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: isEditing ? product.name : '');
    final priceController = TextEditingController(text: isEditing ? product.price.toString() : '');
    final stockController = TextEditingController(text: isEditing ? product.stock.toString() : '');
    String selectedCat = isEditing ? product.category : 'Tarpaulin';

    XFile? pickedImage = isEditing ? product.localImageFile : null;
    String? currentImageUrl = isEditing ? product.imageUrl : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Function para pumili ng picture mula sa Gallery o Camera
            Future<void> pickProductImage(ImageSource source) async {
              try {
                final XFile? image = await _imagePicker.pickImage(
                  source: source,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 85,
                );
                if (image != null) {
                  setModalState(() {
                    pickedImage = image;
                  });
                }
              } catch (e) {
                debugPrint('Image Pick Error: $e');
              }
            }

            // Dialog para mamili kung Gallery o Camera
            void showImageSourceSelector() {
              showModalBottomSheet(
                context: context,
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
                                backgroundColor: Color(0xFFF1F5F9),
                                child: Icon(Icons.photo_library_rounded, color: Color(0xFFE11D48)),
                              ),
                              SizedBox(height: 8),
                              Text('Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                                backgroundColor: Color(0xFFF1F5F9),
                                child: Icon(Icons.camera_alt_rounded, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 8),
                              Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEditing ? 'Edit Product' : 'Add New Product',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // =====================================================
                        // PRODUCT IMAGE IMPORT FIELD
                        // =====================================================
                        const Text(
                          'Product Image *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: showImageSourceSelector,
                          child: Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid, width: 1.5),
                            ),
                            child: pickedImage != null
                                ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: kIsWeb
                                      ? Image.network(pickedImage!.path, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                      : Image.file(File(pickedImage!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    radius: 16,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                                      onPressed: showImageSourceSelector,
                                    ),
                                  ),
                                ),
                              ],
                            )
                                : (currentImageUrl != null && currentImageUrl!.isNotEmpty)
                                ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.network(
                                    currentImageUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Icon(Icons.broken_image_rounded, size: 40, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    radius: 16,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                                      onPressed: showImageSourceSelector,
                                    ),
                                  ),
                                ),
                              ],
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE11D48).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFFE11D48), size: 28),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap to import product image',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                ),
                                const Text(
                                  'Supports PNG, JPG (Max 5MB)',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Product Name Input
                        TextFormField(
                          controller: nameController,
                          decoration: _buildInputDecoration('Product Name *', Icons.inventory_2_outlined),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter product name' : null,
                        ),
                        const SizedBox(height: 12),

                        // Category Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedCat,
                          decoration: _buildInputDecoration('Category *', Icons.category_outlined),
                          items: _categories.where((c) => c != 'All').map((cat) {
                            return DropdownMenuItem(value: cat, child: Text(cat));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedCat = val);
                          },
                        ),
                        const SizedBox(height: 12),

                        // Price & Stock Inputs Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _buildInputDecoration('Price (₱) *', Icons.payments_outlined),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (double.tryParse(v) == null) return 'Invalid price';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDecoration('Stock Qty *', Icons.numbers_rounded),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (int.tryParse(v) == null) return 'Invalid qty';
                                  return null;
                                },
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
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
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
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Inventory & Products', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
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
            color: const Color(0xFF0F172A),
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
                    selectedColor: const Color(0xFFE11D48),
                    backgroundColor: const Color(0xFF1E293B),
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
              child: Text('No products available in this category.', style: TextStyle(color: Color(0xFF64748B))),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Product Image Display
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported_rounded, color: Color(0xFF94A3B8)),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${product.category} • Stock: ${product.stock}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE11D48)),
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons (Edit & Delete)
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF0F172A), size: 26),
                        onPressed: () => _showEditProductModal(context, product: product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 22),
                        onPressed: () {
                          setState(() {
                            _products.removeWhere((p) => p.id == product.id);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Product deleted')),
                          );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditProductModal(context),
        backgroundColor: const Color(0xFFE11D48),
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
    );
  }
}