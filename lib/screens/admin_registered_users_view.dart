import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class AdminRegisteredUsersView extends StatefulWidget {
  const AdminRegisteredUsersView({super.key});

  @override
  State<AdminRegisteredUsersView> createState() => _AdminRegisteredUsersViewState();
}

class _AdminRegisteredUsersViewState extends State<AdminRegisteredUsersView> {
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 5;
  String _searchQuery = '';
  final Set<String> _locallyArchivedIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

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
            Icon(Icons.person_add_rounded, color: Color(0xFF4F46E5), size: 20),
            SizedBox(width: 8),
            Text('Add New Customer', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF070A14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF070A14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF070A14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim().toLowerCase();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty || email.isEmpty) return;

              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('users').add({
                  'full_name': name,
                  'email': email,
                  'phone': phone.isNotEmpty ? phone : 'N/A',
                  'role': 'customer',
                  'created_at': FieldValue.serverTimestamp(),
                  'dateJoined': 'Oct 2026',
                  'archived': false,
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Customer $name added!'), backgroundColor: const Color(0xFF10B981)),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding customer: $e'), backgroundColor: const Color(0xFFF43F5E)),
                );
              }
            },
            child: const Text('Add User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameCtrl = TextEditingController(text: user['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: user['phone']?.toString() ?? '');
    final docId = user['docId'].toString();

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
            Icon(Icons.edit_note_rounded, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 8),
            Text('Edit Customer Profile', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User ID & Email info (read-only)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF070A14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF818CF8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['custId'].toString(),
                          style: const TextStyle(color: Color(0xFF818CF8), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user['email'].toString(),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF070A14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF070A14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E293B))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newPhone = phoneCtrl.text.trim();
              if (newName.isEmpty) return;

              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('users').doc(docId).set({
                  'full_name': newName,
                  'name': newName,
                  'phone': newPhone.isNotEmpty ? newPhone : 'N/A',
                  'contact': newPhone.isNotEmpty ? newPhone : 'N/A',
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Customer "$newName" updated successfully!'),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Update failed: $e'),
                    backgroundColor: const Color(0xFFF43F5E),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save Changes', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showArchiveUserDialog(String docId, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: const [
            Icon(Icons.archive_outlined, color: Color(0xFFF59E0B), size: 20),
            SizedBox(width: 8),
            Text('Archive Account', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to archive customer "$userName"?\n\nThis safely deactivates and hides the user from the active Registered System Users list without deleting their account, order history, or loyalty records.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _locallyArchivedIds.add(docId));
              try {
                await FirebaseFirestore.instance.collection('users').doc(docId).set({
                  'archived': true,
                  'isArchived': true,
                  'archivedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Account "$userName" archived safely.'),
                    backgroundColor: const Color(0xFFF59E0B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Account archived locally: $userName'),
                    backgroundColor: const Color(0xFFF59E0B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Archive', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading users: ${snapshot.error}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          );
        }

        final List<Map<String, dynamic>> users = [];
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final isArchived = d['archived'] == true || d['isArchived'] == true || _locallyArchivedIds.contains(doc.id);
            if (isArchived) continue;

            final email = (d['email'] ?? '').toString();
            final name = (d['full_name'] ?? d['displayName'] ?? d['name'] ?? '').toString();
            final phone = (d['phone'] ?? d['contact'] ?? '09170000000').toString();
            final date = (d['dateJoined'] ?? d['regDate'] ?? '2026-10-01').toString();
            final custId = 'CUST-${doc.id.length > 8 ? doc.id.substring(0, 8) : doc.id}';

            users.add({
              'docId': doc.id,
              'custId': custId,
              'name': name.isNotEmpty ? name : (email.contains('@') ? email.split('@').first : 'Customer'),
              'email': email,
              'phone': phone,
              'dateJoined': date,
            });
          }
        }

        // Demo fallback accounts if empty
        if (users.isEmpty && _locallyArchivedIds.isEmpty) {
          users.addAll([
            {'docId': '1', 'custId': 'CUST-167', 'name': 'xian dawinan', 'email': 'xdawinan@gmail.com', 'phone': '09170000000', 'dateJoined': '2026-09-14'},
            {'docId': '2', 'custId': 'CUST-1791408101', 'name': 'xian', 'email': 'xdawinan@gmail.com', 'phone': '09311508184', 'dateJoined': '2026-10-08'},
            {'docId': '3', 'custId': 'CUST-1791914754', 'name': 'jaym', 'email': 'johnuchiha1019@gmail.com', 'phone': '09343464648', 'dateJoined': '2026-10-14'},
            {'docId': '4', 'custId': 'CUST-1791914849', 'name': 'hdndngnfn', 'email': 'xiandawinan86@gmail.com', 'phone': '09565646594', 'dateJoined': '2026-10-14'},
            {'docId': '5', 'custId': 'CUST-1802914120', 'name': 'Maria Santos', 'email': 'maria.santos@gmail.com', 'phone': '09182394124', 'dateJoined': '2026-10-15'},
            {'docId': '6', 'custId': 'CUST-1803914589', 'name': 'Juan Dela Cruz', 'email': 'juan.cruz@gmail.com', 'phone': '09228491024', 'dateJoined': '2026-10-18'},
          ]);
        }

        // Search Filter
        final filteredUsers = users.where((u) {
          if (_searchQuery.isEmpty) return true;
          return u['name'].toString().toLowerCase().contains(_searchQuery) ||
                 u['email'].toString().toLowerCase().contains(_searchQuery) ||
                 u['custId'].toString().toLowerCase().contains(_searchQuery) ||
                 u['phone'].toString().contains(_searchQuery);
        }).toList();

        // Pagination
        final totalPages = (filteredUsers.length / _itemsPerPage).ceil().clamp(1, 9999);
        if (_currentPage > totalPages) _currentPage = totalPages;
        if (_currentPage < 1) _currentPage = 1;
        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex = math.min(startIndex + _itemsPerPage, filteredUsers.length);
        final pagedUsers = filteredUsers.sublist(startIndex, endIndex);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // Top Banner Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1224),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: Color(0xFF818CF8), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Registered Users',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${users.length} Accounts', style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('Manage user accounts, edit details, or archive profiles', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddUserDialog,
                    icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 14),
                    label: const Text('Add User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1224),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: const InputDecoration(
                  hintText: 'Search Name, Email, or User ID...',
                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Users Table Container
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1224),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('REGISTERED SYSTEM USERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                        Text('${filteredUsers.length} Users', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF1E293B)),
                  if (pagedUsers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No registered users found.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pagedUsers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF161F36)),
                      itemBuilder: (context, idx) {
                        final u = pagedUsers[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF1E293B),
                                child: Text(
                                  (u['name'].toString().isNotEmpty ? u['name'].toString()[0] : '?').toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF818CF8), fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // User Info Column with strict ellipsis bounds
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            u['name'].toString(),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            u['custId'].toString(),
                                            style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      u['email'].toString(),
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '📞 ${u['phone']} • Joined: ${u['dateJoined']}',
                                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Action Buttons Row: [Edit] [Archive]
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Edit Button (Blue)
                                  InkWell(
                                    onTap: () => _showEditUserDialog(u),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 13),
                                          SizedBox(width: 3),
                                          Text('Edit', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Archive Button (Amber)
                                  InkWell(
                                    onTap: () => _showArchiveUserDialog(u['docId'].toString(), u['name'].toString()),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.archive_outlined, color: Color(0xFFF59E0B), size: 13),
                                          SizedBox(width: 3),
                                          Text('Archive', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  // Pagination Controls
                  const Divider(height: 1, color: Color(0xFF1E293B)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                          onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                        ),
                        Text(
                          'Page $_currentPage of $totalPages (${filteredUsers.length} users)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
