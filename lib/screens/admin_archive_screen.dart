import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArchiveItem {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'user', 'service', 'product', 'sample'
  final String categoryName;
  final Map<String, dynamic> rawData;
  final String? imageUrl;

  ArchiveItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.categoryName,
    required this.rawData,
    this.imageUrl,
  });
}

class AdminArchiveScreen extends StatefulWidget {
  const AdminArchiveScreen({super.key});

  @override
  State<AdminArchiveScreen> createState() => _AdminArchiveScreenState();
}

class _AdminArchiveScreenState extends State<AdminArchiveScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _selectedCategory = 'All'; // 'All', 'Users', 'Printing Services', 'In-Store Supplies', 'Sample Works'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restoreItem(ArchiveItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: Row(
          children: const [
            Icon(Icons.restore_from_trash_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text(
              "Restore Item",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF14532D),
              ),
            ),
          ],
        ),
        content: Text(
          "I-restore ang '${item.title}' pabalik sa aktibong listahan?",
          style: const TextStyle(color: Color(0xFF4B7A5E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF4B7A5E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Restore"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (item.type == 'product') {
        await _db.collection('products').doc(item.id).update({
          'archived': false,
          'archivedAt': FieldValue.delete(),
        });
        try {
          await _db
              .collection('artifacts')
              .doc('printcraft-pro')
              .collection('public')
              .doc('data')
              .collection('store_products')
              .doc(item.id)
              .update({
            'archived': false,
            'archivedAt': FieldValue.delete(),
          });
        } catch (_) {}
      } else if (item.type == 'user') {
        await _db.collection('users').doc(item.id).update({
          'archived': false,
          'archivedAt': FieldValue.delete(),
        });
      } else if (item.type == 'service') {
        await _db.collection('services').doc(item.id).update({
          'archived': false,
          'archivedAt': FieldValue.delete(),
        });
      } else if (item.type == 'sample') {
        await _db.collection('sample_works').doc(item.id).update({
          'archived': false,
          'archivedAt': FieldValue.delete(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Naibalik na ang '${item.title}'!"),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error restoring item: $e"),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    }
  }

  Future<void> _permanentlyDeleteItem(ArchiveItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFF43F5E)),
            SizedBox(width: 8),
            Text(
              "Permanent Delete",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF14532D),
              ),
            ),
          ],
        ),
        content: Text(
          "Sigurado ka bang buburahin nang permanente ang '${item.title}'? Hindi na ito mababawi kailanman.",
          style: const TextStyle(color: Color(0xFF4B7A5E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF4B7A5E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete Permanently"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (item.type == 'product') {
        await _db.collection('products').doc(item.id).delete();
        try {
          await _db
              .collection('artifacts')
              .doc('printcraft-pro')
              .collection('public')
              .doc('data')
              .collection('store_products')
              .doc(item.id)
              .delete();
        } catch (_) {}
      } else if (item.type == 'user') {
        await _db.collection('users').doc(item.id).delete();
      } else if (item.type == 'service') {
        await _db.collection('services').doc(item.id).delete();
      } else if (item.type == 'sample') {
        await _db.collection('sample_works').doc(item.id).delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Permanently deleted '${item.title}'."),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting item: $e"),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    }
  }

  Widget _buildFilterChip(String label, int count, String key) {
    final isSelected = _selectedCategory == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF047857) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF047857).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          "$label ($count)",
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF15803D), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "System Archives",
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('products').snapshots(),
        builder: (context, productsSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').snapshots(),
            builder: (context, usersSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _db.collection('services').snapshots(),
                builder: (context, servicesSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _db.collection('sample_works').snapshots(),
                    builder: (context, samplesSnap) {
                      // 1. Gather all archived items
                      final List<ArchiveItem> userItems = [];
                      for (final doc in usersSnap.data?.docs ?? []) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['archived'] == true) {
                          userItems.add(ArchiveItem(
                            id: doc.id,
                            title: data['name'] ?? data['email'] ?? 'User',
                            subtitle: "Email: ${data['email'] ?? 'N/A'} • Role: ${data['role'] ?? 'Customer'}",
                            type: 'user',
                            categoryName: 'Users',
                            rawData: data,
                          ));
                        }
                      }

                      final List<ArchiveItem> productItems = [];
                      for (final doc in productsSnap.data?.docs ?? []) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['archived'] == true) {
                          final stock = (data['stock'] ?? 0);
                          final price = (data['price'] ?? 0).toDouble();
                          productItems.add(ArchiveItem(
                            id: doc.id,
                            title: data['name'] ?? 'Product',
                            subtitle: "Category: ${data['category'] ?? 'General'} • Stock: $stock pcs • ₱${price.toStringAsFixed(2)}",
                            type: 'product',
                            categoryName: 'In-Store Supplies',
                            imageUrl: data['imageUrl'],
                            rawData: data,
                          ));
                        }
                      }

                      final List<ArchiveItem> serviceItems = [];
                      for (final doc in servicesSnap.data?.docs ?? []) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['archived'] == true) {
                          serviceItems.add(ArchiveItem(
                            id: doc.id,
                            title: data['name'] ?? data['title'] ?? 'Service',
                            subtitle: "Category: ${data['category'] ?? 'Printing'} • Rate: ₱${(data['price'] ?? 0).toDouble().toStringAsFixed(2)}",
                            type: 'service',
                            categoryName: 'Printing Services',
                            imageUrl: data['imageUrl'],
                            rawData: data,
                          ));
                        }
                      }

                      final List<ArchiveItem> sampleItems = [];
                      for (final doc in samplesSnap.data?.docs ?? []) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['archived'] == true) {
                          sampleItems.add(ArchiveItem(
                            id: doc.id,
                            title: data['name'] ?? data['title'] ?? 'Sample Work',
                            subtitle: "Category: ${data['category'] ?? 'Portfolio'}",
                            type: 'sample',
                            categoryName: 'Sample Works',
                            imageUrl: data['imageUrl'],
                            rawData: data,
                          ));
                        }
                      }

                      final allItems = [
                        ...userItems,
                        ...serviceItems,
                        ...productItems,
                        ...sampleItems,
                      ];

                      // 2. Filter according to selected category and search query
                      List<ArchiveItem> displayedItems = [];
                      if (_selectedCategory == 'All') {
                        displayedItems = allItems;
                      } else if (_selectedCategory == 'Users') {
                        displayedItems = userItems;
                      } else if (_selectedCategory == 'Printing Services') {
                        displayedItems = serviceItems;
                      } else if (_selectedCategory == 'In-Store Supplies') {
                        displayedItems = productItems;
                      } else if (_selectedCategory == 'Sample Works') {
                        displayedItems = sampleItems;
                      }

                      if (_searchQuery.trim().isNotEmpty) {
                        final query = _searchQuery.toLowerCase();
                        displayedItems = displayedItems.where((i) {
                          return i.title.toLowerCase().contains(query) ||
                              i.subtitle.toLowerCase().contains(query);
                        }).toList();
                      }

                      final totalArchivedCount = allItems.length;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Container matching screenshot
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Green Box Icon
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6F4EA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_rounded,
                                      color: Color(0xFF047857),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Title + Subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              "System Archives",
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD1FAE5),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                "$totalArchivedCount Archived Items",
                                                style: const TextStyle(
                                                  color: Color(0xFF047857),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          "Recycle bin for soft-deleted users, printing services, in-store supplies, and sample works. You can restore or permanently delete items anytime.",
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Refresh Button
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isRefreshing = true;
                                      });
                                      Future.delayed(const Duration(milliseconds: 400), () {
                                        if (mounted) setState(() => _isRefreshing = false);
                                      });
                                    },
                                    icon: _isRefreshing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF334155)),
                                          )
                                        : const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF334155)),
                                    label: const Text(
                                      "Refresh",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Category Filter Bar + Search Bar matching screenshot
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  // Category Filter Pills
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildFilterChip("All Items", totalArchivedCount, "All"),
                                        const SizedBox(width: 8),
                                        _buildFilterChip("Users", userItems.length, "Users"),
                                        const SizedBox(width: 8),
                                        _buildFilterChip("Printing Services", serviceItems.length, "Printing Services"),
                                        const SizedBox(width: 8),
                                        _buildFilterChip("In-Store Supplies", productItems.length, "In-Store Supplies"),
                                        const SizedBox(width: 8),
                                        _buildFilterChip("Sample Works", sampleItems.length, "Sample Works"),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Search Field
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (val) => setState(() => _searchQuery = val),
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      hintText: "Search archived items...",
                                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      isDense: true,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF047857)),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Main Content Area / Empty Box matching screenshot
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 280),
                              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: displayedItems.isEmpty
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Soft grey archive box icon in subtle container
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(
                                            Icons.all_inbox_rounded,
                                            size: 26,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          "No Archived Items Found",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          "Deleted items like users, printing services, in-store products, or sample works will appear here.",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: displayedItems.length,
                                      separatorBuilder: (_, __) => const Divider(height: 20, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (ctx, idx) {
                                        final item = displayedItems[idx];
                                        return Row(
                                          children: [
                                            // Thumbnail / Icon
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                                  ? Image.network(
                                                      item.imageUrl!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => const Icon(
                                                        Icons.inventory_2_outlined,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    )
                                                  : Icon(
                                                      item.type == 'user'
                                                          ? Icons.person_outline_rounded
                                                          : item.type == 'service'
                                                              ? Icons.print_outlined
                                                              : item.type == 'sample'
                                                                  ? Icons.image_outlined
                                                                  : Icons.shopping_bag_outlined,
                                                      color: const Color(0xFF64748B),
                                                      size: 22,
                                                    ),
                                            ),
                                            const SizedBox(width: 12),

                                            // Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          item.title,
                                                          style: const TextStyle(
                                                            fontSize: 13.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF0F172A),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          item.categoryName,
                                                          style: const TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF475569),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    item.subtitle,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Actions
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.restore_from_trash_rounded, color: Color(0xFF047857), size: 20),
                                                  tooltip: "Restore",
                                                  onPressed: () => _restoreItem(item),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 20),
                                                  tooltip: "Permanent Delete",
                                                  onPressed: () => _permanentlyDeleteItem(item),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
