import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'login_screen.dart';
import 'store_screen.dart';
import 'place_order_screen.dart';
import 'admin_products_screen.dart';
import '../services/order_repository.dart';

class DashboardScreen extends StatefulWidget {
  final String userEmail;
  const DashboardScreen({super.key, required this.userEmail});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    OrderRepository().syncOfflineOrders();
  }

  int _currentNavIndex = 0;
  int _adminSubTab = 0; // 0: Orders Queue, 1: Live Chat, 2: Analytics, 3: RFID Monitor

  String _statusFilter = 'All Active';
  String _selectedServiceCategory = 'All Services';
  bool _isListView = true;

  // --- ORDERS PAGINATION STATE ---
  int _ordersCurrentPage = 1;
  final int _ordersPerPage = 6;

  final List<String> _serviceCategories = [
    'All Services',
    'Standard A4 Print',
    'Business Cards',
    'Tarpaulins',
    'Flyers & Leaflets',
    'Stickers & Labels',
    'Invitations',
    'Shirt Printing',
    'Photo & Canvas',
    'Booklets & Menus',
    'Mug Printing',
    'In-Store Supplies',
  ];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _chatReplyController = TextEditingController();

  bool get _isAdmin => widget.userEmail.toLowerCase().trim() == 'supernovaelectrodog@gmail.com';

  // FIRESTORE COLLECTIONS
  CollectionReference get _ordersRef => FirebaseFirestore.instance
      .collection('artifacts')
      .doc('printcraft-pro')
      .collection('public')
      .doc('data')
      .collection('orders');

  CollectionReference get _chatsRef => FirebaseFirestore.instance
      .collection('artifacts')
      .doc('printcraft-pro')
      .collection('public')
      .doc('data')
      .collection('chats');

  CollectionReference get _rfidLogsRef => FirebaseFirestore.instance
      .collection('artifacts')
      .doc('printcraft-pro')
      .collection('public')
      .doc('data')
      .collection('rfid_logs');

  @override
  void dispose() {
    _searchController.dispose();
    _chatReplyController.dispose();
    super.dispose();
  }

  // --- TERMS & CONDITIONS DIALOG ---
  void _showTermsAndConditionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.gavel_rounded, color: Color(0xFFE11D48)),
            SizedBox(width: 8),
            Text("Terms & Conditions", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("1. Print File Proofing & Responsibility", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text("Customers are responsible for reviewing uploaded documents, layout sizing, and spelling before submitting print orders.", style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
              SizedBox(height: 10),
              Text("2. Turnaround Time & Processing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text("Standard print jobs take 1-2 business days. Bulk orders (Tarpaulins, Shirts, Booklets) may require additional processing time.", style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
              SizedBox(height: 10),
              Text("3. Cancellation & Non-Refundable Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text("Once a job moves to 'Printing' status, orders cannot be cancelled or refunded due to customized materials used.", style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
              SizedBox(height: 10),
              Text("4. Unclaimed Prints & RFID Rewards", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text("Orders ready for pickup must be claimed within 30 days. RFID loyalty points are earned upon successful payment verification.", style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("I Agree"),
          ),
        ],
      ),
    );
  }

  // LOGOUT DIALOG
  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE11D48)),
            SizedBox(width: 10),
            Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
          ],
        ),
        content: const Text('Are you sure you want to log out of your account?', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 400),
                ),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), elevation: 0),
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _cleanStr(dynamic val) {
    if (val == null) return '';
    return val.toString().toLowerCase().replaceAll('-', '').replaceAll('_', '').replaceAll(' ', '').trim();
  }

  String _formatDateTime(dynamic rawDate) {
    if (rawDate == null) return 'Sep 28, 2026 • 09:47 PM';
    if (rawDate is Timestamp) {
      final dt = rawDate.toDate();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthStr = months[dt.month - 1];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$monthStr ${dt.day}, ${dt.year} • ${hour.toString().padLeft(2, '0')}:$minute $period';
    }
    return rawDate.toString();
  }

  String _getStatusCategory(String rawStatus) {
    final st = rawStatus.toLowerCase().trim();
    if (st.contains('print')) {
      return 'printing';
    } else if (st.contains('ready') || st.contains('pickup')) {
      return 'ready';
    } else if (st.contains('complet') || st.contains('done') || st.contains('finish')) {
      return 'completed';
    } else if (st.contains('reject') || st.contains('cancel')) {
      return 'rejected';
    } else {
      return 'approval';
    }
  }

  bool _checkServiceCategoryMatch(String serviceName, String categoryFilter, Map<String, dynamic> data) {
    if (categoryFilter == 'All Services') return true;
    final s = serviceName.toLowerCase();
    final cat = categoryFilter.toLowerCase();

    if (cat.contains('standard') || cat.contains('a4')) return s.contains('standard') || s.contains('a4') || s.contains('document');
    if (cat.contains('card')) return s.contains('card') || s.contains('business');
    if (cat.contains('tarp')) return s.contains('tarp') || s.contains('banner');
    if (cat.contains('flyer') || cat.contains('leaflet')) return s.contains('flyer') || s.contains('leaflet');
    if (cat.contains('sticker') || cat.contains('label')) return s.contains('sticker') || s.contains('label');
    if (cat.contains('invitat')) return s.contains('invitat');
    if (cat.contains('shirt')) return s.contains('shirt') || s.contains('dtf') || s.contains('apparel');
    if (cat.contains('photo') || cat.contains('canvas')) return s.contains('photo') || s.contains('canvas');
    if (cat.contains('booklet') || cat.contains('menu')) return s.contains('booklet') || s.contains('menu');
    if (cat.contains('mug')) return s.contains('mug');
    if (cat.contains('store') || cat.contains('supply') || cat.contains('in-store')) {
      final paperSize = (data['paperSize'] ?? '').toString().toLowerCase();
      return s.contains('store') || s.contains('supply') || s.contains('in-store') || paperSize.contains('store');
    }
    return s.contains(cat);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE11D48)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('KCZ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAdmin ? 'Kez C-Em Zek (Admin)' : 'Kez C-Em Zek',
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(widget.userEmail, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.gavel_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Terms & Conditions',
            onPressed: () => _showTermsAndConditionsDialog(context),
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0F172A)),
              tooltip: 'Manage Products',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminProductsScreen()));
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48)),
            tooltip: 'Logout',
            onPressed: () => _showLogoutConfirmationDialog(context),
          ),
        ],
      ),
      body: _buildSelectedTabContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) => setState(() => _currentNavIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE11D48),
        unselectedItemColor: const Color(0xFF94A3B8),
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'Store'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    if (_isAdmin) {
      switch (_currentNavIndex) {
        case 0:
          return _buildCustomerHomeTab();
        case 1:
          return const StoreScreen(isAdmin: true, userEmail: 'Admin');
        case 2:
          return _buildAdminDashboardTabsView();
        case 3:
          return _buildCustomersAndProfileView();
        default:
          return _buildCustomerHomeTab();
      }
    } else {
      switch (_currentNavIndex) {
        case 0:
          return _buildCustomerHomeTab();
        case 1:
          return const StoreScreen(isAdmin: false, userEmail: 'Customer');
        case 2:
          return _buildCustomerOrdersTab();
        case 3:
          return _buildProfileTab();
        default:
          return _buildCustomerHomeTab();
      }
    }
  }

  // --- ADMIN MAIN SWITCHER ---
  Widget _buildAdminDashboardTabsView() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAdminSubTabButton(0, 'Orders Queue', Icons.receipt_long_rounded),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(1, 'Live Chat', Icons.chat_bubble_rounded),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(2, 'Analytics', Icons.analytics_rounded),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(3, 'RFID Loyalty', Icons.nfc_rounded),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        Expanded(
          child: _adminSubTab == 0
              ? _buildManageOrdersView()
              : _adminSubTab == 1
              ? _buildAdminLiveChatView()
              : _adminSubTab == 2
              ? _buildAdminAnalyticsView()
              : _buildAdminRfidView(),
        ),
      ],
    );
  }

  Widget _buildAdminSubTabButton(int index, String title, IconData icon) {
    final isSelected = _adminSubTab == index;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
      label: Text(title),
      selected: isSelected,
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (_) => setState(() => _adminSubTab = index),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
    );
  }

  // ===========================================================================
  // 1. LIVE CUSTOMER CHAT SUPPORT
  // ===========================================================================
  Widget _buildAdminLiveChatView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatsRef.orderBy('lastUpdated', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Chat Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final chatDocs = snapshot.data!.docs;

        if (chatDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.chat_outlined, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text('No active customer chats yet.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13)),
                Text('New messages from web/app customers will appear here in realtime.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final doc = chatDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final customerName = (data['customerName'] ?? data['email'] ?? 'Customer').toString();
            final lastMsg = (data['lastMessage'] ?? 'Sent an inquiry...').toString();
            final unread = data['unread'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: unread ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: unread ? const Color(0xFFFFF1F2) : const Color(0xFFF1F5F9),
                  child: Icon(Icons.person, color: unread ? const Color(0xFFE11D48) : const Color(0xFF64748B)),
                ),
                title: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () => _openChatConversationModal(doc.id, customerName),
              ),
            );
          },
        );
      },
    );
  }

  void _openChatConversationModal(String chatId, String customerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(radius: 16, backgroundColor: Color(0xFFFFF1F2), child: Icon(Icons.person, color: Color(0xFFE11D48), size: 18)),
                          const SizedBox(width: 10),
                          Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatsRef.doc(chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final msgs = snapshot.data!.docs;

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: msgs.length,
                        itemBuilder: (context, index) {
                          final mData = msgs[index].data() as Map<String, dynamic>;
                          final isMe = mData['sender'] == 'admin';
                          final text = (mData['text'] ?? '').toString();

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                text,
                                style: TextStyle(color: isMe ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatReplyController,
                          decoration: InputDecoration(
                            hintText: 'Type your reply...',
                            hintStyle: const TextStyle(fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: const Color(0xFFE11D48),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          onPressed: () async {
                            final txt = _chatReplyController.text.trim();
                            if (txt.isNotEmpty) {
                              _chatReplyController.clear();
                              await _chatsRef.doc(chatId).collection('messages').add({
                                'sender': 'admin',
                                'text': txt,
                                'timestamp': FieldValue.serverTimestamp(),
                              });
                              await _chatsRef.doc(chatId).update({
                                'lastMessage': 'Admin: $txt',
                                'lastUpdated': FieldValue.serverTimestamp(),
                                'unread': false,
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 2. FULL ANALYTICS VIEW
  // ===========================================================================
  Widget _buildAdminAnalyticsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Analytics Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        double totalRevenue = 0.0;
        int totalOrders = docs.length;
        int pagesPrinted = 0;
        Set<String> uniqueCustomers = {};
        double storeRevenue = 0.0;
        double printRevenue = 0.0;

        Map<String, int> statusCounts = {
          'Completed': 0,
          'Order Submitted': 0,
          'Printing': 0,
          'Ready for Pickup': 0,
          'Rejected': 0,
        };

        Map<String, int> serviceBreakdown = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;

          final rawTotal = data['total'] ?? data['price'] ?? data['amount'];
          double totalVal = 0.0;
          if (rawTotal is num) totalVal = rawTotal.toDouble();
          if (rawTotal is String) {
            totalVal = double.tryParse(rawTotal.replaceAll('₱', '').replaceAll(',', '').trim()) ?? 0.0;
          }
          totalRevenue += totalVal;

          int copies = int.tryParse((data['copies'] ?? data['quantity'] ?? 1).toString()) ?? 1;
          int pages = int.tryParse((data['pages'] ?? 1).toString()) ?? 1;
          pagesPrinted += (copies * pages);

          final cust = (data['customer'] ?? data['email'] ?? data['customerId'] ?? '').toString().trim();
          if (cust.isNotEmpty) uniqueCustomers.add(cust.toLowerCase());

          final service = (data['service'] ?? data['serviceName'] ?? 'Standard A4 Print').toString();
          serviceBreakdown[service] = (serviceBreakdown[service] ?? 0) + 1;

          final serviceLower = service.toLowerCase();
          if (serviceLower.contains('store') || serviceLower.contains('supply') || serviceLower.contains('in-store')) {
            storeRevenue += totalVal;
          } else {
            printRevenue += totalVal;
          }

          final rawStatus = (data['status'] ?? 'Order Submitted').toString().toLowerCase();
          if (rawStatus.contains('reject') || rawStatus.contains('cancel')) {
            statusCounts['Rejected'] = (statusCounts['Rejected'] ?? 0) + 1;
          } else if (rawStatus.contains('complet') || rawStatus.contains('done')) {
            statusCounts['Completed'] = (statusCounts['Completed'] ?? 0) + 1;
          } else if (rawStatus.contains('ready') || rawStatus.contains('pickup')) {
            statusCounts['Ready for Pickup'] = (statusCounts['Ready for Pickup'] ?? 0) + 1;
          } else if (rawStatus.contains('print')) {
            statusCounts['Printing'] = (statusCounts['Printing'] ?? 0) + 1;
          } else {
            statusCounts['Order Submitted'] = (statusCounts['Order Submitted'] ?? 0) + 1;
          }
        }

        double avgOrderValue = totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;
        int activeCustomersCount = uniqueCustomers.isNotEmpty ? uniqueCustomers.length : (totalOrders > 0 ? 4 : 0);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: [
                _buildWebAnalyticsMetricCard(
                  title: 'TOTAL REVENUE',
                  value: '₱${totalRevenue.toStringAsFixed(2)}',
                  subtitle: 'Print + Store Sales',
                  icon: Icons.monetization_on_rounded,
                  iconColor: const Color(0xFF059669),
                  valueColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                ),
                _buildWebAnalyticsMetricCard(
                  title: 'TOTAL ORDERS',
                  value: '$totalOrders',
                  subtitle: 'Submitted print jobs',
                  icon: Icons.inventory_2_rounded,
                  iconColor: const Color(0xFF2563EB),
                  valueColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                ),
                _buildWebAnalyticsMetricCard(
                  title: 'PAGES PRINTED',
                  value: _formatNumberWithCommas(pagesPrinted),
                  subtitle: 'Total paper consumption',
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  valueColor: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFEEF2FF),
                ),
                _buildWebAnalyticsMetricCard(
                  title: 'TOTAL CUSTOMERS',
                  value: '$activeCustomersCount',
                  subtitle: 'Registered accounts',
                  icon: Icons.people_alt_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  valueColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF5F3FF),
                ),
                _buildWebAnalyticsMetricCard(
                  title: 'AVG ORDER VALUE',
                  value: '₱${avgOrderValue.toStringAsFixed(2)}',
                  subtitle: 'Average spent per ticket',
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFFD97706),
                  valueColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                ),
                _buildWebAnalyticsMetricCard(
                  title: 'STORE REVENUE',
                  value: '₱${storeRevenue.toStringAsFixed(2)}',
                  subtitle: 'School supplies sales',
                  icon: Icons.shopping_cart_rounded,
                  iconColor: const Color(0xFFEA580C),
                  valueColor: const Color(0xFFEA580C),
                  bgColor: const Color(0xFFFFEDD5),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildChartCard(
              title: 'ORDER STATUS DISTRIBUTION',
              subtitle: 'Live active job status breakdown',
              badgeLabel: 'Real-Time',
              badgeColor: const Color(0xFFEFF6FF),
              badgeTextColor: const Color(0xFF2563EB),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _DonutChartPainter(statusCounts: statusCounts),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildChartLegendItem('Completed', const Color(0xFFF59E0B)),
                      _buildChartLegendItem('Order Submitted', const Color(0xFF8B5CF6)),
                      _buildChartLegendItem('Printing', const Color(0xFF3B82F6)),
                      _buildChartLegendItem('Rejected', const Color(0xFFF43F5E)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildChartCard(
              title: 'ORDERS BY SERVICE TYPE',
              subtitle: 'Popular print products volume',
              badgeLabel: 'Live Data',
              badgeColor: const Color(0xFFEEF2FF),
              badgeTextColor: const Color(0xFF4F46E5),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _BarChartPainter(serviceBreakdown: serviceBreakdown),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Flyers & Leaflets • Spiral Notebooks • In-Store Supplies • Invitations',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildChartCard(
              title: 'REVENUE SHARE',
              subtitle: 'Print jobs vs Store supply sales',
              badgeLabel: 'Financials',
              badgeColor: const Color(0xFFECFDF5),
              badgeTextColor: const Color(0xFF059669),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _PieChartPainter(
                        printRevenue: printRevenue > 0 ? printRevenue : 1,
                        storeRevenue: storeRevenue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildChartLegendItem('Print Services', const Color(0xFF2563EB)),
                      const SizedBox(width: 20),
                      _buildChartLegendItem('Store Supplies', const Color(0xFFEA580C)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildWebAnalyticsMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color valueColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 14),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: valueColor, fontFamily: 'monospace'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required String badgeLabel,
    required Color badgeColor,
    required Color badgeTextColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF0F172A), letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                child: Text(badgeLabel, style: TextStyle(color: badgeTextColor, fontWeight: FontWeight.bold, fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
      ],
    );
  }

  String _formatNumberWithCommas(int number) {
    return number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  // ===========================================================================
  // 3. RFID LOYALTY & CARD TAP MONITOR
  // ===========================================================================
  Widget _buildAdminRfidView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _rfidLogsRef.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('RFID Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final rfidDocs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.nfc_rounded, color: Color(0xFF16A34A), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('RFID Reader Active (Store Counter)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Live card taps, customer points & discount tapping', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await _rfidLogsRef.add({
                  'cardUid': 'A4:8F:C2:90',
                  'customerName': 'xdawinan',
                  'pointsAdded': 10,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Simulated RFID Tap registered! (+10 Loyalty Points)')),
                );
              },
              icon: const Icon(Icons.tap_and_play, color: Colors.white, size: 18),
              label: const Text('Simulate Test Card Tap (+10 Points)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('LIVE CARD TAP LOGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            if (rfidDocs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Text('No RFID taps logged yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              )
            else
              ...rfidDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final uid = (data['cardUid'] ?? 'N/A').toString();
                final name = (data['customerName'] ?? 'Customer').toString();
                final pts = data['pointsAdded'] ?? 10;
                final dt = _formatDateTime(data['timestamp']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.credit_card_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$name ($uid)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                            Text(dt, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                        child: Text('+$pts PTS', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // --- HOMEPAGE TAB ---
  Widget _buildCustomerHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isAdmin) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFE11D48).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFFE11D48), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Admin Product Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Edit prices, update stocks & import product photos', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminProductsScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Manage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Kez C-Em Zek Printing Service Web System', style: TextStyle(color: Color(0xFFE11D48), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      onPressed: () => _showTermsAndConditionsDialog(context),
                      icon: const Icon(Icons.gavel_rounded, size: 14, color: Color(0xFFE11D48)),
                      label: const Text('Terms', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Streamlined Printing Orders with Real-Time Tracking & RFID Rewards', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.2)),
                const SizedBox(height: 10),
                const Text('A clean, unified web solution for modern print shops: instant file proofing, accurate price calculations, stage-by-stage order monitoring, customer-staff live chat, RFID loyalty tapping, and real-time paper stock level sensors.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _currentNavIndex = 2),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('View Orders →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentNavIndex = 1),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text('Store Supplies', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('OUR SERVICES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFE11D48), letterSpacing: 1.2)),
          const SizedBox(height: 4),
          const Text('Everything your business needs printed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Text('Pick a service to see options and pricing.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: [
              _buildWebServiceCard('Standard Document Print', 'Short, Long, A4 paper in Black & White or Full Color.', 'Starts at ₱3.00 / page', Icons.description_rounded, const Color(0xFFFFF1F2), const Color(0xFFE11D48)),
              _buildWebServiceCard('PVC ID & Badge Printing', 'Durable waterproof PVC cards for school or work IDs.', 'Starts at ₱50.00 / card', Icons.badge_rounded, const Color(0xFFFEF3C7), const Color(0xFFD97706)),
              _buildWebServiceCard('Sticker & Label Printing', 'Glossy, Matte, or Vinyl die-cut stickers for packaging.', 'Starts at ₱45.00 / sheet', Icons.auto_awesome_rounded, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
              _buildWebServiceCard('Store & Office Supplies', 'Notebooks, pens, clear books, folders, and paper packs.', 'Available in Store Tab', Icons.storefront_rounded, const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWebServiceCard(String title, String desc, String price, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 20, color: iconColor)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 3, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF059669))),
        ],
      ),
    );
  }

  // --- MANAGE ORDERS VIEW ---
  Widget _buildManageOrdersView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        int approvalCount = 0;
        int printingCount = 0;
        int readyCount = 0;

        for (var d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final category = _getStatusCategory((data['status'] ?? '').toString());
          if (category == 'approval') approvalCount++;
          if (category == 'printing') printingCount++;
          if (category == 'ready') readyCount++;
        }

        final queryClean = _cleanStr(_searchController.text);

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rawStatus = (data['status'] ?? 'Order Submitted').toString();
          final category = _getStatusCategory(rawStatus);
          final serviceName = (data['service'] ?? data['serviceName'] ?? '').toString();

          bool matchesCategory = _checkServiceCategoryMatch(serviceName, _selectedServiceCategory, data);
          bool matchesSearch = queryClean.isEmpty;
          if (!matchesSearch) {
            String fullDocString = '${_cleanStr(doc.id)} ${_cleanStr(data.toString())}';
            if (fullDocString.contains(queryClean)) matchesSearch = true;
          }

          bool matchesStatus = true;
          if (queryClean.isEmpty) {
            if (_statusFilter == 'All Active') {
              matchesStatus = (category != 'completed' && category != 'rejected');
            } else if (_statusFilter == 'For Approval') {
              matchesStatus = (category == 'approval');
            } else if (_statusFilter == 'Printing') {
              matchesStatus = (category == 'printing');
            } else if (_statusFilter == 'Ready for Pickup') {
              matchesStatus = (category == 'ready');
            } else if (_statusFilter == 'Completed') {
              matchesStatus = (category == 'completed');
            } else if (_statusFilter == 'Rejected / Cancelled') {
              matchesStatus = (category == 'rejected');
            }
          }

          return matchesCategory && matchesSearch && matchesStatus;
        }).toList();

        // ORDERS PAGINATION CALCULATION
        int totalPages = (filteredDocs.length / _ordersPerPage).ceil();
        if (totalPages < 1) totalPages = 1;
        if (_ordersCurrentPage > totalPages) _ordersCurrentPage = totalPages;
        if (_ordersCurrentPage < 1) _ordersCurrentPage = 1;

        int startIndex = (_ordersCurrentPage - 1) * _ordersPerPage;
        int endIndex = math.min(startIndex + _ordersPerPage, filteredDocs.length);
        final pagedDocs = filteredDocs.sublist(startIndex, endIndex);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.print_rounded, color: Color(0xFFE11D48))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Print Production Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                  child: Text('${docs.length} Active', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text('Organized print job management • FIFO', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatusCounterBox('APPROVAL', approvalCount.toString(), const Color(0xFFFEF3C7), const Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      _buildStatusCounterBox('PRINTING', printingCount.toString(), const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      _buildStatusCounterBox('READY', readyCount.toString(), const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() => _ordersCurrentPage = 1),
              decoration: InputDecoration(
                hintText: 'Search PRNT-7767, Client, or Item...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _serviceCategories.contains(_selectedServiceCategory) ? _selectedServiceCategory : 'All Services',
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF0F172A)),
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedServiceCategory = val;
                            _ordersCurrentPage = 1;
                          });
                        }
                      },
                      items: _serviceCategories.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      _buildViewToggleBtn('List', Icons.list_alt_rounded, _isListView, () => setState(() => _isListView = true)),
                      _buildViewToggleBtn('Cards', Icons.grid_view_rounded, !_isListView, () => setState(() => _isListView = false)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All Active', 'For Approval', 'Printing', 'Ready for Pickup', 'Completed', 'Rejected / Cancelled'].map((status) {
                  final isSelected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (val) => setState(() {
                        _statusFilter = status;
                        _ordersCurrentPage = 1;
                      }),
                      selectedColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF334155), fontSize: 11, fontWeight: FontWeight.bold),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0))),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            if (pagedDocs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF1F5F9))),
                child: Text('No matching orders found under "$_selectedServiceCategory".', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13)),
              )
            else
              ...pagedDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final String displayRefId = (data['id'] ?? data['refId'] ?? data['ref_id'] ?? data['orderNumber'] ?? (docId.length > 10 ? 'PRNT-${docId.substring(0, 6).toUpperCase()}' : docId)).toString();
                final serviceName = (data['service'] ?? data['serviceName'] ?? data['item_name'] ?? 'Standard A4 Print').toString();
                final customer = (data['customer'] ?? data['userEmail'] ?? data['fullName'] ?? 'Customer').toString();
                final rawTotal = data['total'] ?? data['price'] ?? data['amount'];
                final String totalStr = rawTotal != null ? (rawTotal is num ? '₱${rawTotal.toStringAsFixed(2)}' : rawTotal.toString()) : '₱30.00';
                final status = (data['status'] ?? 'Order Submitted').toString();
                final payment = (data['payment'] ?? data['payment_method'] ?? 'GCash').toString();
                final dateTimeStr = _formatDateTime(data['createdAt'] ?? data['created_at'] ?? data['timestamp'] ?? data['date'] ?? data['time']);

                return _isListView
                    ? _buildOrderListItem(docId, displayRefId, serviceName, customer, totalStr, status, payment, dateTimeStr, data)
                    : _buildOrderCardItem(docId, displayRefId, serviceName, customer, totalStr, status, payment, dateTimeStr, data);
              }),

            // ORDERS PAGINATION BOTTOM BAR (WITH EDGEINSETS.ONLY FIX)
            if (filteredDocs.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _ordersCurrentPage > 1
                          ? () => setState(() => _ordersCurrentPage--)
                          : null,
                    ),
                    Text(
                      "Page $_ordersCurrentPage of $totalPages (${filteredDocs.length} orders)",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _ordersCurrentPage < totalPages
                          ? () => setState(() => _ordersCurrentPage++)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildViewToggleBtn(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCardItem(String docId, String refId, String service, String customer, String total, String status, String payment, String dateTimeStr, Map<String, dynamic> data) {
    final statusCategory = _getStatusCategory(status);
    Color statusBgColor = const Color(0xFFFEF3C7);
    Color statusTextColor = const Color(0xFFD97706);
    if (statusCategory == 'printing') {
      statusBgColor = const Color(0xFFEFF6FF);
      statusTextColor = const Color(0xFF2563EB);
    } else if (statusCategory == 'ready') {
      statusBgColor = const Color(0xFFDCFCE7);
      statusTextColor = const Color(0xFF16A34A);
    } else if (statusCategory == 'completed') {
      statusBgColor = const Color(0xFFECFDF5);
      statusTextColor = const Color(0xFF059669);
    } else if (statusCategory == 'rejected') {
      statusBgColor = const Color(0xFFFFE4E6);
      statusTextColor = const Color(0xFFE11D48);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(refId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusTextColor))),
            ],
          ),
          const SizedBox(height: 8),
          Text(customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(service, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF059669))),
              _buildDynamicActionButton(docId, status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListItem(String docId, String refId, String service, String customer, String total, String status, String payment, String dateTimeStr, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(refId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669))),
            ],
          ),
          const SizedBox(height: 4),
          Text(customer, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Text(service, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)), child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
              _buildDynamicActionButton(docId, status),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndUpdateOrderStatus(String orderId, String newStatus, String actionLabel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF0F172A)),
            SizedBox(width: 8),
            Text('Confirm Action', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to change order status to "$newStatus"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(c, true),
            child: Text(actionLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _ordersRef.doc(orderId).update({'status': newStatus});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to "$newStatus"')),
      );
    }
  }

  Widget _buildDynamicActionButton(String orderId, String status) {
    final category = _getStatusCategory(status);
    if (category == 'approval') {
      return ElevatedButton(
        onPressed: () => _confirmAndUpdateOrderStatus(orderId, 'Printing', 'Approve Order'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        child: const Text('Approve', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
      );
    } else if (category == 'printing') {
      return ElevatedButton(
        onPressed: () => _confirmAndUpdateOrderStatus(orderId, 'Ready for Pickup', 'Mark Ready'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        child: const Text('Mark Ready', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
      );
    } else if (category == 'ready') {
      return ElevatedButton(
        onPressed: () => _confirmAndUpdateOrderStatus(orderId, 'Completed', 'Complete Order'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        child: const Text('Complete', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
      );
    } else {
      return const Text('Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)));
    }
  }

  Widget _buildStatusCounterBox(String label, String count, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 2),
            Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersAndProfileView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9))),
          child: Row(
            children: [
              const CircleAvatar(radius: 24, backgroundColor: Color(0xFFFFF1F2), child: Icon(Icons.admin_panel_settings, color: Color(0xFFE11D48))),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Administrator Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(widget.userEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: Colors.white,
          leading: const Icon(Icons.gavel_rounded, color: Color(0xFFE11D48)),
          title: const Text("Terms and Conditions", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _showTermsAndConditionsDialog(context),
        ),
      ],
    );
  }

  Widget _buildCustomerOrdersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PlaceOrderScreen(userEmail: widget.userEmail)));
                  },
                  icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
                  label: const Text('Place New Print Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showTermsAndConditionsDialog(context),
                child: const Text(
                  "By placing an order, you agree to our Terms & Conditions →",
                  style: TextStyle(fontSize: 10.5, color: Color(0xFFE11D48), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _ordersRef.where('email', isEqualTo: widget.userEmail).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFE11D48)),
                        SizedBox(height: 8),
                        Text('Nabigo sa pagkonekta sa database.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('Gumagamit ng local offline cache kung available.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('Wala ka pang order.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)));
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['id'] ?? 'PRNT-xxxx', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(data['service'] ?? 'Print Service', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                        Text('Total: ₱${data['total'] ?? '30.00'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(radius: 36, backgroundColor: Color(0xFFFFF1F2), child: Icon(Icons.person, color: Color(0xFFE11D48))),
          const SizedBox(height: 12),
          Text(widget.userEmail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showTermsAndConditionsDialog(context),
            icon: const Icon(Icons.gavel_rounded, size: 16, color: Color(0xFFE11D48)),
            label: const Text("Terms & Conditions", style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showLogoutConfirmationDialog(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CUSTOM PAINTERS (CHARTS)
// =============================================================================
class _DonutChartPainter extends CustomPainter {
  final Map<String, int> statusCounts;
  _DonutChartPainter({required this.statusCounts});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.2;
    final strokeWidth = 24.0;

    final total = statusCounts.values.fold(0, (sum, val) => sum + val);
    if (total == 0) return;

    double startAngle = -math.pi / 2;

    final colors = {
      'Completed': const Color(0xFFF59E0B),
      'Order Submitted': const Color(0xFF8B5CF6),
      'Printing': const Color(0xFF3B82F6),
      'Rejected': const Color(0xFFF43F5E),
      'Ready for Pickup': const Color(0xFF10B981),
    };

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    statusCounts.forEach((key, count) {
      if (count > 0) {
        final sweepAngle = (count / total) * 2 * math.pi;
        paint.color = colors[key] ?? const Color(0xFFCBD5E1);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          startAngle,
          sweepAngle - 0.04,
          false,
          paint,
        );
        startAngle += sweepAngle;
      }
    });
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}

class _BarChartPainter extends CustomPainter {
  final Map<String, int> serviceBreakdown;
  _BarChartPainter({required this.serviceBreakdown});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF3B82F6);
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height - (i * (size.height / 4));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final entries = serviceBreakdown.entries.toList();
    if (entries.isEmpty) return;

    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal > 0 ? maxVal : 25;

    final barSpacing = size.width / (entries.length * 1.5 + 1);
    final barWidth = barSpacing * 0.8;

    double currentX = barSpacing;

    for (var entry in entries) {
      final barHeight = (entry.value / effectiveMax) * (size.height - 20);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(currentX, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(4),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(currentX, 0, barWidth, size.height),
          const Radius.circular(4),
        ),
        bgPaint,
      );

      canvas.drawRRect(rect, paint);
      currentX += barWidth + barSpacing * 0.7;
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

class _PieChartPainter extends CustomPainter {
  final double printRevenue;
  final double storeRevenue;

  _PieChartPainter({required this.printRevenue, required this.storeRevenue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.1;

    final total = printRevenue + storeRevenue;
    if (total <= 0) return;

    final printSweep = (printRevenue / total) * 2 * math.pi;
    final storeSweep = (storeRevenue / total) * 2 * math.pi;

    final paintPrint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    final paintStore = Paint()
      ..color = const Color(0xFFEA580C)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      printSweep,
      true,
      paintPrint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + printSweep,
      storeSweep,
      true,
      paintStore,
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) => true;
}