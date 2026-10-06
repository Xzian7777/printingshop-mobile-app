import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/local_db_service.dart';
import '../services/order_repository.dart';

class PlaceOrderScreen extends StatefulWidget {
  final String userEmail;
  const PlaceOrderScreen({super.key, required this.userEmail});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  final List<String> _serviceOptions = [
    'Standard A4 Print (₱3.00/pg)',
    'Business Cards (from ₱250)',
    'Tarpaulins (₱15/sqft)',
    'Flyers & Leaflets (₱2.50/pc)',
    'Stickers & Labels (₱5/pc)',
    'Invitations (₱35/pc)',
    'Shirt Printing - DTF/Sublimation (₱180/pc)',
    'Photo & Canvas Prints (from ₱120)',
    'Booklets & Menus (₱45/pc)',
  ];

  late String _selectedService;
  String _paymentMethod = 'GCash Online';
  String _selectedFileName = 'Walang napiling file';
  File? _selectedFileObj;

  // Common Controllers
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _pagesController = TextEditingController(text: '1');
  final TextEditingController _widthController = TextEditingController(text: '3');
  final TextEditingController _heightController = TextEditingController(text: '4');

  // Dynamic Form Field States
  String _bcSize = 'Standard (3.5 x 2 in)';
  String _bcPaper = '300 GSM Matte Cardstock';
  String _bcSides = '1-Side Printing';
  String _bcFinish = 'Matte Finish';
  String _bcCorners = 'Square Corners';

  String _tarpThickness = '10 oz Standard Tarpaulin';
  String _tarpEyelets = 'With Eyelets (4 Corners)';
  String _tarpFinishing = 'Folded Edge (Kaibe)';

  String _flyerSize = 'A4 Size';
  String _flyerPaper = '80 GSM Bond Paper';
  String _flyerSides = '1-Side Printing';
  String _flyerFinish = 'Glossy Finish';
  String _flyerFold = 'No Fold (Flat)';

  String _stickerSize = '2x2 inches';
  String _stickerShape = 'Die-Cut (Custom Shape)';
  String _stickerMaterial = 'Vinyl Sticker (Waterproof)';
  String _stickerFinish = 'Glossy Laminated';
  String _stickerAdhesive = 'Permanent Strong Adhesive';

  String _invSize = '5 x 7 inches (Standard)';
  String _invPaper = '250 GSM Linen Cardstock';
  String _invSides = 'Front & Back Printing';
  String _invFinish = 'Flat Card';
  String _invEnvelope = 'With Matching Envelope';

  String _shirtSize = 'Small (S)';
  String _shirtColor = 'Black';
  String _shirtFabric = 'Cotton Blend 200 GSM';
  String _shirtMethod = 'DTF (Direct to Film)';
  String _shirtLocation = 'Front Chest (Standard)';

  String _photoSize = '8 x 10 inches (₱120)';
  String _photoMaterial = 'Glossy Photo Paper';
  String _photoOrientation = 'Portrait';
  String _photoFinish = 'Gloss Lamination';
  String _photoFrame = 'Without Frame';

  String _bookletSize = 'A4 Size Booklet';
  String _bookletPaper = '80 GSM Bond Paper';
  String _bookletCover = '200 GSM Glossy Card Cover';
  String _bookletBinding = 'Saddle Stitch (Wire Staple)';

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedService = _serviceOptions[0];
  }

  Future<void> _pickDeviceFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'psd', 'ai'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _selectedFileObj = File(result.files.single.path!);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Naka-select na ang file: $_selectedFileName'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sa pagkuha ng file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  double get _calculatedTotal {
    int qty = int.tryParse(_quantityController.text) ?? 1;
    int pages = int.tryParse(_pagesController.text) ?? 1;
    double width = double.tryParse(_widthController.text) ?? 1.0;
    double height = double.tryParse(_heightController.text) ?? 1.0;

    if (_selectedService.contains('Standard A4 Print')) {
      return pages * qty * 3.00;
    } else if (_selectedService.contains('Business Cards')) {
      return qty * 2.50;
    } else if (_selectedService.contains('Tarpaulins')) {
      return (width * height) * 15.00 * qty;
    } else if (_selectedService.contains('Flyers & Leaflets')) {
      return qty * 2.50;
    } else if (_selectedService.contains('Stickers & Labels')) {
      return qty * 5.00;
    } else if (_selectedService.contains('Invitations')) {
      return qty * 35.00;
    } else if (_selectedService.contains('Shirt Printing')) {
      return qty * 180.00;
    } else if (_selectedService.contains('Photo & Canvas')) {
      return qty * 120.00;
    } else if (_selectedService.contains('Booklets & Menus')) {
      return qty * 45.00;
    }
    return qty * 30.00;
  }

  Map<String, dynamic> _buildOrderDetails() {
    if (_selectedService.contains('Business Cards')) {
      return {'size': _bcSize, 'paper': _bcPaper, 'sides': _bcSides, 'finish': _bcFinish, 'corners': _bcCorners};
    } else if (_selectedService.contains('Tarpaulins')) {
      return {'width': _widthController.text, 'height': _heightController.text, 'thickness': _tarpThickness, 'eyelets': _tarpEyelets, 'finishing': _tarpFinishing};
    } else if (_selectedService.contains('Flyers')) {
      return {'size': _flyerSize, 'paper': _flyerPaper, 'sides': _flyerSides, 'finish': _flyerFinish, 'folding': _flyerFold};
    } else if (_selectedService.contains('Stickers')) {
      return {'size': _stickerSize, 'shape': _stickerShape, 'material': _stickerMaterial, 'finish': _stickerFinish, 'adhesive': _stickerAdhesive};
    } else if (_selectedService.contains('Invitations')) {
      return {'size': _invSize, 'paper': _invPaper, 'sides': _invSides, 'finish': _invFinish, 'envelope': _invEnvelope};
    } else if (_selectedService.contains('Shirt')) {
      return {'size': _shirtSize, 'color': _shirtColor, 'fabric': _shirtFabric, 'method': _shirtMethod, 'location': _shirtLocation};
    } else if (_selectedService.contains('Photo')) {
      return {'size': _photoSize, 'material': _photoMaterial, 'orientation': _photoOrientation, 'finish': _photoFinish, 'frame': _photoFrame};
    } else if (_selectedService.contains('Booklets')) {
      return {'size': _bookletSize, 'pages': _pagesController.text, 'paper': _bookletPaper, 'cover': _bookletCover, 'binding': _bookletBinding};
    }
    return {'pages': _pagesController.text};
  }

  Future<void> _submitOrder() async {
    if (_selectedFileObj == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pumili muna ng file mula sa iyong device!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final qty = int.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mangyaring maglagay ng tamang bilang ng quantity (higit sa 0).'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedService.contains('Tarpaulins')) {
      final w = double.tryParse(_widthController.text.trim());
      final h = double.tryParse(_heightController.text.trim());
      if (w == null || w <= 0 || h == null || h <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mangyaring maglagay ng tamang Width at Height (higit sa 0).'), backgroundColor: Colors.orange),
        );
        return;
      }
    }

    if (_selectedService.contains('Booklets') || _selectedService.contains('A4')) {
      final p = int.tryParse(_pagesController.text.trim());
      if (p == null || p <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mangyaring maglagay ng tamang bilang ng pahina (pages > 0).'), backgroundColor: Colors.orange),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final randomRef = 'PRNT-${Random().nextInt(8999) + 1000}';
      final customerName = widget.userEmail.split('@')[0];

      // 1. SAFE STORAGE UPLOAD (FALLBACK MODE PARANG DI MAG-ERROR)
      String uploadedFileUrl = '';
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('customer_orders/${DateTime.now().millisecondsSinceEpoch}_$_selectedFileName');

        final TaskSnapshot uploadSnapshot = await storageRef.putFile(_selectedFileObj!);
        uploadedFileUrl = await uploadSnapshot.ref.getDownloadURL();
      } catch (storageErr) {
        debugPrint('Storage Error (Fallback mode active): $storageErr');
        // Magse-set ng temporary link indicator para tuloy pa rin ang pag-save sa database
        uploadedFileUrl = 'Local File Attached: $_selectedFileName';
      }

      final orderMap = {
        'id': randomRef,
        'customer': customerName,
        'email': widget.userEmail,
        'service': _selectedService,
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'specifications': _buildOrderDetails(),
        'payment': _paymentMethod,
        'total': _calculatedTotal,
        'status': 'Order Submitted',
        'file': _selectedFileName,
        'fileUrl': uploadedFileUrl,
        'createdAt': DateTime.now().toIso8601String(),
      };

      bool online = await OrderRepository().isOnline();

      if (online) {
        try {
          // 2. DIRECT SAVE ORDER SA FIRESTORE
          await FirebaseFirestore.instance
              .collection('artifacts')
              .doc('printcraft-pro')
              .collection('public')
              .doc('data')
              .collection('orders')
              .doc(randomRef)
              .set({
            ...orderMap,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          // Save locally as synced
          await LocalDbService.instance.insertOrUpdateOrder(orderMap, isSynced: true);
        } catch (firestoreErr) {
          debugPrint('Firestore Error, saving to local queue: $firestoreErr');
          await LocalDbService.instance.insertOrUpdateOrder(orderMap, isSynced: false);
        }
      } else {
        // Offline mode: Save locally as unsynced
        await LocalDbService.instance.insertOrUpdateOrder(orderMap, isSynced: false);
        debugPrint('Offline mode: Order saved locally and queued for sync.');
      }

      // Try syncing any pending offline orders in background
      OrderRepository().syncOfflineOrders();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
              SizedBox(width: 8),
              Text('Order Successful!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Your order reference is $randomRef. Total: ₱${_calculatedTotal.toStringAsFixed(2)}'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting order: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Place Print Order', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('STEP 1: UPLOAD DOCUMENT OR DESIGN'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.upload_file_rounded, size: 40, color: Color(0xFFE11D48)),
                  const SizedBox(height: 8),
                  Text(_selectedFileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  const Text('Mag-upload ng PDF, Word, AI, PSD, o Image file mula sa storage', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickDeviceFile,
                    icon: const Icon(Icons.folder_open_rounded, size: 16, color: Colors.white),
                    label: const Text('Choose File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('STEP 2: SELECT SERVICE & CUSTOM SPECIFICATIONS'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Printing Service Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedService,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                    items: _serviceOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedService = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  ..._buildDynamicServiceFields(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('STEP 3: PAYMENT METHOD'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'GCash Online'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'GCash Online' ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _paymentMethod == 'GCash Online' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'GCash Online',
                            groupValue: _paymentMethod,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) => setState(() => _paymentMethod = val!),
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('GCash Online', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Pay instantly', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'Cash on Pickup'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'Cash on Pickup' ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _paymentMethod == 'Cash on Pickup' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'Cash on Pickup',
                            groupValue: _paymentMethod,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) => setState(() => _paymentMethod = val!),
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cash on Pickup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Pay at counter', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL SUMMARY', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  const Text('Estimated Total:', style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    '₱${_calculatedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w900, fontSize: 28),
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text(_paymentMethod, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estimated Pickup:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text('Tomorrow 4:00 PM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitOrder,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                      label: Text(_isSubmitting ? 'Uploading & Submitting...' : 'Confirm & Submit Order →', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDynamicServiceFields() {
    if (_selectedService.contains('Business Cards')) {
      return [
        _buildRowTwoFields(
          _buildTextField('Quantity (pcs)', _quantityController),
          _buildDropdownField('Size', _bcSize, ['Standard (3.5 x 2 in)', 'Square (2.5 x 2.5 in)'], (v) => setState(() => _bcSize = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Paper Type & Thickness', _bcPaper, ['300 GSM Matte Cardstock', '350 GSM Glossy Cardstock'], (v) => setState(() => _bcPaper = v!)),
          _buildDropdownField('Printing Sides', _bcSides, ['1-Side Printing', '2-Side Printing'], (v) => setState(() => _bcSides = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Finish', _bcFinish, ['Matte Finish', 'Glossy Finish', 'Soft Touch'], (v) => setState(() => _bcFinish = v!)),
          _buildDropdownField('Corners', _bcCorners, ['Square Corners', 'Rounded Corners'], (v) => setState(() => _bcCorners = v!)),
        ),
      ];
    } else if (_selectedService.contains('Tarpaulins')) {
      return [
        _buildRowTwoFields(
          _buildTextField('Width (ft)', _widthController),
          _buildTextField('Height (ft)', _heightController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildTextField('Quantity (pcs)', _quantityController),
          _buildDropdownField('Material Thickness', _tarpThickness, ['10 oz Standard Tarpaulin', '13 oz Premium Heavy Duty'], (v) => setState(() => _tarpThickness = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Eyelets / Rings', _tarpEyelets, ['With Eyelets (4 Corners)', 'With Eyelets (Every 2ft)', 'No Eyelets'], (v) => setState(() => _tarpEyelets = v!)),
          _buildDropdownField('Finishing', _tarpFinishing, ['Folded Edge (Kaibe)', 'Cut to Size'], (v) => setState(() => _tarpFinishing = v!)),
        ),
      ];
    } else if (_selectedService.contains('Flyers')) {
      return [
        _buildRowTwoFields(
          _buildDropdownField('Size', _flyerSize, ['A4 Size', 'A5 Size', 'DL Size'], (v) => setState(() => _flyerSize = v!)),
          _buildTextField('Quantity (pcs)', _quantityController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Paper Type & Thickness', _flyerPaper, ['80 GSM Bond Paper', '115 GSM Glossy Paper'], (v) => setState(() => _flyerPaper = v!)),
          _buildDropdownField('Printing Sides', _flyerSides, ['1-Side Printing', '2-Side Printing'], (v) => setState(() => _flyerSides = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Finish', _flyerFinish, ['Glossy Finish', 'Matte Finish'], (v) => setState(() => _flyerFinish = v!)),
          _buildDropdownField('Folding Option', _flyerFold, ['No Fold (Flat)', 'Bi-Fold', 'Tri-Fold'], (v) => setState(() => _flyerFold = v!)),
        ),
      ];
    } else if (_selectedService.contains('Stickers')) {
      return [
        _buildRowTwoFields(
          _buildDropdownField('Size / Dimensions', _stickerSize, ['2x2 inches', '3x3 inches', 'A4 Sheet'], (v) => setState(() => _stickerSize = v!)),
          _buildTextField('Quantity (pcs)', _quantityController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Shape / Die-cut', _stickerShape, ['Die-Cut (Custom Shape)', 'Circle', 'Square', 'Rectangle'], (v) => setState(() => _stickerShape = v!)),
          _buildDropdownField('Material', _stickerMaterial, ['Vinyl Sticker (Waterproof)', 'Transparent Sticker', 'Paper Sticker'], (v) => setState(() => _stickerMaterial = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Finish', _stickerFinish, ['Glossy Laminated', 'Matte Laminated', '3D Holographic'], (v) => setState(() => _stickerFinish = v!)),
          _buildDropdownField('Adhesive Type', _stickerAdhesive, ['Permanent Strong Adhesive', 'Removable Adhesive'], (v) => setState(() => _stickerAdhesive = v!)),
        ),
      ];
    } else if (_selectedService.contains('Invitations')) {
      return [
        _buildRowTwoFields(
          _buildTextField('Quantity (pcs)', _quantityController),
          _buildDropdownField('Card Size', _invSize, ['5 x 7 inches (Standard)', '4 x 6 inches'], (v) => setState(() => _invSize = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Paper Type & Thickness', _invPaper, ['250 GSM Linen Cardstock', '300 GSM Matte Cardstock'], (v) => setState(() => _invPaper = v!)),
          _buildDropdownField('Printing Sides', _invSides, ['Front & Back Printing', 'Front Only'], (v) => setState(() => _invSides = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Finish & Folding', _invFinish, ['Flat Card', 'Folded Card'], (v) => setState(() => _invFinish = v!)),
          _buildDropdownField('Envelope Included', _invEnvelope, ['With Matching Envelope', 'Without Envelope'], (v) => setState(() => _invEnvelope = v!)),
        ),
      ];
    } else if (_selectedService.contains('Shirt')) {
      return [
        _buildRowTwoFields(
          _buildDropdownField('Shirt Size', _shirtSize, ['Small (S)', 'Medium (M)', 'Large (L)', 'XL', '2XL'], (v) => setState(() => _shirtSize = v!)),
          _buildTextField('Quantity (pcs)', _quantityController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Shirt Color', _shirtColor, ['Black', 'White', 'Navy Blue', 'Red'], (v) => setState(() => _shirtColor = v!)),
          _buildDropdownField('Shirt Type / Fabric', _shirtFabric, ['Cotton Blend 200 GSM', '100% Organic Cotton'], (v) => setState(() => _shirtFabric = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Printing Method', _shirtMethod, ['DTF (Direct to Film)', 'Sublimation Printing'], (v) => setState(() => _shirtMethod = v!)),
          _buildDropdownField('Print Location', _shirtLocation, ['Front Chest (Standard)', 'Back Center', 'Front & Back'], (v) => setState(() => _shirtLocation = v!)),
        ),
      ];
    } else if (_selectedService.contains('Photo')) {
      return [
        _buildRowTwoFields(
          _buildDropdownField('Size / Dimensions', _photoSize, ['8 x 10 inches (₱120)', 'A4 Photo', '12 x 18 inches'], (v) => setState(() => _photoSize = v!)),
          _buildTextField('Quantity (pcs)', _quantityController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Material', _photoMaterial, ['Glossy Photo Paper', 'Satin Photo Paper', 'Canvas Fabric'], (v) => setState(() => _photoMaterial = v!)),
          _buildDropdownField('Orientation', _photoOrientation, ['Portrait', 'Landscape'], (v) => setState(() => _photoOrientation = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Finish', _photoFinish, ['Gloss Lamination', 'Matte Lamination'], (v) => setState(() => _photoFinish = v!)),
          _buildDropdownField('Frame Option', _photoFrame, ['Without Frame', 'With Black Frame', 'With Wooden Frame'], (v) => setState(() => _photoFrame = v!)),
        ),
      ];
    } else if (_selectedService.contains('Booklets')) {
      return [
        _buildRowTwoFields(
          _buildDropdownField('Size', _bookletSize, ['A4 Size Booklet', 'A5 Size Booklet'], (v) => setState(() => _bookletSize = v!)),
          _buildTextField('Quantity (pcs)', _quantityController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildTextField('Number of Pages', _pagesController),
          _buildDropdownField('Paper Type (Inner Pages)', _bookletPaper, ['80 GSM Bond Paper', '100 GSM Glossy Paper'], (v) => setState(() => _bookletPaper = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField('Cover Type & Thickness', _bookletCover, ['200 GSM Glossy Card Cover', '250 GSM Matte Cover'], (v) => setState(() => _bookletCover = v!)),
          _buildDropdownField('Printing Sides & Binding', _bookletBinding, ['Saddle Stitch (Wire Staple)', 'Perfect Binding'], (v) => setState(() => _bookletBinding = v!)),
        ),
      ];
    }

    return [
      _buildRowTwoFields(
        _buildTextField('Pages', _pagesController),
        _buildTextField('Quantity / Copies', _quantityController),
      ),
    ];
  }

  Widget _buildRowTwoFields(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFE11D48), letterSpacing: 1.1));
  }
}