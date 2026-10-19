import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../services/local_db_service.dart';
import '../services/supabase_storage_service.dart';

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
  int _selectedFileSize = 0;
  File? _selectedFileObj;

  // Common Controllers
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _pagesController = TextEditingController(text: '1');
  final TextEditingController _widthController = TextEditingController(text: '3');
  final TextEditingController _heightController = TextEditingController(text: '4');
  final TextEditingController _noteController = TextEditingController();
  static const int _maxNoteLength = 500;

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
    _selectedService = _serviceOptions.first;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _pagesController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _calculatedTotal {
    int qty = int.tryParse(_quantityController.text) ?? 1;
    if (qty < 1) qty = 1;

    if (_selectedService.contains('Standard A4 Print')) {
      int pages = int.tryParse(_pagesController.text) ?? 1;
      if (pages < 1) pages = 1;
      return pages * qty * 3.00;
    } else if (_selectedService.contains('Business Cards')) {
      double basePrice = 250.0;
      if (_bcSides.contains('2-Side')) basePrice += 100.0;
      if (_bcFinish.contains('Soft Touch')) basePrice += 50.0;
      return (qty / 100).ceil() * basePrice;
    } else if (_selectedService.contains('Tarpaulins')) {
      double w = double.tryParse(_widthController.text) ?? 3.0;
      double h = double.tryParse(_heightController.text) ?? 4.0;
      double sqft = w * h;
      double rate = _tarpThickness.contains('13 oz') ? 20.0 : 15.0;
      return sqft * rate * qty;
    } else if (_selectedService.contains('Flyers')) {
      double base = _flyerSize.contains('A4') ? 3.50 : 2.50;
      if (_flyerSides.contains('2-Side')) base += 1.50;
      return base * qty;
    } else if (_selectedService.contains('Stickers')) {
      double base = _stickerSize.contains('3x3') ? 8.00 : 5.00;
      if (_stickerMaterial.contains('Vinyl')) base += 2.00;
      return base * qty;
    } else if (_selectedService.contains('Invitations')) {
      double base = 35.00;
      if (_invEnvelope.contains('With Matching')) base += 10.00;
      return base * qty;
    } else if (_selectedService.contains('Shirt')) {
      double base = 180.00;
      if (_shirtLocation.contains('Front & Back')) base += 50.00;
      return base * qty;
    } else if (_selectedService.contains('Photo')) {
      double base = 120.00;
      if (_photoSize.contains('12 x 18')) base = 250.00;
      if (_photoFrame.contains('Frame')) base += 150.00;
      return base * qty;
    } else if (_selectedService.contains('Booklets')) {
      int pages = int.tryParse(_pagesController.text) ?? 10;
      return (pages * 2.50 + 20.00) * qty;
    }
    return 30.00;
  }

  Future<void> _pickDeviceFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: SupabaseStorageService.allowedExtensions,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        final pickedName = result.files.single.name;

        final validationErr = SupabaseStorageService.validateFile(pickedFile, pickedName);
        if (validationErr != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(validationErr), backgroundColor: const Color(0xFFF43F5E)),
          );
          return;
        }

        setState(() {
          _selectedFileName = pickedName;
          _selectedFileSize = pickedFile.lengthSync();
          _selectedFileObj = pickedFile;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'), backgroundColor: const Color(0xFFF43F5E)),
      );
    }
  }

  void _removeSelectedFile() {
    setState(() {
      _selectedFileName = 'Walang napiling file';
      _selectedFileSize = 0;
      _selectedFileObj = null;
    });
  }

  Future<void> _submitOrder() async {
    final noteText = _noteController.text.trim();
    if (noteText.length > _maxNoteLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Special instructions cannot exceed 500 characters.'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String customOrderRef = 'PRNT-${Random().nextInt(900000) + 100000}';
      String fileDownloadUrl = 'Pending / Direct In-Store Upload';

      if (_selectedFileObj != null) {
        try {
          fileDownloadUrl = await SupabaseStorageService.uploadFile(
            file: _selectedFileObj!,
            originalFilename: _selectedFileName,
            orderId: customOrderRef,
          );
        } catch (storageErr) {
          debugPrint('Supabase Storage Upload Warning: $storageErr');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File upload warning: $storageErr'),
              backgroundColor: const Color(0xFFF43F5E),
            ),
          );
          return;
        }
      }

      final Map<String, dynamic> orderPayload = {
        'id': customOrderRef,
        'customer': widget.userEmail.split('@').first,
        'email': widget.userEmail,
        'service': _selectedService,
        'total': _calculatedTotal,
        'status': 'For Approval',
        'payment': _paymentMethod,
        'fileName': _selectedFileName,
        'fileUrl': fileDownloadUrl,
        'customerNote': noteText,
        'specialInstructions': noteText,
        'createdAt': FieldValue.serverTimestamp(),
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'details': {
          if (_selectedService.contains('Business Cards')) ...{
            'size': _bcSize,
            'paper': _bcPaper,
            'sides': _bcSides,
            'finish': _bcFinish,
            'corners': _bcCorners,
          },
          if (_selectedService.contains('Tarpaulins')) ...{
            'dimensions': '${_widthController.text}ft x ${_heightController.text}ft',
            'thickness': _tarpThickness,
            'eyelets': _tarpEyelets,
            'finishing': _tarpFinishing,
          },
          if (_selectedService.contains('Flyers')) ...{
            'size': _flyerSize,
            'paper': _flyerPaper,
            'sides': _flyerSides,
            'finish': _flyerFinish,
            'fold': _flyerFold,
          },
          if (_selectedService.contains('Stickers')) ...{
            'size': _stickerSize,
            'shape': _stickerShape,
            'material': _stickerMaterial,
            'finish': _stickerFinish,
            'adhesive': _stickerAdhesive,
          },
          if (_selectedService.contains('Invitations')) ...{
            'size': _invSize,
            'paper': _invPaper,
            'sides': _invSides,
            'finish': _invFinish,
            'envelope': _invEnvelope,
          },
          if (_selectedService.contains('Shirt')) ...{
            'size': _shirtSize,
            'color': _shirtColor,
            'fabric': _shirtFabric,
            'method': _shirtMethod,
            'location': _shirtLocation,
          },
          if (_selectedService.contains('Photo')) ...{
            'size': _photoSize,
            'material': _photoMaterial,
            'orientation': _photoOrientation,
            'finish': _photoFinish,
            'frame': _photoFrame,
          },
          if (_selectedService.contains('Booklets')) ...{
            'size': _bookletSize,
            'pages': _pagesController.text,
            'paper': _bookletPaper,
            'cover': _bookletCover,
            'binding': _bookletBinding,
          },
        },
      };

      try {
        await FirebaseFirestore.instance
            .collection('artifacts')
            .doc('printcraft-pro')
            .collection('public')
            .doc('data')
            .collection('orders')
            .add(orderPayload);
      } catch (firestoreErr) {
        debugPrint('Firestore offline fallback: $firestoreErr');
        await LocalDbService.instance.insertOrUpdateOrder(orderPayload, isSynced: false);
      }

      if (!mounted) return;

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
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Order Submitted!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tracking Ref: $customOrderRef', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF818CF8))),
              const SizedBox(height: 6),
              const Text('Your order has been queued for shop approval. You will receive real-time notifications on production status.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting order: $e'), backgroundColor: const Color(0xFFF43F5E)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070A14),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E293B)),
        ),
        title: const Text('Place Print Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
                color: const Color(0xFF0D1224),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.upload_file_rounded, size: 40, color: Color(0xFF818CF8)),
                  const SizedBox(height: 8),
                  if (_selectedFileObj != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _selectedFileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFFF43F5E), size: 18),
                          tooltip: 'Remove file',
                          onPressed: _removeSelectedFile,
                        ),
                      ],
                    ),
                    Text(
                      'Size: ${(_selectedFileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ] else ...[
                    Text(_selectedFileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 6),
                  const Text(
                    'Allowed: PDF, PNG, JPG, JPEG, DOC, DOCX (Max 10MB per file, up to 5 files / 25MB total)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickDeviceFile,
                    icon: const Icon(Icons.folder_open_rounded, size: 16, color: Colors.white),
                    label: Text(_selectedFileObj != null ? 'Change File' : 'Choose File', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
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
              decoration: BoxDecoration(
                color: const Color(0xFF0D1224),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Printing Service Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF0F172A),
                    initialValue: _selectedService,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                    ),
                    items: _serviceOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12, color: Colors.white), overflow: TextOverflow.ellipsis)))
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
                        color: _paymentMethod == 'GCash Online' ? const Color(0xFF4F46E5).withValues(alpha: 0.15) : const Color(0xFF0D1224),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _paymentMethod == 'GCash Online' ? const Color(0xFF4F46E5) : const Color(0xFF1E293B), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          // ignore: deprecated_member_use
                          Radio<String>(
                            value: 'GCash Online',
                            // ignore: deprecated_member_use
                            groupValue: _paymentMethod,
                            activeColor: const Color(0xFF818CF8),
                            // ignore: deprecated_member_use
                            onChanged: (val) => setState(() => _paymentMethod = val!),
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('GCash Online', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                Text('Pay instantly', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
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
                        color: _paymentMethod == 'Cash on Pickup' ? const Color(0xFF4F46E5).withValues(alpha: 0.15) : const Color(0xFF0D1224),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _paymentMethod == 'Cash on Pickup' ? const Color(0xFF4F46E5) : const Color(0xFF1E293B), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          // ignore: deprecated_member_use
                          Radio<String>(
                            value: 'Cash on Pickup',
                            // ignore: deprecated_member_use
                            groupValue: _paymentMethod,
                            activeColor: const Color(0xFF818CF8),
                            // ignore: deprecated_member_use
                            onChanged: (val) => setState(() => _paymentMethod = val!),
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cash on Pickup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                Text('Pay at counter', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
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

            _buildSectionHeader('STEP 4: SPECIAL INSTRUCTIONS / ORDER NOTE (OPTIONAL)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1224),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order Note (Optional)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        '${_noteController.text.length}/$_maxNoteLength',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _noteController.text.length > _maxNoteLength
                              ? const Color(0xFFF43F5E)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _noteController,
                    maxLines: 4,
                    maxLength: _maxNoteLength,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (_) => setState(() {}),
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    decoration: InputDecoration(
                      hintText: 'Write any special instructions for your order...\n(e.g., orientation, paper preference, urgent timing)',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.4),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1E293B)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1224),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL SUMMARY', style: TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  const Text('Estimated Total:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    '₱${_calculatedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 28),
                  ),
                  const Divider(color: Color(0xFF1E293B), height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Text(_paymentMethod, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estimated Pickup:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
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
                        backgroundColor: const Color(0xFF4F46E5),
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
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          dropdownColor: const Color(0xFF0F172A),
          initialValue: items.contains(value) ? value : items.first,
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 11),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
          ),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 10, color: Colors.white), overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF818CF8), letterSpacing: 1.1));
  }
}