import '../services/auth_service.dart';
import '../services/display_text.dart';
import 'rewards_screen.dart';
import '../services/app_notifications.dart';
import '../services/notification_destination.dart';
import '../widgets/notification_bell.dart';
import '../services/order_cancellation.dart';
import '../widgets/order_cancel_dialog.dart';
import 'admin_pos_view.dart';
import '../widgets/customer_order_card.dart';
import '../widgets/dashboard_controls.dart';
import '../theme/dashboard_theme.dart';
import '../services/order_workflow.dart';
import 'admin_archive_screen.dart';
import 'admin_catalog_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'login_screen.dart';
import 'store_screen.dart';
import 'place_order_screen.dart';
import 'customer_chat_screen.dart';
import 'admin_live_chat_view.dart' hide getSafeConversationId;
import 'admin_rfid_loyalty_view.dart';
import 'admin_registered_users_view.dart';
import '../services/order_repository.dart';
import '../services/fcm_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatelessWidget {
  final String userEmail;
  final bool isAdmin;
  final int? initialNavIndex;
  final int initialAdminTab;
  const DashboardScreen(
      {super.key,
      required this.userEmail,
      required this.isAdmin,
      this.initialNavIndex,
      this.initialAdminTab = 0});

  @override
  Widget build(BuildContext context) => Theme(
        data: DashboardTheme.light,
        child: _DashboardContent(
            userEmail: userEmail,
            isAdmin: isAdmin,
            initialNavIndex: initialNavIndex,
            initialAdminTab: initialAdminTab),
      );
}

class _DashboardContent extends StatefulWidget {
  final String userEmail;
  final bool isAdmin;
  final int? initialNavIndex;
  final int initialAdminTab;

  const _DashboardContent({
    required this.userEmail,
    required this.isAdmin,
    this.initialNavIndex,
    this.initialAdminTab = 0,
  });

  @override
  State<_DashboardContent> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialNavIndex ?? (widget.isAdmin ? 2 : 0);
    _adminSubTab = widget.initialAdminTab;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FcmService().registerUserToken(widget.userEmail);
      if (mounted) FcmService().activateNavigation();
    });
    OrderRepository().syncOfflineOrders();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  int _currentNavIndex = 0;
  int _adminSubTab =
      0; // 0: Orders Management, 1: Live Chat, 2: Analytics, 3: RFID Loyalty, 4: Registered Users, 5: Samples, 6: Services, 7: GCash, 8: Archive

  String _statusFilter = 'All Active';
  String _selectedServiceCategory = 'All Services';
  String _orderSortOrder =
      'Latest to Previous'; // 'Latest to Previous' or 'Previous to Latest'
  bool _isListView = true;

  // --- CUSTOMER TRACKER STATE ---
  String _customerFilter = 'All Orders';
  String _customerCategoryFilter = 'All Services & Store Items';
  Key _customerTrackerRefreshKey = UniqueKey();
  int _customerOrdersCurrentPage = 1;
  final int _customerOrdersPerPage = 5;

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

  bool get _isAdmin => widget.isAdmin;

  // FIRESTORE COLLECTIONS
  CollectionReference get _ordersRef => FirebaseFirestore.instance
      .collection('artifacts')
      .doc('printcraft-pro')
      .collection('public')
      .doc('data')
      .collection('orders');

  CollectionReference get _rfidLogsRef => FirebaseFirestore.instance
      .collection('artifacts')
      .doc('printcraft-pro')
      .collection('public')
      .doc('data')
      .collection('rfid_logs');

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    _chatReplyController.dispose();
    super.dispose();
  }

  // --- TERMS & CONDITIONS DIALOG ---
  void _showTermsAndConditionsDialog(BuildContext context) {
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
            Icon(Icons.gavel_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text("Terms & Conditions",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("1. Print File Proofing & Responsibility",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text(
                  "Customers are responsible for reviewing uploaded documents, layout sizing, and spelling before submitting print orders.",
                  style: TextStyle(fontSize: 11, color: Color(0xFF4B7A5E))),
              SizedBox(height: 10),
              Text("2. Turnaround Time & Processing",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text(
                  "Standard print jobs take 1-2 business days. Bulk orders (Tarpaulins, Shirts, Booklets) may require additional processing time.",
                  style: TextStyle(fontSize: 11, color: Color(0xFF4B7A5E))),
              SizedBox(height: 10),
              Text("3. Cancellation & Non-Refundable Items",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text(
                  "Orders can be cancelled only before admin approval. Approved orders can no longer be cancelled.",
                  style: TextStyle(fontSize: 11, color: Color(0xFF4B7A5E))),
              SizedBox(height: 10),
              Text("4. Unclaimed Prints & RFID Rewards",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text(
                  "Orders ready for pickup must be claimed within 30 days. One loyalty point is earned per paid completed order. Points discounts cover up to 50% of the order subtotal.",
                  style: TextStyle(fontSize: 11, color: Color(0xFF4B7A5E))),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: DashboardTheme.green,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("I Agree"),
          ),
        ],
      ),
    );
  }

  // LOGOUT DIALOG
  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Color(0xFF15803D)),
            SizedBox(width: 10),
            Text('Exit App',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0F172A))),
          ],
        ),
        content: const Text(
          'Are you sure you want to close and exit the app?',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B7A5E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF4B7A5E), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardTheme.green,
              elevation: 0,
            ),
            child: const Text('Exit',
                style: TextStyle(
                    color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFF43F5E)),
            SizedBox(width: 10),
            Text('Confirm Logout',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0F172A))),
          ],
        ),
        content: const Text('Are you sure you want to log out of your account?',
            style: TextStyle(fontSize: 13, color: Color(0xFF4B7A5E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF4B7A5E), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FcmService().removeUserToken(widget.userEmail);
                await AuthService.signOut();
              } catch (e) {
                debugPrint('Logout error: $e');
              }
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const LoginScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 400),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E), elevation: 0),
            child: const Text('Log Out',
                style: TextStyle(
                    color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _cleanStr(dynamic val) {
    if (val == null) return '';
    return val
        .toString()
        .toLowerCase()
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .trim();
  }

  String _formatDateTime(dynamic rawDate) {
    final parsed = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is DateTime
            ? rawDate
            : DateTime.tryParse('$rawDate');
    if (parsed != null) {
      final dt = parsed.toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final monthStr = months[dt.month - 1];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$monthStr ${dt.day}, ${dt.year} • ${hour.toString().padLeft(2, '0')}:$minute $period';
    }
    return rawDate?.toString() ?? 'Date unavailable';
  }

  String _getStatusCategory(String rawStatus) {
    final st = rawStatus.toLowerCase().trim();
    if (st == 'cancelled') return 'cancelled';
    if (st == 'approved') return 'approved';
    if (st.contains('print') || st.contains('prepar')) {
      return 'printing';
    } else if (st.contains('ready') || st.contains('pickup')) {
      return 'ready';
    } else if (st.contains('complet') ||
        st.contains('done') ||
        st.contains('finish')) {
      return 'completed';
    } else if (st.contains('reject') || st.contains('cancel')) {
      return 'rejected';
    } else {
      return 'approval';
    }
  }

  bool _checkServiceCategoryMatch(
      String serviceName, String categoryFilter, Map<String, dynamic> data) {
    if (categoryFilter == 'All Services') return true;
    final s = serviceName.toLowerCase();
    final cat = categoryFilter.toLowerCase();

    if (cat.contains('standard') || cat.contains('a4'))
      return s.contains('standard') ||
          s.contains('a4') ||
          s.contains('document');
    if (cat.contains('card'))
      return s.contains('card') || s.contains('business');
    if (cat.contains('tarp')) return s.contains('tarp') || s.contains('banner');
    if (cat.contains('flyer') || cat.contains('leaflet'))
      return s.contains('flyer') || s.contains('leaflet');
    if (cat.contains('sticker') || cat.contains('label'))
      return s.contains('sticker') || s.contains('label');
    if (cat.contains('invitat')) return s.contains('invitat');
    if (cat.contains('shirt'))
      return s.contains('shirt') || s.contains('dtf') || s.contains('apparel');
    if (cat.contains('photo') || cat.contains('canvas'))
      return s.contains('photo') || s.contains('canvas');
    if (cat.contains('booklet') || cat.contains('menu'))
      return s.contains('booklet') || s.contains('menu');
    if (cat.contains('mug')) return s.contains('mug');
    if (cat.contains('store') ||
        cat.contains('supply') ||
        cat.contains('in-store')) {
      final paperSize = (data['paperSize'] ?? '').toString().toLowerCase();
      return s.contains('store') ||
          s.contains('supply') ||
          s.contains('in-store') ||
          paperSize.contains('store');
    }
    return s.contains(cat);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        // If not on Home tab (e.g. Orders, Store, Profile), return to Home tab first
        if (_currentNavIndex != 0) {
          setState(() => _currentNavIndex = 0);
          return;
        }

        // If already on Home tab, show exit confirmation dialog
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FFF9),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8FFF9),
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFBBF7D0)),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/images/kcz_logo.jpg',
                      fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isAdmin ? 'KCZ Printing (Admin)' : 'KCZ Printing',
                      style: const TextStyle(
                          color: Color(0xFF14532D),
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(widget.userEmail,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF4B7A5E), fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (_isAdmin) IconButton(tooltip: 'Rewards Management', icon: const Icon(Icons.redeem, color: DashboardTheme.green),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RewardsScreen(isAdmin: _isAdmin)))),
            if (FirebaseAuth.instance.currentUser != null)
              NotificationBell(
                repository: NotificationRepository(
                  uid: FirebaseAuth.instance.currentUser!.uid,
                  email: widget.userEmail,
                  admin: _isAdmin,
                ),
                onOpen: _openNotification,
              ),
            if (!_isAdmin)
              IconButton(
                icon:
                    const Icon(Icons.person_rounded, color: Color(0xFF15803D)),
                tooltip: 'Profile',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: const Color(0xFFF8FFF9),
                        appBar: AppBar(title: const Text('Profile')),
                        body: _buildProfileTab(),
                      ),
                    )),
              ),
            if (!_isAdmin)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .doc(getSafeConversationId(widget.userEmail))
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final bool hasUnread =
                      (data?['unreadCountCustomer'] as num? ?? 0) > 0 ||
                          data?['customerUnread'] == true;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF15803D)),
                        tooltip: 'Live Chat Support',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerChatScreen(
                                  userEmail: widget.userEmail),
                            ),
                          );
                        },
                      ),
                      if (hasUnread)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF43F5E),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (_isAdmin)
              IconButton(
                icon:
                    const Icon(Icons.archive_rounded, color: Color(0xFF15803D)),
                tooltip: 'System Archive',
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminArchiveScreen()));
                },
              ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFF43F5E)),
              tooltip: 'Logout',
              onPressed: () => _showLogoutConfirmationDialog(context),
            ),
          ],
        ),
        extendBody: true,
        body: _buildSelectedTabContent(),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: const Color(0xFFBBF7D0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFloatingNavItem(0, Icons.home_rounded, 'Home'),
                  _buildFloatingNavItem(1, Icons.storefront_rounded, 'Store'),
                  _buildFloatingNavItem(
                      2,
                      _isAdmin
                          ? Icons.receipt_long_rounded
                          : Icons.print_rounded,
                      _isAdmin ? 'Orders' : 'Order Services'),
                  _buildFloatingNavItem(
                      3,
                      _isAdmin
                          ? Icons.person_rounded
                          : Icons.receipt_long_rounded,
                      _isAdmin ? 'Profile' : 'My Orders'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    // Vibrant neon lime matching the reference image, with muted gray when unselected
    const activeColor = Color(0xFF15803D);
    const inactiveColor = Color(0xFF64748B);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: () {
            if (!_isAdmin && index == 2) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PlaceOrderScreen(userEmail: widget.userEmail),
                  ));
              return;
            }
            setState(() => _currentNavIndex = index);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
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
          return StoreScreen(isAdmin: false, userEmail: widget.userEmail);
        case 2:
          return _buildCustomerOrdersTab();
        case 3:
          return _buildCustomerOrdersTab();
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
                _buildAdminSubTabButton(
                    0, 'Manage Orders', Icons.receipt_long_rounded),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(9, 'POS', Icons.point_of_sale),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(
                    1, 'Live Chat', Icons.chat_bubble_rounded),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(
                    2, 'Analytics', Icons.analytics_rounded),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(3, 'RFID Cards', Icons.nfc_rounded),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(4, 'Users', Icons.people_alt_rounded),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(
                    5, 'Samples & Services', Icons.palette_outlined),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(6, 'Place Order', Icons.print_rounded),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(
                    7, 'GCash Settings', Icons.payments_outlined),
                const SizedBox(width: 8),
                _buildAdminSubTabButton(8, 'Archive', Icons.archive_outlined),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFBBF7D0)),
        Expanded(
          child: _adminSubTab == 0
              ? _buildManageOrdersView()
              : _adminSubTab == 1
                  ? _buildAdminLiveChatView()
                  : _adminSubTab == 2
                      ? _buildAdminAnalyticsView()
                      : _adminSubTab == 3
                          ? AdminRfidLoyaltyView(userEmail: widget.userEmail)
                          : _adminSubTab == 4
                              ? const AdminRegisteredUsersView()
                              : _adminSubTab == 5
                                  ? Theme(
                                      data: ThemeData.light().copyWith(
                                          colorScheme: ColorScheme.fromSeed(
                                              seedColor:
                                                  const Color(0xFF15803D))),
                                      child: const AdminCatalogView(
                                          services: false))
                                  : _adminSubTab == 6
                                      ? Theme(
                                          data: ThemeData.light().copyWith(
                                              colorScheme: ColorScheme.fromSeed(
                                                  seedColor:
                                                      const Color(0xFF15803D))),
                                          child: const AdminCatalogView(
                                              services: true))
                                      : _adminSubTab == 7
                                          ? Theme(
                                              data: ThemeData.light().copyWith(
                                                  colorScheme:
                                                      ColorScheme.fromSeed(
                                                          seedColor:
                                                              const Color(
                                                                  0xFF15803D))),
                                              child: const AdminGcashView())
                                          : _adminSubTab == 9
                                              ? const AdminPosView()
                                              : const AdminArchiveScreen(
                                                  embedded: true),
        ),
      ],
    );
  }

  Widget _buildAdminSubTabButton(int index, String title, IconData icon) {
    final isSelected = _adminSubTab == index;
    return ChoiceChip(
      avatar: Icon(icon,
          size: 16, color: isSelected ? Colors.white : const Color(0xFF4B7A5E)),
      label: Text(title),
      selected: isSelected,
      selectedColor: DashboardTheme.green,
      backgroundColor: const Color(0xFFF0FDF4),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF4B7A5E),
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (_) => setState(() => _adminSubTab = index),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color:
                isSelected ? const Color(0xFF16A34A) : const Color(0xFFBBF7D0)),
      ),
    );
  }

  // ===========================================================================
  // 1. LIVE CUSTOMER CHAT SUPPORT
  // ===========================================================================
  void _openNotification(InboxNotification notification) {
    final destination = notificationDestination(notification.destination);
    if (destination == 'chat') {
      if (_isAdmin) {
        final conversation = notification.data['conversationId']?.toString() ??
            Uri.tryParse('${notification.data['link'] ?? ''}')?.queryParameters['convId'];
        Navigator.push(context, MaterialPageRoute(builder: (_) => Theme(
          data: DashboardTheme.light,
          child: Scaffold(appBar: AppBar(title: const Text('Messages')),
            body: AdminLiveChatView(initialConversationId: conversation)),
        )));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerChatScreen(userEmail: widget.userEmail)));
      }
      return;
    }
    setState(() {
      _currentNavIndex = _isAdmin ? 2 : 3;
      _adminSubTab = 0;
      _statusFilter = 'All Active';
      _selectedServiceCategory = 'All Services';
      _ordersCurrentPage = 1;
      _searchController.clear();
      _customerFilter = 'All Orders';
      _customerCategoryFilter = 'All Services & Store Items';
      _customerOrdersCurrentPage = 1;
    });
  }

  Widget _buildAdminLiveChatView() {
    return const AdminLiveChatView();
  }

  // ===========================================================================
  // 2. FULL ANALYTICS VIEW
  // ===========================================================================
  Widget _buildAdminAnalyticsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
              child: Text('Analytics Error: ${snapshot.error}',
                  style: const TextStyle(color: DashboardTheme.ink)));
        if (!snapshot.hasData)
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)));

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
          'Approved': 0,
          'Printing': 0,
          'Ready for Pickup': 0,
          'Rejected': 0,
          'Cancelled': 0,
        };

        Map<String, int> serviceBreakdown = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;

          final rawTotal = data['total'] ?? data['price'] ?? data['amount'];
          double totalVal = 0.0;
          if (rawTotal is num) totalVal = rawTotal.toDouble();
          if (rawTotal is String) {
            totalVal = double.tryParse(
                    rawTotal.replaceAll('₱', '').replaceAll(',', '').trim()) ??
                0.0;
          }
          final cancelled = '${data['status']}'.toLowerCase() == 'cancelled';
          if (cancelled) totalVal = 0;
          totalRevenue += totalVal;

          int copies = int.tryParse(
                  (data['copies'] ?? data['quantity'] ?? 1).toString()) ??
              1;
          int pages = int.tryParse((data['pages'] ?? 1).toString()) ?? 1;
          if (data['source'] != 'POS' && !cancelled)
            pagesPrinted += (copies * pages);

          final cust =
              (data['customer'] ?? data['email'] ?? '').toString().trim();
          if (cust.isNotEmpty) uniqueCustomers.add(cust.toLowerCase());

          final service =
              (data['service'] ?? data['serviceName'] ?? 'Standard A4 Print')
                  .toString();
          serviceBreakdown[service] = (serviceBreakdown[service] ?? 0) + 1;

          final serviceLower = service.toLowerCase();
          if (data['source'] == 'POS') {
            storeRevenue += (data['productTotal'] as num? ?? 0).toDouble();
            printRevenue += (data['serviceTotal'] as num? ?? 0).toDouble();
          } else if (serviceLower.contains('store') ||
              serviceLower.contains('supply') ||
              serviceLower.contains('in-store') ||
              serviceLower.contains('notebook') ||
              serviceLower.contains('pen')) {
            storeRevenue += totalVal;
          } else {
            printRevenue += totalVal;
          }

          final rawStatus =
              (data['status'] ?? 'Order Submitted').toString().toLowerCase();
          if (rawStatus == 'cancelled') {
            statusCounts['Cancelled'] = (statusCounts['Cancelled'] ?? 0) + 1;
          } else if (rawStatus.contains('reject')) {
            statusCounts['Rejected'] = (statusCounts['Rejected'] ?? 0) + 1;
          } else if (rawStatus.contains('complet') ||
              rawStatus.contains('done')) {
            statusCounts['Completed'] = (statusCounts['Completed'] ?? 0) + 1;
          } else if (rawStatus.contains('ready') ||
              rawStatus.contains('pickup')) {
            statusCounts['Ready for Pickup'] =
                (statusCounts['Ready for Pickup'] ?? 0) + 1;
          } else if (rawStatus.contains('approve')) {
            statusCounts['Approved'] = (statusCounts['Approved'] ?? 0) + 1;
          } else if ((rawStatus.contains('print') ||
              rawStatus.contains('prepar'))) {
            statusCounts['Printing'] = (statusCounts['Printing'] ?? 0) + 1;
          } else {
            statusCounts['Order Submitted'] =
                (statusCounts['Order Submitted'] ?? 0) + 1;
          }
        }

        double avgOrderValue =
            totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;
        int activeCustomersCount = uniqueCustomers.length;

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
                  iconColor: const Color(0xFF10B981),
                  valueColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFF10B981).withOpacity(0.15),
                ),
                _buildWebAnalyticsMetricCard(
                  title: 'TOTAL ORDERS',
                  value: '$totalOrders',
                  subtitle: 'Submitted print jobs',
                  icon: Icons.inventory_2_rounded,
                  iconColor: const Color(0xFF15803D),
                  valueColor: const Color(0xFF15803D),
                  bgColor: const Color(0xFF15803D).withOpacity(0.15),
                ),
                _buildWebAnalyticsMetricCard(
                  title: 'PAGES PRINTED',
                  value: _formatNumberWithCommas(pagesPrinted),
                  subtitle: 'Total paper consumption',
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFF15803D),
                  valueColor: const Color(0xFF15803D),
                  bgColor: const Color(0xFF15803D).withOpacity(0.15),
                ),
                _buildWebAnalyticsMetricCard(
                  title: 'TOTAL CUSTOMERS',
                  value: '$activeCustomersCount',
                  subtitle: 'Registered accounts',
                  icon: Icons.people_alt_rounded,
                  iconColor: const Color(0xFFA78BFA),
                  valueColor: const Color(0xFFA78BFA),
                  bgColor: const Color(0xFFA78BFA).withOpacity(0.15),
                ),
                _buildWebAnalyticsMetricCard(
                  title: 'AVG ORDER VALUE',
                  value: '₱${avgOrderValue.toStringAsFixed(2)}',
                  subtitle: 'Average spent per ticket',
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFFFBBF24),
                  valueColor: const Color(0xFFFBBF24),
                  bgColor: const Color(0xFFFBBF24).withOpacity(0.15),
                ),
                _buildWebAnalyticsMetricCard(
                  title: 'STORE REVENUE',
                  value: '₱${storeRevenue.toStringAsFixed(2)}',
                  subtitle: 'School supplies sales',
                  icon: Icons.shopping_cart_rounded,
                  iconColor: const Color(0xFFFB923C),
                  valueColor: const Color(0xFFFB923C),
                  bgColor: const Color(0xFFFB923C).withOpacity(0.15),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildChartCard(
              title: 'ORDER STATUS DISTRIBUTION',
              subtitle: 'Live active job status breakdown',
              badgeLabel: 'Real-Time',
              badgeColor: const Color(0xFF16A34A).withOpacity(0.2),
              badgeTextColor: const Color(0xFF15803D),
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
                      _buildChartLegendItem(
                          'Completed', const Color(0xFFF59E0B)),
                      _buildChartLegendItem(
                          'Order Submitted', const Color(0xFF8B5CF6)),
                      _buildChartLegendItem(
                          'Printing', const Color(0xFF22C55E)),
                      _buildChartLegendItem(
                          'Rejected', const Color(0xFFF43F5E)),
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
              badgeColor: const Color(0xFF16A34A).withOpacity(0.2),
              badgeTextColor: const Color(0xFF15803D),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter:
                          _BarChartPainter(serviceBreakdown: serviceBreakdown),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Flyers & Leaflets • Spiral Notebooks • In-Store Supplies • Invitations',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF4B7A5E),
                        fontWeight: FontWeight.bold),
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
              badgeColor: const Color(0xFF10B981).withOpacity(0.2),
              badgeTextColor: const Color(0xFF10B981),
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
                      _buildChartLegendItem(
                          'Print Services', const Color(0xFF15803D)),
                      const SizedBox(width: 20),
                      _buildChartLegendItem(
                          'Store Supplies', const Color(0xFFFB923C)),
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
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
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
                  style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4B7A5E),
                      letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 14),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: valueColor,
                fontFamily: 'monospace'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Color(0xFF4B7A5E)),
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
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0)),
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
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: Color(0xFF14532D),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF4B7A5E))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: badgeColor, borderRadius: BorderRadius.circular(12)),
                child: Text(badgeLabel,
                    style: TextStyle(
                        color: badgeTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 9)),
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
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4B7A5E))),
      ],
    );
  }

  String _formatNumberWithCommas(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  // ===========================================================================
  // 3. RFID LOYALTY & CARD TAP MONITOR
  // ===========================================================================
  Widget _buildAdminRfidView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _rfidLogsRef.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
              child: Text('RFID Error: ${snapshot.error}',
                  style: const TextStyle(color: DashboardTheme.ink)));
        if (!snapshot.hasData)
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)));

        final rfidDocs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.nfc_rounded,
                        color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('RFID Reader Active (Store Counter)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: DashboardTheme.ink)),
                        SizedBox(height: 2),
                        Text(
                            'Live card taps, customer points & discount tapping',
                            style: TextStyle(
                                color: Color(0xFF4B7A5E), fontSize: 10.5)),
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
                  'customerName': widget.userEmail.split('@').first,
                  'pointsAdded': 0,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Simulated RFID identification logged.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              icon: const Icon(Icons.tap_and_play,
                  color: Color(0xFF14532D), size: 18),
              label: const Text('Simulate Test Card Identification',
                  style: TextStyle(
                      color: Color(0xFF14532D),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: DashboardTheme.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('LIVE CARD TAP LOGS',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: DashboardTheme.ink)),
            const SizedBox(height: 10),
            if (rfidDocs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Text('No RFID taps logged yet.',
                    style: TextStyle(color: Color(0xFF4B7A5E), fontSize: 12)),
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
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: const Color(0xFF15803D).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.credit_card_rounded,
                            color: Color(0xFF15803D), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$name ($uid)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: DashboardTheme.ink)),
                            Text(dt,
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF4B7A5E))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('+$pts PTS',
                            style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 10)),
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

  // ===========================================================================
  // --- INTERIOR HOMEPAGE TAB (MATCHING HOMESCREEN FUTURISTIC DESIGN) ---
  // ===========================================================================
  Widget _buildCustomerHomeTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Admin quick card banner if admin
          if (_isAdmin)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0FDF4), Color(0xFF14532D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF166534)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        color: Color(0xFF15803D), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Admin Product Management',
                            style: TextStyle(
                                color: Color(0xFF14532D),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text(
                            'Edit prices, update stocks & import product photos',
                            style: TextStyle(
                                color: Color(0xFF4B7A5E), fontSize: 10.5)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _currentNavIndex = 1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DashboardTheme.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Manage',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Hero Headline
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Text(
                  'Elevate Your\nPrinting Experience',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF14532D),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: const Text(
                    'Unlock your printing potential in a fully connected environment, powered by Kez C-Em Zek Printing Shop',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF4B7A5E),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Central Sphere Graphic with Floating Glass Cards
          SizedBox(
            height: 310,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Centered App Logo
                Center(
                  child: Container(
                    width: 175,
                    height: 175,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withOpacity(0.20),
                          blurRadius: 30,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/images/kcz_logo.jpg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // Center Action Button
                Positioned(
                  top: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.12),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_isAdmin) {
                          setState(() => _currentNavIndex = 2);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PlaceOrderScreen(
                                    userEmail: widget.userEmail)),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: DashboardTheme.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: Text(
                        _isAdmin ? 'Manage Orders' : 'Place New Print Order',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                ),

                // Left Floating Card
                Positioned(
                  left: 16,
                  bottom: 60,
                  child: _buildHomeGlassCard(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Print Services',
                                style: TextStyle(
                                    color: Color(0xFF4B7A5E),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.north_east_rounded,
                                  color: Color(0xFF14532D), size: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text('Unparalleled\nQuality Proofing',
                            style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                height: 1.2)),
                        const SizedBox(height: 6),
                        const Text('100% Guaranteed',
                            style: TextStyle(
                                color: Color(0xFF15803D),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

                // Right Floating Card
                Positioned(
                  right: 16,
                  bottom: 35,
                  child: _buildHomeGlassCard(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Order Tracking',
                                style: TextStyle(
                                    color: Color(0xFF4B7A5E),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.north_east_rounded,
                                  color: Color(0xFF14532D), size: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('99.4%',
                            style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 17,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2)),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.94,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF15803D),
                                  Color(0xFF22C55E)
                                ]),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_isAdmin) {
                        setState(() => _currentNavIndex = 2);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PlaceOrderScreen(
                                  userEmail: widget.userEmail)),
                        );
                      }
                    },
                    icon: Icon(
                        _isAdmin
                            ? Icons.assignment_turned_in_rounded
                            : Icons.add_circle_rounded,
                        size: 18),
                    label: Text(_isAdmin ? 'View Orders' : 'Order Prints',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DashboardTheme.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StoreSuppliesButton(
                      onPressed: () => setState(() => _currentNavIndex = 1)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Services Grid Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OUR SERVICES',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF15803D),
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                const Text('Everything your business needs printed',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
                const Text(
                    'Tap a service to customize and calculate instant prices.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF4B7A5E))),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: [
                    _buildDarkServiceCard(
                        'Document Print',
                        'Short, Long, A4 B&W or Color.',
                        'Starts at ₱3.00 / pg',
                        Icons.description_rounded,
                        const Color(0xFF15803D)),
                    _buildDarkServiceCard(
                        'PVC ID Cards',
                        'Durable waterproof PVC cards.',
                        'Starts at ₱50.00 / pc',
                        Icons.badge_rounded,
                        const Color(0xFFFBBF24)),
                    _buildDarkServiceCard(
                        'Stickers & Labels',
                        'Glossy, Matte, or Vinyl die-cut.',
                        'Starts at ₱45.00 / sheet',
                        Icons.auto_awesome_rounded,
                        const Color(0xFFA78BFA)),
                    _buildDarkServiceCard(
                        'Store Supplies',
                        'Notebooks, pens, and paper packs.',
                        'Available in Store Tab',
                        Icons.storefront_rounded,
                        const Color(0xFF10B981)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHomeGlassCard({required double width, required Widget child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDarkServiceCard(String title, String desc, String price,
      IconData icon, Color accentColor) {
    return InkWell(
      onTap: () {
        if (_isAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'You are signed in as an admin. Only customers can place orders.'),
              backgroundColor: Color(0xFF15803D),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    PlaceOrderScreen(userEmail: widget.userEmail)),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: accentColor),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Expanded(
                child: Text(desc,
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF4B7A5E)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 4),
            Text(price,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Color(0xFF10B981))),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // --- MANAGE ORDERS VIEW (ADMIN) ---
  // ===========================================================================
  Widget _buildManageOrdersView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: DashboardTheme.ink)));
        if (!snapshot.hasData)
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)));

        final docs = snapshot.data!.docs;
        int approvalCount = 0;
        int printingCount = 0;
        int readyCount = 0;

        for (var d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final category =
              _getStatusCategory((data['status'] ?? '').toString());
          if (category == 'approval') approvalCount++;
          if (category == 'printing') printingCount++;
          if (category == 'ready') readyCount++;
        }

        final queryClean = _cleanStr(_searchController.text);

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rawStatus = (data['status'] ?? 'Order Submitted').toString();
          final category = _getStatusCategory(rawStatus);
          final serviceName =
              (data['service'] ?? data['serviceName'] ?? '').toString();

          bool matchesCategory = _checkServiceCategoryMatch(
              serviceName, _selectedServiceCategory, data);
          bool matchesSearch = queryClean.isEmpty;
          if (!matchesSearch) {
            String fullDocString =
                '${_cleanStr(doc.id)} ${_cleanStr(data.toString())}';
            if (fullDocString.contains(queryClean)) matchesSearch = true;
          }

          bool matchesStatus = true;
          if (queryClean.isEmpty) {
            if (_statusFilter == 'All Active') {
              matchesStatus = (category != 'completed' &&
                  category != 'rejected' &&
                  category != 'cancelled');
            } else if (_statusFilter == 'For Approval') {
              matchesStatus = (category == 'approval');
            } else if (_statusFilter == 'Approved') {
              matchesStatus = (category == 'approved');
            } else if (_statusFilter == 'Printing') {
              matchesStatus = (category == 'printing');
            } else if (_statusFilter == 'Ready for Pickup') {
              matchesStatus = (category == 'ready');
            } else if (_statusFilter == 'Completed') {
              matchesStatus = (category == 'completed');
            } else if (_statusFilter == 'Cancelled') {
              matchesStatus = (category == 'cancelled');
            } else if (_statusFilter == 'Rejected') {
              matchesStatus = (category == 'rejected');
            }
          }

          return matchesCategory && matchesSearch && matchesStatus;
        }).toList();

        // Sort orders based on _orderSortOrder
        filteredDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final timeA = _getOrderTimestamp(dataA);
          final timeB = _getOrderTimestamp(dataB);
          if (_orderSortOrder == 'Latest to Previous') {
            return timeB.compareTo(timeA);
          } else {
            return timeA.compareTo(timeB);
          }
        });

        int totalPages = (filteredDocs.length / _ordersPerPage).ceil();
        if (totalPages < 1) totalPages = 1;
        if (_ordersCurrentPage > totalPages) _ordersCurrentPage = totalPages;
        if (_ordersCurrentPage < 1) _ordersCurrentPage = 1;

        int startIndex = (_ordersCurrentPage - 1) * _ordersPerPage;
        int endIndex =
            math.min(startIndex + _ordersPerPage, filteredDocs.length);
        final pagedDocs = filteredDocs.sublist(startIndex, endIndex);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.print_rounded,
                            color: Color(0xFF15803D)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Print Production Queue',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: DashboardTheme.ink)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text('${docs.length} Active',
                                      style: const TextStyle(
                                          color: Color(0xFF15803D),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text('Organized print job management • FIFO',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF4B7A5E))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatusCounterBox(
                          'APPROVAL',
                          approvalCount.toString(),
                          const Color(0xFFFBBF24).withOpacity(0.15),
                          const Color(0xFFFBBF24)),
                      const SizedBox(width: 8),
                      _buildStatusCounterBox(
                          'PRINTING',
                          printingCount.toString(),
                          const Color(0xFF15803D).withOpacity(0.15),
                          const Color(0xFF15803D)),
                      const SizedBox(width: 8),
                      _buildStatusCounterBox(
                          'READY',
                          readyCount.toString(),
                          const Color(0xFF10B981).withOpacity(0.15),
                          const Color(0xFF10B981)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() => _ordersCurrentPage = 1),
              style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search PRNT-7767, Client, or Item...',
                hintStyle:
                    const TextStyle(fontSize: 12, color: Color(0xFF4B7A5E)),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: Color(0xFF4B7A5E)),
                filled: true,
                fillColor: const Color(0xFFFFFFFF),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sort Dropdown (Latest to Previous / Previous to Latest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: const Color(0xFFFFFFFF),
                              value: _orderSortOrder,
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: DashboardTheme.ink),
                              style: const TextStyle(
                                  color: Color(0xFF14532D),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _orderSortOrder = val;
                                    _ordersCurrentPage = 1;
                                  });
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'Latest to Previous',
                                  child: Text('Latest to Previous'),
                                ),
                                DropdownMenuItem(
                                  value: 'Previous to Latest',
                                  child: Text('Previous to Latest'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Service Category Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: const Color(0xFFFFFFFF),
                              value: _serviceCategories
                                      .contains(_selectedServiceCategory)
                                  ? _selectedServiceCategory
                                  : 'All Services',
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: DashboardTheme.ink),
                              style: const TextStyle(
                                  color: Color(0xFF14532D),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedServiceCategory = val;
                                    _ordersCurrentPage = 1;
                                  });
                                }
                              },
                              items: _serviceCategories
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s)))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All Active',
                  'For Approval',
                  'Approved',
                  'Printing',
                  'Ready for Pickup',
                  'Completed',
                  'Rejected',
                  'Cancelled'
                ].map((status) {
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
                      selectedColor: DashboardTheme.green,
                      labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF4B7A5E),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                      backgroundColor: const Color(0xFFFFFFFF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : const Color(0xFFBBF7D0))),
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
                decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0))),
                child: Text(
                    'No matching orders found under "$_selectedServiceCategory".',
                    style: const TextStyle(
                        color: Color(0xFF4B7A5E),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              )
            else
              ...pagedDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final String displayRefId = (data['id'] ??
                        data['refId'] ??
                        data['ref_id'] ??
                        data['orderNumber'] ??
                        (docId.length > 10
                            ? 'PRNT-${docId.substring(0, 6).toUpperCase()}'
                            : docId))
                    .toString();
                final serviceName = (data['service'] ??
                        data['serviceName'] ??
                        data['item_name'] ??
                        'Standard A4 Print')
                    .toString();
                final customer = (data['customer'] ??
                        data['userEmail'] ??
                        data['fullName'] ??
                        'Customer')
                    .toString();
                final rawTotal =
                    data['total'] ?? data['price'] ?? data['amount'];
                final String totalStr = rawTotal != null
                    ? (rawTotal is num
                        ? '₱${rawTotal.toStringAsFixed(2)}'
                        : rawTotal.toString())
                    : '₱30.00';
                final status = (data['status'] ?? 'Order Submitted').toString();
                final payment =
                    (data['payment'] ?? data['payment_method'] ?? 'GCash')
                        .toString();
                final dateTimeStr = _formatDateTime(data['createdAt'] ??
                    data['created_at'] ??
                    data['timestamp'] ??
                    data['date'] ??
                    data['time']);

                return _isListView
                    ? _buildOrderListItem(docId, displayRefId, serviceName,
                        customer, totalStr, status, payment, dateTimeStr, data)
                    : _buildOrderCardItem(docId, displayRefId, serviceName,
                        customer, totalStr, status, payment, dateTimeStr, data);
              }),
            if (filteredDocs.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: DashboardTheme.ink),
                      onPressed: _ordersCurrentPage > 1
                          ? () => setState(() => _ordersCurrentPage--)
                          : null,
                    ),
                    Text(
                      "Page $_ordersCurrentPage of $totalPages (${filteredDocs.length} orders)",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: DashboardTheme.ink),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded,
                          color: DashboardTheme.ink),
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

  Widget _buildViewToggleBtn(
      String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF4B7A5E)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color:
                        isSelected ? Colors.white : const Color(0xFF4B7A5E))),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCardItem(
      String docId,
      String refId,
      String service,
      String customer,
      String total,
      String status,
      String payment,
      String dateTimeStr,
      Map<String, dynamic> data) {
    final statusCategory = _getStatusCategory(status);
    Color statusBgColor = const Color(0xFFFBBF24).withOpacity(0.2);
    Color statusTextColor = const Color(0xFFFBBF24);
    if (statusCategory == 'printing') {
      statusBgColor = const Color(0xFF15803D).withOpacity(0.2);
      statusTextColor = const Color(0xFF15803D);
    } else if (statusCategory == 'ready') {
      statusBgColor = const Color(0xFF10B981).withOpacity(0.2);
      statusTextColor = const Color(0xFF10B981);
    } else if (statusCategory == 'completed') {
      statusBgColor = const Color(0xFF10B981).withOpacity(0.2);
      statusTextColor = const Color(0xFF10B981);
    } else if (statusCategory == 'cancelled') {
      statusBgColor = const Color(0xFFE2E8F0);
      statusTextColor = const Color(0xFF334155);
    } else if (statusCategory == 'rejected') {
      statusBgColor = const Color(0xFFF43F5E).withOpacity(0.2);
      statusTextColor = const Color(0xFFF43F5E);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBBF7D0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(refId,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F172A))),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusTextColor))),
            ],
          ),
          const SizedBox(height: 8),
          Text(customer,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF334155))),
          Text(service,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          if ((data['customerNote'] ?? data['specialInstructions'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFBBF7D0),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note_alt_outlined,
                      size: 12, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Note: ${(data['customerNote'] ?? data['specialInstructions']).toString().trim()}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF92400E),
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(total,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF10B981))),
              _buildAdminOrderActions(docId, refId, status, data),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListItem(
      String docId,
      String refId,
      String service,
      String customer,
      String total,
      String status,
      String payment,
      String dateTimeStr,
      Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(refId,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F172A))),
              Text(total,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 4),
          Text(customer,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF334155))),
          Text(service,
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          if ((data['customerNote'] ?? data['specialInstructions'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.note_alt_outlined,
                    size: 12, color: Color(0xFFFBBF24)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "Note: ${(data['customerNote'] ?? data['specialInstructions']).toString().trim()}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF92400E),
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFBBF7D0),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(status,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14532D)))),
              _buildAdminOrderActions(docId, refId, status, data),
            ],
          ),
        ],
      ),
    );
  }

  // --- STOCK DEDUCTION / RESTORATION LOGIC FOR ORDERS ---
  Future<void> _confirmAndUpdateOrderStatus(String orderId, String newStatus,
      String actionLabel, Map<String, dynamic> orderData) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFBBF7D0))),
        title: Row(
          children: const [
            Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('Confirm Action',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DashboardTheme.ink)),
          ],
        ),
        content: Text(
            newStatus == 'Completed' ? 'Confirm that payment was received and this order was completed. Fully free rewards require no cash payment.' : 'Are you sure you want to change order status to "$newStatus"?',
            style: const TextStyle(color: Color(0xFF4B7A5E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF4B7A5E))),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: DashboardTheme.green),
            onPressed: () => Navigator.pop(c, true),
            child: Text(actionLabel,
                style: const TextStyle(
                    color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await updateOrderWorkflow(orderId, newStatus, paymentConfirmed: newStatus == 'Completed');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to "$newStatus"'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
      }
    }
  }

  Widget _buildAdminOrderActions(
      String orderId, String refId, String status, Map<String, dynamic> data) {
    final category = _getStatusCategory(status);
    final isFinished = category == 'completed' ||
        category == 'rejected' ||
        category == 'cancelled';

    String nextStatus = 'Approved';
    String actionLabel = 'Approve';
    Color btnColor = DashboardTheme.green; // Emerald green like screenshot

    if (status == 'Approved') {
      nextStatus = 'Printing';
      actionLabel = 'Start Printing';
    } else if (category == 'printing') {
      nextStatus = 'Ready for Pickup';
      actionLabel = 'Ready';
      btnColor = const Color(0xFFB45309);
    } else if (category == 'ready') {
      nextStatus = 'Completed';
      actionLabel = 'Done';
      btnColor = DashboardTheme.green;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isFinished) ...[
          // Split action button matching reference: [✓ Approve | v]
          Container(
            decoration: BoxDecoration(
              color: btnColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _confirmAndUpdateOrderStatus(
                      orderId, nextStatus, '$actionLabel Order', data),
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(10)),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded,
                            size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          actionLabel,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF14532D),
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 18,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 14, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFBBF7D0)),
                  ),
                  tooltip: 'Change Status',
                  onSelected: (selectedStatus) {
                    _confirmAndUpdateOrderStatus(
                        orderId, selectedStatus, 'Update Status', data);
                  },
                  itemBuilder: (context) => [
                    _buildStatusMenuItem('For Approval', '✓ For Approval',
                        const Color(0xFFFBBF24)),
                    _buildStatusMenuItem('Printing', '🖨️ Start Printing',
                        const Color(0xFF15803D)),
                    _buildStatusMenuItem('Ready for Pickup',
                        '📦 Ready for Pickup', const Color(0xFF15803D)),
                    _buildStatusMenuItem('Completed', '🎉 Complete Order',
                        const Color(0xFF10B981)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
        OrderOptionsButton(
          hasFile: (data['fileUrl'] ??
                      data['file_url'] ??
                      data['url'] ??
                      data['file'] ??
                      '')
                  .toString()
                  .trim()
                  .isNotEmpty &&
              !['Pending / Direct In-Store Upload', 'No file selected']
                  .contains(systemDisplayText(data['fileUrl'] ??
                          data['file_url'] ?? data['url'] ?? data['file'])),
          onSelected: (value) {
            if (value == 'review') _showReviewSpecsModal(orderId, refId, data);
            if (value == 'file') _openAttachedFile(data);
            if (value == 'slip') _showPrintJobSlipModal(refId, data);
            if (value == 'reject') _showRejectOrderModal(orderId, refId, data);
          },
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildStatusMenuItem(
      String value, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  // ── MODAL 1: REVIEW SPECS & FILE ───────────────────────────────────────────
  void _showReviewSpecsModal(
      String orderId, String refId, Map<String, dynamic> data) {
    final customer =
        (data['customer'] ?? data['userEmail'] ?? 'Guest').toString();
    final service = (data['service'] ?? 'Standard A4 Print').toString();
    final total = orderAmount(data['total'] ?? data['price'] ?? 0);
    final store = isStoreSupplyOrder(data);
    final items = data['items'] is List
        ? (data['items'] as List).whereType<Map>().toList()
        : const <Map>[];
    final payment = (data['payment'] ?? 'GCash Online').toString();
    final status = (data['status'] ?? 'Order Submitted').toString();
    final fileName =
        systemDisplayText(data['fileName'] ?? data['file'] ?? 'No file attached');
    final fileUrl = (data['fileUrl'] ?? data['file_url'] ?? '').toString();
    final note = (data['customerNote'] ?? data['specialInstructions'] ?? '')
        .toString()
        .trim();
    final details = data['details'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: Row(children: [
          const Icon(Icons.assignment_outlined,
              color: DashboardTheme.green, size: 22),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Review Specs & File',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: DashboardTheme.ink))),
          IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded,
                  color: DashboardTheme.muted, size: 20)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSpecRow('Order ID', refId, isMono: true),
              _buildSpecRow('Customer', customer),
              _buildSpecRow('Service', service),
              if (!store) ...[
                _buildSpecRow(
                    'Paper Specs', '${data['paperSize'] ?? 'Standard Specs'}'),
                _buildSpecRow('Copies / Quantity',
                    '${data['copies'] ?? data['quantity'] ?? 1}'),
                _buildSpecRow(
                    'Color Mode', '${data['colorMode'] ?? 'Not specified'}'),
              ],
              if (store && items.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Store items',
                    style: TextStyle(
                        color: DashboardTheme.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                ...items.map((item) {
                  final quantity =
                      int.tryParse('${item['qty'] ?? item['quantity'] ?? 1}') ??
                          1;
                  return _buildSpecRow('${item['name'] ?? 'Store item'}',
                      '$quantity ${quantity == 1 ? 'unit' : 'units'}');
                }),
              ],
              _buildSpecRow('Status', status),
              _buildSpecRow('Payment', payment),
              if ((data['gcashRef'] ?? '').toString().isNotEmpty)
                _buildSpecRow('GCash reference', data['gcashRef'].toString()),
              if ((data['gcashReceiptUrl'] ?? '').toString().isNotEmpty)
                sharedImage(data['gcashReceiptUrl'].toString()),
              _buildSpecRow('Subtotal', orderAmount(data['subtotal'] ?? data['total'])),
              _buildSpecRow('Points used', '${data['pointsUsed'] ?? 0}'),
              _buildSpecRow('Points discount', orderAmount(data['pointsDiscount'] ?? 0)),
              _buildSpecRow('Points earned', '${data['pointsEarned'] ?? 0}'),
              _buildSpecRow('Total', total, isHighlight: true),
              if (!store && details != null && details.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Custom Specs:',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D))),
                const SizedBox(height: 4),
                ...details.entries.map((e) =>
                    _buildSpecRow(e.key.toUpperCase(), e.value.toString())),
              ],
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFBBF7D0)),
              const SizedBox(height: 6),
              const Text('Customer Note / Instructions:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4B7A5E))),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  note.isNotEmpty ? note : 'No special instructions provided.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle:
                        note.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                    color: DashboardTheme.ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Attached File:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4B7A5E))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.file_present_rounded,
                        color: DashboardTheme.green, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: DashboardTheme.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (fileUrl.isNotEmpty && fileUrl.startsWith('http'))
                      ElevatedButton.icon(
                        onPressed: () => _openAttachedFile(data),
                        icon: const Icon(Icons.open_in_new_rounded,
                            size: 12, color: Colors.white),
                        label: const Text('Open',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DashboardTheme.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBBF7D0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close',
                  style: TextStyle(
                      color: Color(0xFF14532D),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value,
      {bool isMono = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: DashboardTheme.muted))),
        const SizedBox(width: 12),
        Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                softWrap: true,
                style: TextStyle(
                    fontSize: isHighlight ? 16 : 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: isMono ? 'monospace' : null,
                    color: isHighlight
                        ? DashboardTheme.green
                        : DashboardTheme.ink))),
      ]),
    );
  }

  // ── MODAL 2: OPEN ATTACHED FILE ───────────────────────────────────────────
  Future<void> _openAttachedFile(Map<String, dynamic> data) async {
    final fileUrl = (data['fileUrl'] ??
            data['file_url'] ??
            data['url'] ??
            data['file'] ??
            '')
        .toString()
        .trim();
    if (fileUrl.isEmpty || !fileUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid web link or file URL is attached.'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(fileUrl);
    if (uri != null) {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the file link.'),
            backgroundColor: Color(0xFFF43F5E),
          ),
        );
      }
    }
  }

  // ── MODAL 3: PRINT JOB SLIP TICKET ─────────────────────────────────────────
  void _showPrintJobSlipModal(String refId, Map<String, dynamic> data) {
    final customer =
        (data['customer'] ?? data['userEmail'] ?? 'Guest').toString();
    final service = (data['service'] ?? 'Standard A4 Print').toString();
    final total = (data['total'] ?? data['price'] ?? 0).toString();
    final payment = (data['payment'] ?? 'GCash Online').toString();
    final status = (data['status'] ?? 'Order Submitted').toString();
    final qty = (data['quantity'] ?? data['copies'] ?? 1).toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.receipt_long_rounded,
                    color: Color(0xFFA855F7), size: 20),
                SizedBox(width: 8),
                Text('Job Slip Ticket',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: DashboardTheme.ink)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Color(0xFF4B7A5E), size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FFF9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'KEZ C-EM ZEK PRINT SHOP',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF14532D),
                      letterSpacing: 1.1),
                ),
              ),
              const Center(
                child: Text('Official Production Job Ticket',
                    style: TextStyle(fontSize: 10, color: Color(0xFF4B7A5E))),
              ),
              const Divider(color: Color(0xFFBBF7D0), height: 16),
              _buildSlipLine('JOB TICKET #:', refId),
              _buildSlipLine('CLIENT:', customer),
              _buildSlipLine('SERVICE:', service),
              _buildSlipLine('QUANTITY:', '$qty pcs'),
              _buildSlipLine('Subtotal', orderAmount(data['subtotal'] ?? data['total'])),
              _buildSlipLine('Points used', '${data['pointsUsed'] ?? 0}'),
              _buildSlipLine('Points discount', orderAmount(data['pointsDiscount'] ?? 0)),
              _buildSlipLine('Points earned', '${data['pointsEarned'] ?? 0}'),
              _buildSlipLine('TOTAL:', '₱$total'),
              _buildSlipLine('PAYMENT:', payment),
              _buildSlipLine('STATUS:', status),
              const Divider(color: Color(0xFFBBF7D0), height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  DateTime.now().toString().substring(0, 19),
                  style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF4B7A5E),
                      fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.print_rounded,
                      size: 14, color: Colors.white),
                  label: const Text('Print Ticket',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  onPressed: () async {
                    try {
                      await const MethodChannel('printingshop/job_ticket')
                          .invokeMethod('print', {
                        'title': 'Job Ticket $refId',
                        'lines': data.entries
                            .where((e) =>
                                !['fileUrl', 'gcashReceiptUrl'].contains(e.key))
                            .map((e) => '${e.key}: ${e.value}')
                            .toList(),
                      });
                    } on MissingPluginException {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Printing is available on Android.')));
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Could not open printing: $e')));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBBF7D0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close',
                    style: TextStyle(
                        color: Color(0xFF14532D),
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlipLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF4B7A5E),
                  fontFamily: 'monospace')),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF14532D),
                  fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  // ── MODAL 4: REJECT ORDER REASON ───────────────────────────────────────────
  void _showRejectOrderModal(
      String orderId, String refId, Map<String, dynamic> orderData) {
    final reasonController = TextEditingController();

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
            Icon(Icons.cancel_outlined, color: Color(0xFFF43F5E), size: 20),
            SizedBox(width: 8),
            Text('Reject Order Reason',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: DashboardTheme.ink)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order: $refId',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: DashboardTheme.muted)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFF14532D), fontSize: 12),
              decoration: InputDecoration(
                hintText:
                    'Reason (e.g., Low file resolution, unreadable text)...',
                hintStyle:
                    const TextStyle(fontSize: 11, color: Color(0xFF4B7A5E)),
                filled: true,
                fillColor: const Color(0xFFF8FFF9),
                contentPadding: const EdgeInsets.all(12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFBBF7D0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFF43F5E)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF43F5E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final reason = reasonController.text.trim();
                    if (reason.length < 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Please enter a rejection reason (at least 4 characters).'),
                            backgroundColor: Color(0xFFF43F5E)),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      await updateOrderWorkflow(orderId, 'Rejected',
                          reason: reason);
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())));
                      return;
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Order $refId marked as Rejected.'),
                          backgroundColor: const Color(0xFFF43F5E)),
                    );
                  },
                  child: const Text('Confirm Reject',
                      style: TextStyle(
                          color: Color(0xFF14532D),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBBF7D0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: Color(0xFF14532D),
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCounterBox(
      String label, String count, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: textColor)),
            const SizedBox(height: 2),
            Text(count,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersAndProfileView() => AdminProfilePanel(
      email: widget.userEmail,
      onTerms: () => _showTermsAndConditionsDialog(context));

  // ===========================================================================
  // --- CUSTOMER ORDERS & LIVE STATUS TRACKER TAB (SCREENSHOT DESIGN) ---
  // ===========================================================================
  Widget _buildCustomerOrdersTab() {
    final cleanEmail = widget.userEmail.trim().toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      key: _customerTrackerRefreshKey,
      stream: _ordersRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 48, color: Color(0xFFF43F5E)),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to connect to database',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: DashboardTheme.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF4B7A5E)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: DashboardTheme.green),
                    onPressed: () => setState(
                        () => _customerTrackerRefreshKey = UniqueKey()),
                    icon: const Icon(Icons.refresh_rounded,
                        size: 16, color: Colors.white),
                    label: const Text('Retry Connection',
                        style: TextStyle(
                            color: Color(0xFF14532D),
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)));
        }

        final allDocs = snapshot.data!.docs;

        // Filter strictly to currently authenticated user's orders (email or customer ID)
        final myDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['source'] == 'POS') return false;
          final orderEmail = (data['email'] ?? data['userEmail'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final orderCustomer =
              (data['customer'] ?? '').toString().trim().toLowerCase();
          final username = cleanEmail.contains('@')
              ? cleanEmail.split('@').first
              : cleanEmail;

          return orderEmail == cleanEmail ||
              (orderCustomer.isNotEmpty &&
                  (orderCustomer == cleanEmail || orderCustomer == username));
        }).toList();

        // Sort newest first by creation timestamp/date
        myDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final timeA = _getOrderTimestamp(dataA);
          final timeB = _getOrderTimestamp(dataB);
          return timeB.compareTo(timeA);
        });

        // Apply Service / Category Dropdown Filter
        final categoryFiltered = myDocs.where((doc) {
          if (_customerCategoryFilter == 'All Services & Store Items')
            return true;
          final data = doc.data() as Map<String, dynamic>;
          final service = (data['service'] ??
                  data['serviceName'] ??
                  data['item_name'] ??
                  '')
              .toString();
          return _checkServiceCategoryMatch(
              service, _customerCategoryFilter, data);
        }).toList();

        // Apply Status Filter Chips
        final filteredDocs = categoryFiltered.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rawStatus = (data['status'] ?? 'Order Submitted').toString();
          return _matchesCustomerStatusFilter(rawStatus, _customerFilter);
        }).toList();

        final custTotalPages = (filteredDocs.length / _customerOrdersPerPage)
            .ceil()
            .clamp(1, 9999);
        if (_customerOrdersCurrentPage > custTotalPages)
          _customerOrdersCurrentPage = custTotalPages;
        if (_customerOrdersCurrentPage < 1) _customerOrdersCurrentPage = 1;
        final custStartIndex =
            (_customerOrdersCurrentPage - 1) * _customerOrdersPerPage;
        final custEndIndex = math.min(
            custStartIndex + _customerOrdersPerPage, filteredDocs.length);
        final pagedDocs = filteredDocs.sublist(custStartIndex, custEndIndex);

        final customerDisplayName = widget.userEmail.contains('@')
            ? widget.userEmail.split('@').first
            : widget.userEmail;

        return RefreshIndicator(
          color: const Color(0xFF16A34A),
          backgroundColor: const Color(0xFFF0FDF4),
          onRefresh: () async {
            setState(() => _customerTrackerRefreshKey = UniqueKey());
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            children: [
              // ── Header Profile & Stats Banner (Matching Reference) ────
              _buildCustomerTopBanner(
                customerName: customerDisplayName,
                totalOrders: myDocs.length,
                rfidPoints: 0,
              ),
              const SizedBox(height: 14),

              // ── Navigation Bar / Pill Row ─────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    Text(
                      'SERVICES & ORDERS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: DashboardTheme.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTrackerTopNavButton(
                      label: 'Place Print Order',
                      icon: Icons.print_outlined,
                      isActive: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PlaceOrderScreen(userEmail: widget.userEmail),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildTrackerTopNavButton(
                      label: 'My Orders & Tracker',
                      icon: Icons.receipt_long_rounded,
                      isActive: true,
                      onTap: () {},
                    ),
                    const SizedBox(width: 6),
                    _buildTrackerTopNavButton(
                      label: 'Visit Store',
                      icon: Icons.storefront_rounded,
                      isActive: false,
                      onTap: () => setState(() => _currentNavIndex = 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Section Title Card & Controls ─────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 5, right: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF15803D),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "MY ACTIVE ORDERS & LIVE STATUS TRACKER",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                  color: Color(0xFF14532D),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "Track your printing orders and view real-time production updates step-by-step.",
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF4B7A5E)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter dropdown + Refresh button row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FFF9),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _customerCategoryFilter,
                                dropdownColor: const Color(0xFFF0FDF4),
                                isExpanded: true,
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: Color(0xFF4B7A5E)),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: DashboardTheme.ink),
                                items: [
                                  'All Services & Store Items',
                                  'Standard A4 Print',
                                  'Business Cards',
                                  'Tarpaulins',
                                  'Flyers & Leaflets',
                                  'Stickers & Labels',
                                  'Invitations',
                                  'Shirt Printing',
                                  'Photo & Canvas',
                                  'Booklets & Menus',
                                  'In-Store Supplies',
                                ]
                                    .map((cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Text(cat,
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    setState(
                                        () => _customerCategoryFilter = val);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DashboardTheme.green,
                              side: const BorderSide(color: Color(0xFFBBF7D0)),
                              backgroundColor: const Color(0xFFF8FFF9),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () {
                              setState(() =>
                                  _customerTrackerRefreshKey = UniqueKey());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("Orders updated from live server."),
                                  backgroundColor: Color(0xFF10B981),
                                  duration: Duration(milliseconds: 900),
                                ),
                              );
                            },
                            icon: const Icon(Icons.refresh_rounded,
                                size: 14, color: Color(0xFF15803D)),
                            label: const Text("Refresh",
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Status Filter Chips (Matching Reference) ──────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    'All Orders',
                    'For Approval',
                    'Approved & Printing',
                    'Ready for Pickup',
                    'Completed',
                    'Rejected',
                    'Cancelled',
                  ].map((filter) {
                    final isSelected = _customerFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (val) =>
                            setState(() => _customerFilter = filter),
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF4B7A5E),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        backgroundColor: const Color(0xFFFFFFFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFBBF7D0),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // ── Orders List / Empty State ─────────────────────────────
              if (filteredDocs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 48, color: Color(0xFF334155)),
                      const SizedBox(height: 10),
                      Text(
                        myDocs.isEmpty
                            ? "You don't have any orders placed yet."
                            : "No orders found under '$_customerFilter'.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Tap 'Place Print Order' or visit the Store to begin.",
                        style:
                            TextStyle(color: Color(0xFF4B7A5E), fontSize: 11),
                      ),
                    ],
                  ),
                )
              else ...[
                ...pagedDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildTrackedCustomerOrderCard(doc.id, data);
                }),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded,
                            color: Color(0xFF14532D), size: 20),
                        onPressed: _customerOrdersCurrentPage > 1
                            ? () => setState(() => _customerOrdersCurrentPage--)
                            : null,
                      ),
                      Text(
                        "Page $_customerOrdersCurrentPage of $custTotalPages (${filteredDocs.length} orders)",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: DashboardTheme.ink),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF14532D), size: 20),
                        onPressed: _customerOrdersCurrentPage < custTotalPages
                            ? () => setState(() => _customerOrdersCurrentPage++)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }

  // --- TOP CUSTOMER PROFILE & REWARDS BANNER ---
  Widget _buildCustomerTopBanner({
    required String customerName,
    required int totalOrders,
    required int rfidPoints,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          // Avatar Icon with gradient
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF15803D), Color(0xFFC084FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.print_rounded,
                color: Color(0xFF14532D), size: 22),
          ),
          const SizedBox(width: 10),

          // User Name & Customer Portal Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Customer Portal",
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF4B7A5E),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // RFID Points Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FFF9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              children: [
                const Text("RFID POINTS",
                    style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981))),
                InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsScreen())),
                  child: const Padding(padding: EdgeInsets.all(6), child: LoyaltyBalance())),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // My Orders Count Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FFF9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              children: [
                const Text("MY ORDERS",
                    style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B7A5E))),
                Text(
                  "$totalOrders",
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: DashboardTheme.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerTopNavButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF2563EB) : const Color(0xFFBBF7D0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: isActive ? Colors.white : const Color(0xFF4B7A5E)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : const Color(0xFF4B7A5E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SINGLE TRACKED CUSTOMER ORDER CARD ---
  Widget _buildTrackedCustomerOrderCard(
      String docId, Map<String, dynamic> data) {
    final String displayRefId = (data['id'] ??
            data['refId'] ??
            data['ref_id'] ??
            data['orderNumber'] ??
            (docId.length > 8
                ? 'PRNT-${docId.substring(0, 6).toUpperCase()}'
                : docId))
        .toString();

    final stage =
        _getTrackerStageIndex((data['status'] ?? 'Order Submitted').toString());
    return CustomerOrderCard(
      reference: displayRefId,
      order: data,
      dateLabel: _formatDateTime(data['createdAt'] ??
          data['created_at'] ??
          data['timestamp'] ??
          data['orderDate']),
      specsLabel:
          _formatOrderSpecs(data, data['quantity'] ?? data['copies'] ?? 1),
      timeline:
          OrderTimeline(currentStage: stage, store: isStoreSupplyOrder(data)),
      onAction: (action) {
        if (action == 'review')
          _showReviewSpecsModal(docId, displayRefId, data);
        if (action == 'file') _openAttachedFile(data);
        if (action == 'slip') _showPrintJobSlipModal(displayRefId, data);
        if (action == 'cancel')
          _confirmCancelCustomerOrder(docId, displayRefId);
      },
    );
  }

  // Helper to format detailed specs line
  String _formatOrderSpecs(Map<String, dynamic> data, dynamic quantity) {
    final List<String> parts = [];
    final details = data['details'];

    if (details is Map) {
      if (details['dimensions'] != null)
        parts.add(details['dimensions'].toString());
      if (details['size'] != null) parts.add(details['size'].toString());
      if (details['paper'] != null) parts.add(details['paper'].toString());
      if (details['sides'] != null) parts.add(details['sides'].toString());
      if (details['method'] != null) parts.add(details['method'].toString());
    }

    if (data['paperSize'] != null && data['paperSize'].toString().isNotEmpty) {
      parts.add(data['paperSize'].toString());
    }

    parts.add("$quantity ${quantity == 1 ? 'copy' : 'copies'}");
    return parts.join(' • ');
  }

  // --- STAGE MAPPING HELPER ---
  int _getTrackerStageIndex(String rawStatus) {
    final s = rawStatus.toLowerCase().trim();
    if (s.contains('reject') || s.contains('cancel')) return -1;
    if (s.contains('complet') || s.contains('done') || s.contains('finish'))
      return 4;
    if (s.contains('ready') || s.contains('pickup')) return 3;
    if (s.contains('print') || s.contains('production') || s.contains('prepar'))
      return 2;
    if (s.contains('approve') &&
        !s.contains('for approve') &&
        !s.contains('for approval')) return 1;
    return 0; // Default: 0 (Submitted / For Approval)
  }

  // --- FILTER MATCHING HELPER ---
  bool _matchesCustomerStatusFilter(String rawStatus, String filter) {
    if (filter == 'All Orders') return true;
    final s = rawStatus.toLowerCase().trim();

    if (filter == 'For Approval') {
      return (s.contains('submitted') ||
              s.contains('for approval') ||
              s.contains('pending')) &&
          !s.contains('print') &&
          !s.contains('ready') &&
          !s.contains('complet') &&
          !s.contains('reject');
    }
    if (filter == 'Approved & Printing') {
      return (s.contains('print') || s.contains('approve')) &&
          !s.contains('ready') &&
          !s.contains('complet') &&
          !s.contains('reject');
    }
    if (filter == 'Ready for Pickup') {
      return (s.contains('ready') || s.contains('pickup')) &&
          !s.contains('complet') &&
          !s.contains('reject');
    }
    if (filter == 'Completed') {
      return s.contains('complet') ||
          s.contains('done') ||
          s.contains('finish');
    }
    if (filter == 'Cancelled') return s == 'cancelled';
    if (filter == 'Rejected') {
      return s.contains('reject');
    }
    return true;
  }

  // --- EXTRACT ORDER TIMESTAMP FOR PROPER SORTING ---
  DateTime _getOrderTimestamp(Map<String, dynamic> data) {
    final raw = data['createdAt'] ?? data['created_at'] ?? data['timestamp'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _confirmCancelCustomerOrder(String docId, String refId) async {
    final reason = await showDialog<String>(
        context: context, builder: (_) => OrderCancelDialog(reference: refId));
    if (reason == null) return;
    try {
      await cancelCustomerOrder(docId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Order $refId cancelled.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to cancel order: $error')));
    }
  }

  Widget _buildProfileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Color(0xFF15803D), size: 48),
          ),
          const SizedBox(height: 12),
          Text(widget.userEmail,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: DashboardTheme.ink)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showTermsAndConditionsDialog(context),
            icon: const Icon(Icons.gavel_rounded,
                size: 16, color: Color(0xFF15803D)),
            label: const Text("Terms & Conditions",
                style: TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFBBF7D0))),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showLogoutConfirmationDialog(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E)),
            child: const Text('Log Out',
                style: TextStyle(
                    color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CUSTOM PAINTERS (CHARTS & SPHERE)
// =============================================================================
class _FuturisticSpherePainter extends CustomPainter {
  final double progress;
  _FuturisticSpherePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final radiusX = size.width * 0.44;
    final radiusY = size.height * 0.38;

    final paintGlow = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final paintStroke = Paint()
      ..color = const Color(0xFF16A34A).withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final paintHighlight = Paint()
      ..color = const Color(0xFF86EFAC).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF15803D).withOpacity(0.20),
          const Color(0xFF1D4ED8).withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radiusX * 1.1));
    canvas.drawCircle(center, radiusX * 0.95, auraPaint);

    const int ringCount = 7;
    for (int i = 0; i < ringCount; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);

      final double angle =
          (i * (math.pi / ringCount)) + (progress * 2 * math.pi * 0.05);
      canvas.rotate(angle);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radiusX * (1.6 - (i * 0.1)),
        height: radiusY * (0.85 + (i * 0.08)),
      );

      canvas.drawOval(rect, paintGlow);
      canvas.drawOval(rect, i % 2 == 0 ? paintHighlight : paintStroke);

      canvas.restore();
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);
    final diagRect = Rect.fromCenter(
      center: Offset.zero,
      width: radiusX * 1.8,
      height: radiusY * 0.7,
    );
    canvas.drawOval(diagRect, paintHighlight);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FuturisticSpherePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<String, int> statusCounts;
  _DonutChartPainter({required this.statusCounts});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.2;
    const strokeWidth = 24.0;

    final total = statusCounts.values.fold(0, (acc, val) => acc + val);
    if (total == 0) return;

    double startAngle = -math.pi / 2;

    final colors = {
      'Completed': const Color(0xFFF59E0B),
      'Order Submitted': const Color(0xFF8B5CF6),
      'Printing': const Color(0xFF22C55E),
      'Rejected': const Color(0xFFF43F5E),
      'Cancelled': const Color(0xFF475569),
      'Ready for Pickup': const Color(0xFF10B981),
    };

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    statusCounts.forEach((key, cnt) {
      if (cnt > 0) {
        final sweepAngle = (cnt / total) * 2 * math.pi;
        paint.color = colors[key] ?? const Color(0xFF4B7A5E);

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
    final paint = Paint()..color = const Color(0xFF22C55E);
    final bgPaint = Paint()..color = const Color(0xFFF0FDF4);
    final gridPaint = Paint()
      ..color = const Color(0xFFBBF7D0)
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
      ..color = const Color(0xFF15803D)
      ..style = PaintingStyle.fill;

    final paintStore = Paint()
      ..color = const Color(0xFFFB923C)
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
