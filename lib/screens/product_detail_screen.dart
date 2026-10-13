import 'package:flutter/material.dart';

/// Product Overview Dialog / Screen matching the modern dark desktop/mobile UI design
class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final Function(int quantity)? onAddToCart;
  final Function(int quantity)? onBuyNow;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.productData,
    this.onAddToCart,
    this.onBuyNow,
  });

  /// Helper to show this as a stylish modal dialog or bottom sheet
  static Future<void> showOverviewDialog(
    BuildContext context, {
    required String productId,
    required Map<String, dynamic> productData,
    Function(int quantity)? onAddToCart,
    Function(int quantity)? onBuyNow,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ProductDetailScreen(
            productId: productId,
            productData: productData,
            onAddToCart: onAddToCart,
            onBuyNow: onBuyNow,
          ),
        ),
      ),
    );
  }

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final String name = widget.productData['name'] ?? 'Product';
    final double price = (widget.productData['price'] ?? 0).toDouble();
    final int stock = (widget.productData['stock'] ?? 0) as int;
    final String imageUrl = widget.productData['imageUrl'] ?? '';
    final String category = (widget.productData['category'] ?? 'ART').toString().toUpperCase();
    final String description = widget.productData['description'] ??
        "Quality school & office supplies item. Guaranteed premium materials and ready for immediate store pick-up.";
    final String shopLocation = widget.productData['location'] ?? "Main Counter (Store Front)";

    final bool isOutOfStock = stock <= 0;
    final bool isLowStock = stock > 0 && stock <= 12;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Deep dark modal background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Bar ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    const Text(
                      "PRODUCT OVERVIEW",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 19, color: Color(0xFF94A3B8)),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Content Area ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 580;
                    return isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Image Box & Badges
                              SizedBox(
                                width: 300,
                                child: _buildImageSection(
                                  imageUrl: imageUrl,
                                  isOutOfStock: isOutOfStock,
                                  isLowStock: isLowStock,
                                  stock: stock,
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Right: Info, Price, Description & Actions
                              Expanded(
                                child: _buildDetailsSection(
                                  name: name,
                                  category: category,
                                  price: price,
                                  stock: stock,
                                  shopLocation: shopLocation,
                                  description: description,
                                  isOutOfStock: isOutOfStock,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildImageSection(
                                imageUrl: imageUrl,
                                isOutOfStock: isOutOfStock,
                                isLowStock: isLowStock,
                                stock: stock,
                              ),
                              const SizedBox(height: 18),
                              _buildDetailsSection(
                                name: name,
                                category: category,
                                price: price,
                                stock: stock,
                                shopLocation: shopLocation,
                                description: description,
                                isOutOfStock: isOutOfStock,
                              ),
                            ],
                          );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection({
    required String imageUrl,
    required bool isOutOfStock,
    required bool isLowStock,
    required int stock,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
              ),

              // Stock Status Badge (Top-left in image, matching reference)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? const Color(0xFFEF4444)
                        : (isLowStock ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5)),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOutOfStock
                            ? Icons.cancel_outlined
                            : (isLowStock ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                        size: 13,
                        color: isOutOfStock
                            ? Colors.white
                            : (isLowStock ? const Color(0xFFD97706) : const Color(0xFF059669)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOutOfStock
                            ? "Out of Stock"
                            : (isLowStock ? "Low Stock" : "In Stock"),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isOutOfStock
                              ? Colors.white
                              : (isLowStock ? const Color(0xFFB45309) : const Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Trust features underneath photo (100% Authentic & Store Pick-up)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
                SizedBox(width: 4),
                Text(
                  "100% Authentic",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.storefront_outlined, size: 14, color: Color(0xFF38BDF8)),
                SizedBox(width: 4),
                Text(
                  "Store Pick-up",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFF1A2234),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.menu_book_rounded, size: 54, color: Color(0xFF475569)),
            SizedBox(height: 6),
            Text("Product Image", style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection({
    required String name,
    required String category,
    required double price,
    required int stock,
    required String shopLocation,
    required String description,
    required bool isOutOfStock,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Text(
            category,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Product Name (Bold, modern)
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),

        // Price Banner Box (matching screenshot: grey-blue capsule container)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              const Text(
                "PRICE: ",
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "₱${price.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Availability info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Availability:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            Text(
              isOutOfStock ? "Out of Stock" : "$stock pcs available",
              style: TextStyle(
                color: isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Shop Location info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Shop Location:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            Text(
              shopLocation,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Product Description Card
        const Text(
          "PRODUCT DESCRIPTION",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF090D1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Quantity Selector Row
        Row(
          children: [
            const Text(
              "Quantity:",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF090D1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    onTap: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Icon(
                        Icons.remove,
                        size: 15,
                        color: _quantity > 1 ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 32),
                    alignment: Alignment.center,
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    onTap: _quantity < stock ? () => setState(() => _quantity++) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Icon(
                        Icons.add,
                        size: 15,
                        color: _quantity < stock ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "(Max: $stock pcs)",
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Action Buttons (Matching Screenshot) ───────────────────
        Row(
          children: [
            // Add to Cart: White/Light button with Navy border & text
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: stock > 0
                      ? () {
                          if (widget.onAddToCart != null) {
                            widget.onAddToCart!(_quantity);
                          }
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Added $_quantity $name to Cart!"),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16, color: Color(0xFF0F172A)),
                  label: const Text(
                    "Add to Cart",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Buy Now: Royal Blue Pill Button with Lightning bolt
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: stock > 0
                      ? () {
                          if (widget.onBuyNow != null) {
                            widget.onBuyNow!(_quantity);
                          }
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Proceeding to checkout: $_quantity x $name"),
                              backgroundColor: const Color(0xFF2563EB),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    "Buy Now",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
