import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'store_screen.dart';
import 'place_order_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userEmail;
  const DashboardScreen({super.key, required this.userEmail});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNavIndex = 0;
  String _statusFilter = 'All Active';
  String _selectedServiceCategory = 'All Services';
  bool _isListView = true;

  final TextEditingController _searchController = TextEditingController();

  bool get _isAdmin => widget.userEmail.toLowerCase().contains('admin');

  CollectionReference get _ordersRef => FirebaseFirestore.instance
      .collection('artifacts')
      .doc('printcraft-pro')
      .collection('public')
      .doc('data')
      .collection('orders');

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
                  const Text('Kez C-Em Zek', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(widget.userEmail, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48)),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
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
          return _buildManageOrdersView();
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

  // --- WEB-MATCHED HOMEPAGE TAB ---
  Widget _buildCustomerHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Kez C-Em Zek Printing Service Web System',
                    style: TextStyle(color: Color(0xFFE11D48), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Streamlined Printing Orders with Real-Time Tracking & RFID Rewards',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'A clean, unified web solution for modern print shops: instant file proofing, accurate price calculations, stage-by-stage order monitoring, customer-staff live chat, RFID loyalty tapping, and real-time paper stock level sensors.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                ),
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
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Text('SIMPLE PROCESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFE11D48), letterSpacing: 1.2)),
                const SizedBox(height: 4),
                const Text('How It Works', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Text('Submit your print job online in 3 easy steps without waiting in line.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                _buildHowItWorksStep('1', 'Upload Your Document', 'Select paper stock, color mode, page counts, and upload your PDF or image file.'),
                const Divider(height: 24),
                _buildHowItWorksStep('2', 'Track Live Production', 'Monitor order status in real-time as staff approves and prints your job.'),
                const Divider(height: 24),
                _buildHowItWorksStep('3', 'Pickup or Pay Online', 'Receive notifications when ready for pickup at the store counter.'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWebServiceCard(String title, String desc, String price, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Expanded(
            child: Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF059669))),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE11D48)]),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }

  // --- ADMIN DASHBOARD ---
  // --- ADMIN DASHBOARD ---
  Widget _buildManageOrdersView() {
    return StreamBuilder<QuerySnapshot>(
      // NAKALAGAY DITO ANG OPTION 2: .orderBy('createdAt', descending: false)
      stream: _ordersRef.orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        // ... ang natitirang bahagi ng iyong code

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

          bool matchesCategory = _selectedServiceCategory == 'All Services' ||
              _cleanStr(serviceName).contains(_cleanStr(_selectedServiceCategory));

          bool matchesSearch = queryClean.isEmpty;
          if (!matchesSearch) {
            String fullDocString = '${_cleanStr(doc.id)} ${_cleanStr(data.toString())}';
            if (fullDocString.contains(queryClean)) {
              matchesSearch = true;
            }
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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.print_rounded, color: Color(0xFFE11D48)),
                      ),
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
              onChanged: (_) => setState(() {}),
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedServiceCategory,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF0F172A)),
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedServiceCategory = val);
                      },
                      items: ['All Services', 'Standard Print', 'Store Supply', 'PVC ID', 'Stickers', 'Photos']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildViewToggleBtn('List', Icons.list_alt_rounded, _isListView, () {
                        setState(() => _isListView = true);
                      }),
                      _buildViewToggleBtn('Cards', Icons.grid_view_rounded, !_isListView, () {
                        setState(() => _isListView = false);
                      }),
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
                      onSelected: (val) => setState(() => _statusFilter = status),
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
            if (filteredDocs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF1F5F9))),
                child: const Text('No matching orders found.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13)),
              )
            else
              ...filteredDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final docId = doc.id;

                final String displayRefId = (data['id'] ??
                    data['refId'] ??
                    data['ref_id'] ??
                    data['orderNumber'] ??
                    data['order_number'] ??
                    (docId.length > 10 ? 'PRNT-${docId.substring(0, 6).toUpperCase()}' : docId))
                    .toString();

                final serviceName = (data['service'] ?? data['serviceName'] ?? data['item_name'] ?? 'Standard A4 Print').toString();
                final customer = (data['customer'] ?? data['userEmail'] ?? data['fullName'] ?? 'Customer').toString();

                final rawTotal = data['total'] ?? data['price'] ?? data['amount'];
                final String totalStr = rawTotal != null
                    ? (rawTotal is num ? '₱${rawTotal.toStringAsFixed(2)}' : rawTotal.toString())
                    : '₱30.00';

                final status = (data['status'] ?? 'Order Submitted').toString();
                final payment = (data['payment'] ?? data['payment_method'] ?? 'GCash').toString();
                final dateTimeStr = _formatDateTime(data['createdAt'] ?? data['created_at'] ?? data['timestamp'] ?? data['date'] ?? data['time']);

                return _isListView
                    ? _buildOrderListItem(docId, displayRefId, serviceName, customer, totalStr, status, payment, dateTimeStr, data)
                    : _buildOrderCardItem(docId, displayRefId, serviceName, customer, totalStr, status, payment, dateTimeStr, data);
              }),
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
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
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
    Color statusBgColor;
    Color statusTextColor;
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
    } else {
      statusBgColor = const Color(0xFFFEF3C7);
      statusTextColor = const Color(0xFFD97706);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.receipt_rounded, size: 14, color: Color(0xFF475569)),
                  ),
                  const SizedBox(width: 8),
                  Text(refId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusTextColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.print_outlined, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(service, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(dateTimeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                    child: Text(payment, style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF059669))),
                ],
              ),
              Row(
                children: [
                  _buildDynamicActionButton(docId, status),
                  const SizedBox(width: 4),
                  _buildOrderActionMenu(docId, refId, dateTimeStr, data),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListItem(String docId, String refId, String service, String customer, String total, String status, String payment, String dateTimeStr, Map<String, dynamic> data) {
    final statusCategory = _getStatusCategory(status);
    Color accentColor;
    if (statusCategory == 'printing') {
      accentColor = const Color(0xFF2563EB);
    } else if (statusCategory == 'ready') {
      accentColor = const Color(0xFF16A34A);
    } else if (statusCategory == 'completed') {
      accentColor = const Color(0xFF059669);
    } else if (statusCategory == 'rejected') {
      accentColor = const Color(0xFFE11D48);
    } else {
      accentColor = const Color(0xFFD97706);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(refId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                child: Text(payment, style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(customer, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF334155)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(service, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(dateTimeStr, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                            child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor)),
                          ),
                          Row(
                            children: [
                              _buildDynamicActionButton(docId, status),
                              const SizedBox(width: 4),
                              _buildOrderActionMenu(docId, refId, dateTimeStr, data),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderActionMenu(String docId, String refId, String dateTimeStr, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF475569)),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (action) async {
          if (action == 'REVIEW_SPECS') {
            _showReviewSpecsDialog(context, data, refId, dateTimeStr);
          } else if (action == 'JOB_SLIP') {
            _showPrintJobSlipDialog(context, data, refId, dateTimeStr);
          } else if (action == 'REJECT') {
            await _ordersRef.doc(docId).update({'status': 'Rejected'});
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'REVIEW_SPECS',
            child: Row(
              children: const [
                Icon(Icons.visibility_rounded, color: Color(0xFF2563EB), size: 18),
                SizedBox(width: 10),
                Text('Review Specs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem(
            value: 'JOB_SLIP',
            child: Row(
              children: const [
                Icon(Icons.print_outlined, color: Color(0xFF9333EA), size: 18),
                SizedBox(width: 10),
                Text('Print Job Slip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem(
            value: 'REJECT',
            child: Row(
              children: const [
                Icon(Icons.cancel, color: Color(0xFFE11D48), size: 18),
                SizedBox(width: 10),
                Text('Reject Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UPDATED DIALOG WITH FILE DISPLAY & DOWNLOAD LINK ---
  void _showReviewSpecsDialog(BuildContext context, Map<String, dynamic> data, String refId, String dateTimeStr) {
    final String fileName = (data['file'] ?? data['fileName'] ?? 'Walang in-attach na file').toString();
    final String? fileUrl = (data['fileUrl'] ?? data['file_url'] ?? data['url']) as String?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.visibility_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Order Specifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('REF ID: $refId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
              const Divider(),
              Text('Customer: ${data['customer'] ?? data['userEmail'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Text('Service: ${data['service'] ?? data['serviceName'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Order Date/Time: $dateTimeStr', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              Text('Payment Method: ${data['payment'] ?? 'GCash'}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Text('Total Amount: ₱${data['total'] ?? '30.00'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              const SizedBox(height: 6),
              Text('Current Status: ${data['status'] ?? 'Order Submitted'}', style: const TextStyle(fontSize: 13, color: Color(0xFFD97706))),
              const Divider(height: 20),

              // ATTACHED FILE CONTAINER & OPEN BUTTON
              const Text('Attached Customer File:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (fileUrl != null && fileUrl.startsWith('http')) ...[
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final Uri uri = Uri.parse(fileUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Hindi mabuksan ang file URL.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 12, color: Colors.white),
                        label: const Text('Open', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrintJobSlipDialog(BuildContext context, Map<String, dynamic> data, String refId, String dateTimeStr) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.print_outlined, color: Color(0xFF9333EA)),
            SizedBox(width: 8),
            Text('Print Job Slip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_rounded, size: 48, color: Color(0xFF9333EA)),
            const SizedBox(height: 12),
            Text(refId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Client: ${data['customer'] ?? data['userEmail'] ?? 'Customer'}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                children: [
                  Text(
                    'Job Spec: ${data['service'] ?? data['serviceName'] ?? 'Standard Print'}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ordered: $dateTimeStr',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Qty / Specs: 1 Copy • A4 Paper • FIFO Queue',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Job slip sent to shop printer queue!')),
              );
            },
            icon: const Icon(Icons.print, size: 16, color: Colors.white),
            label: const Text('Send to Printer', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA)),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicActionButton(String orderId, String status) {
    final category = _getStatusCategory(status);

    if (category == 'approval') {
      return ElevatedButton.icon(
        onPressed: () async {
          await _ordersRef.doc(orderId).update({'status': 'Printing'});
        },
        icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
        label: const Text('Approve Order', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    } else if (category == 'printing') {
      return ElevatedButton.icon(
        onPressed: () async {
          await _ordersRef.doc(orderId).update({'status': 'Ready for Pickup'});
        },
        icon: const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
        label: const Text('Mark Ready', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    } else if (category == 'ready') {
      return ElevatedButton.icon(
        onPressed: () async {
          await _ordersRef.doc(orderId).update({'status': 'Completed'});
        },
        icon: const Icon(Icons.task_alt_rounded, size: 14, color: Colors.white),
        label: const Text('Complete Order', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
            SizedBox(width: 4),
            Text('Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          ],
        ),
      );
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
        const SizedBox(height: 20),
        const Text('Registered Customers (Database)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('customers').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text('No registered customers found in database.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12));
            }
            final custDocs = snapshot.data!.docs;
            return Column(
              children: custDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final fullName = (data['fullName'] ?? 'Customer').toString();
                final email = (data['email'] ?? '').toString();
                final contact = (data['contact'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF1F5F9))),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.person, color: Color(0xFF3B82F6))),
                    title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Email: $email\nContact: $contact', style: const TextStyle(fontSize: 11)),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // --- HIWALAY NA CUSTOMER ORDERS TAB NA MAY "PLACE NEW ORDER" BUTTON ---
  Widget _buildCustomerOrdersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlaceOrderScreen(userEmail: widget.userEmail)),
                );
              },
              icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
              label: const Text('Place New Print Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _ordersRef.where('email', isEqualTo: widget.userEmail).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Wala ka pang order. Pindutin ang button sa itaas para umorder!',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(data['id'] ?? 'PRNT-xxxx', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                              child: Text(data['status'] ?? 'Submitted', style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(data['service'] ?? 'Print Service', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                        const SizedBox(height: 4),
                        Text('Total: ₱${data['total'] ?? '30.00'} • Payment: ${data['payment'] ?? 'GCash'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 36, backgroundColor: Color(0xFFFFF1F2), child: Icon(Icons.person, color: Color(0xFFE11D48))),
            const SizedBox(height: 12),
            Text(widget.userEmail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
              child: const Text('Log Out', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}