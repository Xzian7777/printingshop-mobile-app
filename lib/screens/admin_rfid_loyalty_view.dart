import 'rewards_screen.dart';
import '../services/profile_directory.dart';
import '../services/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class AdminRfidLoyaltyView extends StatefulWidget {
  final String userEmail;

  const AdminRfidLoyaltyView({
    super.key,
    required this.userEmail,
  });

  @override
  State<AdminRfidLoyaltyView> createState() => _AdminRfidLoyaltyViewState();
}

class _AdminRfidLoyaltyViewState extends State<AdminRfidLoyaltyView> {
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _itemsPerPage = 5;
  late final Stream<List<ProfileRecord>> _profiles = watchProfiles();
  String _searchQuery = '';
  bool _isSimulating = false;

  final CollectionReference _rfidLogsRef =
      FirebaseFirestore.instance.collection('rfid_logs');

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

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Recent Active';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} • $hour:$minute $period';
    }
    return timestamp.toString();
  }

  Future<void> _simulateTap([String? specificCardUid, String? custName]) async {
    setState(() => _isSimulating = true);
    var cardUid = specificCardUid ?? '';
    final name = custName ??
        (widget.userEmail.contains('@')
            ? widget.userEmail.split('@').first
            : widget.userEmail);

    try {
      if (specificCardUid != null && cardUid.isEmpty)
        throw StateError('This customer has no assigned RFID card.');
      if (cardUid.isEmpty) {
        final profiles = [
          ...(await FirebaseFirestore.instance.collection('customers').get())
              .docs,
          ...(await FirebaseFirestore.instance.collection('users').get()).docs
        ];
        final assigned = profiles
            .where((p) =>
                p.data()['archived'] != true &&
                (p.data()['rfidUid'] ?? '').toString().isNotEmpty)
            .toList();
        if (assigned.isEmpty) throw StateError('No assigned RFID cards.');
        cardUid = assigned.first.data()['rfidUid'].toString();
      }
      await AdminRepository().tapCard(cardUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('✅ RFID card $cardUid identified for $name.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tap failed: $e'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('loyalty_accounts').snapshots(),
    builder: (context, snapshot) => _buildCards(context, {for (final doc in snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) doc.id: doc.data()}));

  Widget _buildCards(BuildContext context, Map<String, Map<String, dynamic>> balances) {
    return StreamBuilder<List<ProfileRecord>>(
      stream: _profiles,
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              _rfidLogsRef.orderBy('timestamp', descending: true).snapshots(),
          builder: (context, rfidSnap) {
            final List<Map<String, dynamic>> memberCards = [];
            final Set<String> seenEmails = {};

            // 1. Gather all users (customers)
            if (userSnap.hasData) {
              for (final doc in userSnap.data!) {
                final d = doc.data();
                if (d['archived'] == true) continue;
                final email = (d['email'] ?? '').toString().trim();
                final name = (d['fullName'] ??
                        d['full_name'] ??
                        d['displayName'] ??
                        d['name'] ??
                        '')
                    .toString()
                    .trim();
                if (email.isNotEmpty &&
                    !seenEmails.contains(email.toLowerCase())) {
                  seenEmails.add(email.toLowerCase());
                  final custPrefix =
                      email.contains('@') ? email.split('@').first : email;
                  final cardUid =
                      (d['rfidUid'] ?? d['cardUid'] ?? '').toString();
                  final balance = balances['${d['loyaltyUid'] ?? d['uid'] ?? doc.id}'] ?? {};
                  final pts = (balance['balance'] as num? ?? 0) - (balance['reserved'] as num? ?? 0);

                  memberCards.add({
                    'id': doc.id,
                    'name': name.isNotEmpty ? name : custPrefix,
                    'email': email,
                    'cardUid': cardUid,
                    'points': pts.toInt(),
                    'lastTap': 'Recent Active',
                  });
                }
              }
            }

            // 2. Tally extra points & latest tap from rfid logs if available
            final rfidDocs = rfidSnap.hasData ? rfidSnap.data!.docs : [];
            for (final doc in rfidDocs) {
              final d = doc.data() as Map<String, dynamic>;
              final cUid = (d['cardUid'] ?? '').toString();
              final cName = (d['customerName'] ?? '').toString();
              final dtStr = _formatDateTime(d['timestamp']);

              var match = memberCards.firstWhere(
                (m) =>
                    m['cardUid'] == cUid ||
                    m['name'].toString().toLowerCase() == cName.toLowerCase(),
                orElse: () => <String, dynamic>{},
              );

              if (match.isNotEmpty) {
                // Balances are updated atomically on customer profiles; logs are history.
                if (match['lastTap'] == 'Recent Active') {
                  match['lastTap'] = dtStr;
                }
              } else if (cUid.isNotEmpty) {
                memberCards.add({
                  'id': doc.id,
                  'name': cName.isNotEmpty ? cName : 'Valued Customer',
                  'email': '$cName@store.member',
                  'cardUid': cUid,
                  'points': 0,
                  'lastTap': dtStr,
                });
              }
            }

            // Filter
            final filteredCards = memberCards.where((c) {
              if (_searchQuery.isEmpty) return true;
              return c['name']
                      .toString()
                      .toLowerCase()
                      .contains(_searchQuery) ||
                  c['email'].toString().toLowerCase().contains(_searchQuery) ||
                  c['cardUid'].toString().toLowerCase().contains(_searchQuery);
            }).toList();

            // Total stats
            final totalCards = memberCards.length;
            final totalPoints = memberCards.fold<int>(
                0, (total, c) => total + (c['points'] as int));

            // Pagination
            final totalPages =
                (filteredCards.length / _itemsPerPage).ceil().clamp(1, 9999);
            if (_currentPage > totalPages) _currentPage = totalPages;
            if (_currentPage < 1) _currentPage = 1;
            final startIndex = (_currentPage - 1) * _itemsPerPage;
            final endIndex =
                math.min(startIndex + _itemsPerPage, filteredCards.length);
            final pagedCards = filteredCards.sublist(startIndex, endIndex);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsScreen(isAdmin: true))), icon: const Icon(Icons.redeem), label: const Text('Rewards Management')),
                // Top Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF15803D)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.credit_card_rounded,
                                color: Color(0xFF15803D), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'RFID Loyalty & Tap-to-Pay',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: const Text('• Active',
                                          style: TextStyle(
                                              color: Color(0xFF10B981),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                    'Manage customer RFID card points, simulate taps, and rewards',
                                    style: TextStyle(
                                        color: Color(0xFF4B7A5E),
                                        fontSize: 10.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSimulating ? null : () => _simulateTap(),
                          icon: _isSimulating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF14532D), strokeWidth: 2))
                              : const Icon(Icons.satellite_alt_rounded,
                                  color: Color(0xFF14532D), size: 16),
                          label: Text(
                            _isSimulating
                                ? 'Processing Tap...'
                                : 'Identify Counter Card',
                            style: const TextStyle(
                                color: Color(0xFF14532D),
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3 Stats Cards Row
                Row(
                  children: [
                    Expanded(
                        child: _buildMetricCard(
                            'ACTIVE CARDS',
                            '$totalCards',
                            'Member cards',
                            Icons.credit_card_rounded,
                            const Color(0xFF15803D))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildMetricCard(
                            'AVAILABLE POINTS',
                            '$totalPoints PTS',
                            'Accumulated rewards',
                            Icons.star_rounded,
                            const Color(0xFFF59E0B))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildMetricCard(
                            'COUNTER STATUS',
                            'Ready',
                            'RC522 / NFC Counter',
                            Icons.sensors_rounded,
                            const Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                        color: Color(0xFF14532D), fontSize: 12.5),
                    decoration: const InputDecoration(
                      hintText: 'Search Card UID or Customer...',
                      hintStyle:
                          TextStyle(color: Color(0xFF4B7A5E), fontSize: 12),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Color(0xFF4B7A5E), size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Table Container
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
                            const Text(
                              'CUSTOMER CARD REGISTRY',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF4B7A5E),
                                  letterSpacing: 0.5),
                            ),
                            Text(
                              '${filteredCards.length} Cards',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF4B7A5E)),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFBBF7D0)),
                      if (pagedCards.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No RFID cards match your search.',
                                style: TextStyle(
                                    color: Color(0xFF4B7A5E), fontSize: 12)),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pagedCards.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: Color(0xFF161F36)),
                          itemBuilder: (context, idx) {
                            final card = pagedCards[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.credit_card,
                                                size: 13,
                                                color: Color(0xFF15803D)),
                                            const SizedBox(width: 4),
                                            Text(
                                              card['cardUid'].toString().isEmpty
                                                  ? 'Not assigned'
                                                  : card['cardUid'].toString(),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11.5,
                                                  color: Color(0xFF15803D),
                                                  fontFamily: 'monospace'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(card['name'].toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: Color(0xFF0F172A))),
                                        Text(card['email'].toString(),
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF4B7A5E))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      '⭐ ${card['points']} PTS',
                                      style: const TextStyle(
                                          color: Color(0xFFF59E0B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: Color(0xFF15803D),
                                        size: 20),
                                    tooltip: 'Identify Card',
                                    onPressed: () => _simulateTap(
                                        card['cardUid'].toString(),
                                        card['name'].toString()),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      // Pagination Bottom Controls
                      const Divider(height: 1, color: Color(0xFFBBF7D0)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
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
                              'Page $_currentPage of $totalPages (${filteredCards.length} cards)',
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
      },
    );
  }

  Widget _buildMetricCard(
      String title, String val, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B7A5E),
                        letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(val,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 8.5, color: Color(0xFF86EFAC)),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
