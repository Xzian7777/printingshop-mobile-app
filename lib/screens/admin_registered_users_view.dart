import '../services/profile_directory.dart';
import '../services/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class AdminRegisteredUsersView extends StatefulWidget {
  const AdminRegisteredUsersView({super.key});

  @override
  State<AdminRegisteredUsersView> createState() =>
      _AdminRegisteredUsersViewState();
}

class _AdminRegisteredUsersViewState extends State<AdminRegisteredUsersView> {
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 5;
  late final Stream<List<ProfileRecord>> _profiles = watchProfiles();
  String _searchQuery = '';

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
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: Row(
          children: const [
            Icon(Icons.person_add_rounded, color: Color(0xFF16A34A), size: 20),
            SizedBox(width: 8),
            Text('Add New Customer',
                style: TextStyle(
                    color: Color(0xFF14532D),
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle:
                    const TextStyle(color: Color(0xFF4B7A5E), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFF8FFF9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle:
                    const TextStyle(color: Color(0xFF4B7A5E), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFF8FFF9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle:
                    const TextStyle(color: Color(0xFF4B7A5E), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFF8FFF9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF4B7A5E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A)),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim().toLowerCase();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty ||
                  !RegExp(r'^[^@\s]+@gmail\.com$').hasMatch(email) ||
                  (phone.isNotEmpty &&
                      !RegExp(r'^09[0-9]{9}$').hasMatch(phone))) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Provide a name, valid Gmail address, and 11-digit phone starting with 09.')));
                return;
              }

              Navigator.pop(ctx);
              try {
                await AdminRepository().saveProfile(
                    FirebaseFirestore.instance.collection('customers').doc().id,
                    {
                      'full_name': name,
                      'email': email,
                      'phone': phone.isNotEmpty ? phone : 'N/A',
                      'role': 'customer',
                      'rfidUid':
                          'RFID-KCZ-${DateTime.now().microsecondsSinceEpoch}',
                      'created_at': FieldValue.serverTimestamp(),
                      'dateJoined':
                          DateTime.now().toIso8601String().split('T').first,
                      'archived': false,
                    },
                    create: true);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Customer $name added!'),
                      backgroundColor: const Color(0xFF10B981)),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error adding customer: $e'),
                      backgroundColor: const Color(0xFFF43F5E)),
                );
              }
            },
            child: const Text('Add User',
                style: TextStyle(
                    color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameCtrl =
        TextEditingController(text: user['name']?.toString() ?? '');
    final phoneCtrl =
        TextEditingController(text: user['phone']?.toString() ?? '');
    final docId = user['docId'].toString();

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
            Icon(Icons.edit_note_rounded, color: Color(0xFF15803D), size: 22),
            SizedBox(width: 8),
            Text('Edit Customer Profile',
                style: TextStyle(
                    color: Color(0xFF14532D),
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
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
                color: const Color(0xFFF8FFF9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined,
                      size: 16, color: Color(0xFF15803D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['custId'].toString(),
                          style: const TextStyle(
                              color: Color(0xFF15803D),
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user['email'].toString(),
                          style: const TextStyle(
                              color: Color(0xFF4B7A5E), fontSize: 10.5),
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
              style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle:
                    const TextStyle(color: Color(0xFF4B7A5E), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFF8FFF9),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle:
                    const TextStyle(color: Color(0xFF4B7A5E), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFF8FFF9),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF4B7A5E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15803D)),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newPhone = phoneCtrl.text.trim();
              if (newName.isEmpty ||
                  (newPhone.isNotEmpty &&
                      newPhone != 'N/A' &&
                      !RegExp(r'^09[0-9]{9}$').hasMatch(newPhone))) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Provide a name and an 11-digit phone starting with 09.')));
                return;
              }

              Navigator.pop(ctx);
              try {
                await AdminRepository().saveProfile(docId, {
                  'email': user['email'],
                  'full_name': newName,
                  'name': newName,
                  'phone': newPhone.isNotEmpty ? newPhone : 'N/A',
                  'contact': newPhone.isNotEmpty ? newPhone : 'N/A',
                  'updatedAt': FieldValue.serverTimestamp(),
                });

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
            child: const Text('Save Changes',
                style: TextStyle(
                    color: Color(0xFFF0FDF4), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showArchiveUserDialog(String docId, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: Row(
          children: const [
            Icon(Icons.archive_outlined, color: Color(0xFFF59E0B), size: 20),
            SizedBox(width: 8),
            Text('Archive Account',
                style: TextStyle(
                    color: Color(0xFF14532D),
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to archive customer "$userName"?\n\nThis safely deactivates and hides the user from the active Registered System Users list without deleting their account, order history, or loyalty records.',
          style: const TextStyle(
              color: Color(0xFF4B7A5E), fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF4B7A5E)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                var snapshot = await FirebaseFirestore.instance
                    .collection('customers')
                    .doc(docId)
                    .get();
                if (!snapshot.exists)
                  snapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(docId)
                      .get();
                await AdminRepository()
                    .archive('user', docId, snapshot.data() ?? {});
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
                    content: Text('Archive failed: $e'),
                    backgroundColor: const Color(0xFFF59E0B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Archive',
                style: TextStyle(
                    color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProfileRecord>>(
      stream: _profiles,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading users: ${snapshot.error}',
                style: const TextStyle(color: Color(0xFF14532D), fontSize: 12)),
          );
        }

        final List<Map<String, dynamic>> users = [];
        if (snapshot.hasData) {
          for (final doc in snapshot.data!) {
            final d = doc.data();
            final isArchived = d['archived'] == true || d['isArchived'] == true;
            if (isArchived) continue;

            final email = (d['email'] ?? '').toString();
            final name = (d['fullName'] ??
                    d['full_name'] ??
                    d['displayName'] ??
                    d['name'] ??
                    '')
                .toString();
            final phone =
                (d['phone'] ?? d['contact'] ?? '09170000000').toString();
            final date =
                (d['dateJoined'] ?? d['regDate'] ?? '2026-10-01').toString();
            final custId =
                'CUST-${doc.id.length > 8 ? doc.id.substring(0, 8) : doc.id}';

            users.add({
              'docId': doc.id,
              'custId': custId,
              'name': name.isNotEmpty
                  ? name
                  : (email.contains('@') ? email.split('@').first : 'Customer'),
              'email': email,
              'phone': phone,
              'dateJoined': date,
            });
          }
        }

        // Demo fallback accounts if empty

        // Search Filter
        final filteredUsers = users.where((u) {
          if (_searchQuery.isEmpty) return true;
          return u['name'].toString().toLowerCase().contains(_searchQuery) ||
              u['email'].toString().toLowerCase().contains(_searchQuery) ||
              u['custId'].toString().toLowerCase().contains(_searchQuery) ||
              u['phone'].toString().contains(_searchQuery);
        }).toList();

        // Pagination
        final totalPages =
            (filteredUsers.length / _itemsPerPage).ceil().clamp(1, 9999);
        if (_currentPage > totalPages) _currentPage = totalPages;
        if (_currentPage < 1) _currentPage = 1;
        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex =
            math.min(startIndex + _itemsPerPage, filteredUsers.length);
        final pagedUsers = filteredUsers.sublist(startIndex, endIndex);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // Top Banner Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.people_alt_rounded,
                        color: Color(0xFF15803D), size: 24),
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
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${users.length} Accounts',
                                  style: const TextStyle(
                                      color: Color(0xFFA5B4FC),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                            'Manage user accounts, edit details, or archive profiles',
                            style: TextStyle(
                                color: Color(0xFF4B7A5E), fontSize: 10.5)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddUserDialog,
                    icon: const Icon(Icons.person_add_rounded,
                        color: Color(0xFF14532D), size: 14),
                    label: const Text('Add User',
                        style: TextStyle(
                            color: Color(0xFF14532D),
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: TextField(
                controller: _searchController,
                style:
                    const TextStyle(color: Color(0xFF14532D), fontSize: 12.5),
                decoration: const InputDecoration(
                  hintText: 'Search Name, Email, or User ID...',
                  hintStyle: TextStyle(color: Color(0xFF4B7A5E), fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Color(0xFF4B7A5E), size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Users Table Container
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('REGISTERED SYSTEM USERS',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Color(0xFF4B7A5E),
                                letterSpacing: 0.5)),
                        Text('${filteredUsers.length} Users',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Color(0xFF4B7A5E))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFBBF7D0)),
                  if (pagedUsers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No registered users found.',
                            style: TextStyle(
                                color: Color(0xFF4B7A5E), fontSize: 12)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pagedUsers.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFF161F36)),
                      itemBuilder: (context, idx) {
                        final u = pagedUsers[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFBBF7D0),
                                child: Text(
                                  (u['name'].toString().isNotEmpty
                                          ? u['name'].toString()[0]
                                          : '?')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF166534),
                                      fontSize: 13),
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
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                                color: Color(0xFF0F172A)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFBBF7D0),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            u['custId'].toString(),
                                            style: const TextStyle(
                                                fontSize: 8.5,
                                                color: Color(0xFF4B7A5E),
                                                fontFamily: 'monospace'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      u['email'].toString(),
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          color: Color(0xFF4B7A5E)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '📞 ${u['phone']} • Joined: ${u['dateJoined']}',
                                      style: const TextStyle(
                                          fontSize: 9.5,
                                          color: Color(0xFF15803D)),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF15803D)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFF15803D)
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.edit_outlined,
                                              color: Color(0xFF15803D),
                                              size: 13),
                                          SizedBox(width: 3),
                                          Text('Edit',
                                              style: TextStyle(
                                                  color: Color(0xFF15803D),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Archive Button (Amber)
                                  InkWell(
                                    onTap: () => _showArchiveUserDialog(
                                        u['docId'].toString(),
                                        u['name'].toString()),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFFF59E0B)
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.archive_outlined,
                                              color: Color(0xFFF59E0B),
                                              size: 13),
                                          SizedBox(width: 3),
                                          Text('Archive',
                                              style: TextStyle(
                                                  color: Color(0xFFF59E0B),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold)),
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
                  const Divider(height: 1, color: Color(0xFFBBF7D0)),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded,
                              color: Color(0xFF14532D), size: 20),
                          onPressed: _currentPage > 1
                              ? () => setState(() => _currentPage--)
                              : null,
                        ),
                        Text(
                          'Page $_currentPage of $totalPages (${filteredUsers.length} users)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF14532D), size: 20),
                          onPressed: _currentPage < totalPages
                              ? () => setState(() => _currentPage++)
                              : null,
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
