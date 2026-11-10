import '../services/loyalty_api.dart';
import '../widgets/points_selector.dart';
import '../services/app_notifications.dart';
import '../widgets/store_checkout_sheet.dart' show gcashQrSource;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/catalog_pricing.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../services/local_db_service.dart';
import '../services/supabase_storage_service.dart';
import '../services/order_validation.dart';
import '../services/order_number_input_formatter.dart';
import '../services/order_reference.dart';
import 'admin_catalog_view.dart' show sharedImage;

class PlaceOrderScreen extends StatefulWidget {
  final String userEmail;
  const PlaceOrderScreen({super.key, required this.userEmail});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  int _pointsUsed = 0;
  double _pointsDiscount = 0;
  String? _loyaltyKey;

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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _servicesSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _gcashSub;
  final Map<String, Map<String, dynamic>> _catalog = {};
  final Map<String, dynamic> _requirementValues = {};
  Map<String, dynamic> _gcash = {};
  bool _catalogLoaded = false;
  String? _catalogError;
  Map<String, dynamic>? get _serviceData => _catalog[_selectedService];
  String get _serviceKind =>
      const {
        'standardA4': 'Standard A4 Print',
        'businessCards': 'Business Cards',
        'tarpaulins': 'Tarpaulins',
        'flyers': 'Flyers',
        'stickers': 'Stickers',
        'invitations': 'Invitations',
        'shirt': 'Shirt',
        'photoCanvas': 'Photo',
        'booklets': 'Booklets',
        'mug': 'Mug',
      }[_serviceData?['id']] ??
      _selectedService;
  List<Map<String, dynamic>> get _requirements =>
      (_serviceData?['requirements'] as List? ?? [])
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  String _paymentMethod = 'GCash Online';
  String _selectedFileName = 'No file selected';
  int _selectedFileSize = 0;
  File? _selectedFileObj;
  File? _receiptFile;
  String _receiptName = '';

  // Common Controllers
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final TextEditingController _pagesController =
      TextEditingController(text: '1');
  final TextEditingController _widthController =
      TextEditingController(text: '3');
  final TextEditingController _heightController =
      TextEditingController(text: '4');
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _gcashReferenceController =
      TextEditingController();
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
    _listenCatalog();
  }

  void _listenCatalog() {
    _servicesSub?.cancel();
    _gcashSub?.cancel();
    try {
      _servicesSub = FirebaseFirestore.instance
          .collection('services')
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        if (_isSubmitting) return;
        final docs = snapshot.docs
            .where((d) => d.data()['archived'] != true)
            .toList()
          ..sort((a, b) => ((a.data()['sortOrder'] as num?) ?? 0)
              .compareTo((b.data()['sortOrder'] as num?) ?? 0));
        setState(() {
          final selectedId = _serviceData?['id'];
          final previousRequirements =
              jsonEncode(_serviceData?['requirements']);
          _catalog.clear();
          for (final doc in docs) {
            final data = {...doc.data(), 'id': doc.id};
            _catalog['${data['name']} (${data['unit'] ?? ''}) [${doc.id}]'] =
                data;
          }
          _serviceOptions
            ..clear()
            ..addAll(_catalog.keys);
          _selectedService = _catalog.keys
                  .where((k) => _catalog[k]!['id'] == selectedId)
                  .firstOrNull ??
              (_serviceOptions.isEmpty ? '' : _serviceOptions.first);
          if (previousRequirements != jsonEncode(_serviceData?['requirements']))
            _requirementValues.clear();
          _catalogLoaded = true;
          _catalogError = null;
        });
      }, onError: (Object e) {
        if (mounted) setState(() => _catalogError = e.toString());
      });
      _gcashSub = FirebaseFirestore.instance
          .collection('settings')
          .doc('gcash_config')
          .snapshots()
          .listen((snapshot) {
        if (!mounted || _isSubmitting) return;
        setState(() {
          _gcash = snapshot.data() ?? {};
          if (_gcash['isActive'] == false) _paymentMethod = 'Cash on Pickup';
        });
      }, onError: (Object e) {
        if (mounted)
          setState(() {
            _gcash = {'isActive': false};
            _paymentMethod = 'Cash on Pickup';
          });
      });
    } catch (e) {
      _catalogError = e.toString();
    }
  }

  @override
  void dispose() {
    _servicesSub?.cancel();
    _gcashSub?.cancel();
    _quantityController.dispose();
    _pagesController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _noteController.dispose();
    _gcashReferenceController.dispose();
    super.dispose();
  }

  double get _calculatedTotal {
    final data = _serviceData;
    if (data != null) {
      final base = double.tryParse('${data['basePrice']}') ?? 0;
      final qty = int.tryParse(_quantityController.text) ?? 0;
      final pages = int.tryParse(_pagesController.text) ?? 0;
      return catalogTotal(
          serviceId: '${data['id']}',
          basePrice: base,
          quantity: qty,
          pages: pages,
          width: double.tryParse(_widthController.text) ?? 0,
          height: double.tryParse(_heightController.text) ?? 0,
          photoPrice:
              _photoSize.contains('12 x 18') || _photoSize.contains('250')
                  ? 250
                  : _photoSize.contains('550')
                      ? 550
                      : null);
    }
    int qty = int.tryParse(_quantityController.text) ?? 1;
    if (qty < 1) qty = 1;

    if (_serviceKind.contains('Standard A4 Print')) {
      int pages = int.tryParse(_pagesController.text) ?? 1;
      if (pages < 1) pages = 1;
      return pages * qty * 3.00;
    } else if (_serviceKind.contains('Business Cards')) {
      double basePrice = 250.0;
      if (_bcSides.contains('2-Side')) basePrice += 100.0;
      if (_bcFinish.contains('Soft Touch')) basePrice += 50.0;
      return (qty / 100).ceil() * basePrice;
    } else if (_serviceKind.contains('Tarpaulins')) {
      double w = double.tryParse(_widthController.text) ?? 3.0;
      double h = double.tryParse(_heightController.text) ?? 4.0;
      double sqft = w * h;
      double rate = _tarpThickness.contains('13 oz') ? 20.0 : 15.0;
      return sqft * rate * qty;
    } else if (_serviceKind.contains('Flyers')) {
      double base = _flyerSize.contains('A4') ? 3.50 : 2.50;
      if (_flyerSides.contains('2-Side')) base += 1.50;
      return base * qty;
    } else if (_serviceKind.contains('Stickers')) {
      double base = _stickerSize.contains('3x3') ? 8.00 : 5.00;
      if (_stickerMaterial.contains('Vinyl')) base += 2.00;
      return base * qty;
    } else if (_serviceKind.contains('Invitations')) {
      double base = 35.00;
      if (_invEnvelope.contains('With Matching')) base += 10.00;
      return base * qty;
    } else if (_serviceKind.contains('Shirt')) {
      double base = 180.00;
      if (_shirtLocation.contains('Front & Back')) base += 50.00;
      return base * qty;
    } else if (_serviceKind.contains('Photo')) {
      double base = 120.00;
      if (_photoSize.contains('12 x 18')) base = 250.00;
      if (_photoFrame.contains('Frame')) base += 150.00;
      return base * qty;
    } else if (_serviceKind.contains('Booklets')) {
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

        final validationErr =
            SupabaseStorageService.validateFile(pickedFile, pickedName);
        if (validationErr != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(validationErr),
                backgroundColor: const Color(0xFFF43F5E)),
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
        SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: const Color(0xFFF43F5E)),
      );
    }
  }

  void _removeSelectedFile() {
    setState(() {
      _selectedFileName = 'No file selected';
      _selectedFileSize = 0;
      _selectedFileObj = null;
    });
  }

  Future<void> _pickReceipt() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
      if (result == null || result.files.single.path == null) return;
      final selected = result.files.single;
      final file = File(selected.path!);
      final error = SupabaseStorageService.validateFile(file, selected.name);
      if (error != null) throw StateError(error);
      if (mounted)
        setState(() {
          _receiptFile = file;
          _receiptName = selected.name;
        });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;
    final noteText = _noteController.text.trim();
    final usesPages = ![
      'businessCards',
      'tarpaulins',
      'flyers',
      'stickers',
      'invitations',
      'shirt',
      'photoCanvas',
      'mug'
    ].contains(_serviceData?['id']);
    final validationError = _selectedFileObj == null
        ? 'Please upload your document or design file in Step 1 before submitting the order!'
        : SupabaseStorageService.validateFile(
                _selectedFileObj!, _selectedFileName) ??
            OrderValidation.validate(
              quantity: _quantityController.text,
              pages: _pagesController.text,
              usesPages: usesPages,
              isTarpaulin: _serviceKind.contains('Tarpaulins'),
              width: _widthController.text,
              height: _heightController.text,
              total: _calculatedTotal,
              paymentMethod: _paymentMethod,
              gcashReference: _gcashReferenceController.text,
              note: noteText,
            );
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(validationError),
            backgroundColor: const Color(0xFFF43F5E)),
      );
      return;
    }

    String? serviceError;
    if (!_catalogLoaded || _serviceData == null)
      serviceError =
          'Services are not available. Please reload the service list.';
    if (_paymentMethod == 'GCash Online' &&
        (_gcash['isActive'] == false ||
            (_gcash['accountNumber'] ?? '').toString().isEmpty))
      serviceError = 'GCash is unavailable. Please choose Cash on Pickup.';
    for (final req in _requirements) {
      final label = '${req['label'] ?? req['name'] ?? ''}';
      final value = _requirementValues[label];
      final text =
          value is List ? value.join(', ') : (value ?? '').toString().trim();
      if (req['required'] != false && text.isEmpty)
        serviceError = 'Please provide: $label';
      if (req['type'] == 'number' &&
          text.isNotEmpty &&
          (int.tryParse(text) == null ||
              int.parse(text) < 1 ||
              int.parse(text) > 100000))
        serviceError = '$label must be a whole number from 1 to 100,000.';
    }
    if (serviceError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serviceError), backgroundColor: Colors.red));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    try {
      // Restrict Admin from placing orders
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid ??
                widget.userEmail.trim().toLowerCase())
            .get();
        final role = userDoc.data()?['role']?.toString().toLowerCase();
        if (role == 'admin') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Only customer accounts can place orders. Please use POS for counter sales."),
              backgroundColor: Color(0xFFF43F5E),
            ),
          );
          return;
        }
      } catch (_) {}

      if (!mounted) return;
      final String customOrderRef = generateOrderReference();
      String submittedOrderRef = customOrderRef;
      final submissionId =
          FirebaseFirestore.instance.collection('orders').doc().id;
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
        'gcashReceiptUrl':
            _paymentMethod == 'GCash Online' && _receiptFile != null
                ? await SupabaseStorageService.uploadFile(
                    file: _receiptFile!,
                    originalFilename: _receiptName,
                    orderId: customOrderRef)
                : '',
        'id': customOrderRef,
        'submissionId': submissionId,
        'customerId':
            FirebaseAuth.instance.currentUser?.uid ?? widget.userEmail,
        'customer': widget.userEmail.split('@').first,
        'email': widget.userEmail,
        'service': _serviceData?['name'] ?? _selectedService,
        'serviceId': _serviceData?['id'],
        'serviceVersion': (_serviceData?['updatedAt'] ?? '').toString(),
        'merchantAccountNumber':
            _paymentMethod == 'GCash Online' ? _gcash['accountNumber'] : '',
        'customRequirements': Map<String, dynamic>.from(_requirementValues),
        'total': _calculatedTotal,
        'status': 'Order Submitted',
        'payment': _paymentMethod,
        'gcashRef': _paymentMethod == 'GCash Online'
            ? _gcashReferenceController.text.trim()
            : '',
        'file': _selectedFileName,
        'fileName': _selectedFileName,
        'fileUrl': fileDownloadUrl,
        'customerNote': noteText,
        'specialInstructions': noteText,
        'createdAt': FieldValue.serverTimestamp(),
        'quantity': int.parse(_quantityController.text.trim()),
        'copies': int.parse(_quantityController.text.trim()),
        'pages': usesPages ? int.parse(_pagesController.text.trim()) : 1,
        'details': {
          ..._requirementValues,
          if (_serviceKind.contains('Business Cards')) ...{
            'size': _bcSize,
            'paper': _bcPaper,
            'sides': _bcSides,
            'finish': _bcFinish,
            'corners': _bcCorners,
          },
          if (_serviceKind.contains('Tarpaulins')) ...{
            'dimensions':
                '${_widthController.text}ft x ${_heightController.text}ft',
            'thickness': _tarpThickness,
            'eyelets': _tarpEyelets,
            'finishing': _tarpFinishing,
          },
          if (_serviceKind.contains('Flyers')) ...{
            'size': _flyerSize,
            'paper': _flyerPaper,
            'sides': _flyerSides,
            'finish': _flyerFinish,
            'fold': _flyerFold,
          },
          if (_serviceKind.contains('Stickers')) ...{
            'size': _stickerSize,
            'shape': _stickerShape,
            'material': _stickerMaterial,
            'finish': _stickerFinish,
            'adhesive': _stickerAdhesive,
          },
          if (_serviceKind.contains('Invitations')) ...{
            'size': _invSize,
            'paper': _invPaper,
            'sides': _invSides,
            'finish': _invFinish,
            'envelope': _invEnvelope,
          },
          if (_serviceKind.contains('Shirt')) ...{
            'size': _shirtSize,
            'color': _shirtColor,
            'fabric': _shirtFabric,
            'method': _shirtMethod,
            'location': _shirtLocation,
          },
          if (_serviceKind.contains('Photo')) ...{
            'size': _photoSize,
            'material': _photoMaterial,
            'orientation': _photoOrientation,
            'finish': _photoFinish,
            'frame': _photoFrame,
          },
          if (_serviceKind.contains('Booklets')) ...{
            'size': _bookletSize,
            'pages': _pagesController.text,
            'paper': _bookletPaper,
            'cover': _bookletCover,
            'binding': _bookletBinding,
          },
        },
      };

      if (_pointsUsed > 0) {
        _loyaltyKey ??= LoyaltyApi.submissionId();
        final request = Map<String, dynamic>.from(orderPayload)..remove('createdAt');
        request['submissionId'] = _loyaltyKey;
        request['pointsUsed'] = _pointsUsed;
        request['expectedDiscount'] = _pointsDiscount;
        final saved = await LoyaltyApi.submitOrder(request);
        submittedOrderRef = saved['orderId'];
        _loyaltyKey = null;
      } else {
      try {
        final db = FirebaseFirestore.instance;
        final orderRef = db
            .collection('artifacts')
            .doc('printcraft-pro')
            .collection('public')
            .doc('data')
            .collection('orders')
            .doc(customOrderRef);
        await db.runTransaction((tx) async {
          final current = await tx
              .get(db.collection('services').doc(orderPayload['serviceId']));
          if (!current.exists ||
              current.data()?['archived'] == true ||
              (current.data()?['updatedAt'] ?? '').toString() !=
                  orderPayload['serviceVersion'])
            throw StateError(
                'The service changed. Reload the service list before ordering.');
          if (_paymentMethod == 'GCash Online') {
            final merchant =
                await tx.get(db.collection('settings').doc('gcash_config'));
            if (merchant.data()?['isActive'] == false ||
                merchant.data()?['accountNumber'] !=
                    orderPayload['merchantAccountNumber'])
              throw StateError(
                  'GCash details changed. Please check the current merchant details.');
          }
          if ((await tx.get(orderRef)).exists)
            throw StateError('Order reference already exists. Please retry.');
          tx.set(orderRef, orderPayload);
          addNewOrderNotification(tx, db, orderRef.id, orderPayload);
        });
      } on FirebaseException catch (firestoreErr) {
        if (!['unavailable', 'deadline-exceeded'].contains(firestoreErr.code))
          rethrow;
        await LocalDbService.instance
            .insertOrUpdateOrder(orderPayload, isSynced: false);
      }

      }
      if (!mounted) return;

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
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Order Submitted!',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tracking Ref: $submittedOrderRef',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF15803D))),
              const SizedBox(height: 6),
              const Text(
                  'Your order has been queued for shop approval. You will receive real-time notifications on production status.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF4B7A5E))),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white),
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
      _listenCatalog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error submitting order: $e'),
            backgroundColor: const Color(0xFFF43F5E)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FFF9),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFBBF7D0)),
        ),
        title: const Text('Place Print Order',
            style: TextStyle(
                color: Color(0xFF14532D),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF14532D)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _isSubmitting,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('STEP 1: UPLOAD DOCUMENT OR DESIGN'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.upload_file_rounded,
                        size: 40, color: Color(0xFF15803D)),
                    const SizedBox(height: 8),
                    if (_selectedFileObj != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _selectedFileName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A)),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFFF43F5E), size: 18),
                            tooltip: 'Remove file',
                            onPressed: _removeSelectedFile,
                          ),
                        ],
                      ),
                      Text(
                        'Size: ${(_selectedFileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold),
                      ),
                    ] else ...[
                      Text(_selectedFileName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF0F172A)),
                          textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Allowed: PDF, PNG, JPG, JPEG, DOC, DOCX (Max 10MB per file, up to 5 files / 25MB total)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF4B7A5E)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickDeviceFile,
                      icon: const Icon(Icons.folder_open_rounded,
                          size: 16, color: Colors.white),
                      label: Text(
                          _selectedFileObj != null
                              ? 'Change File'
                              : 'Choose File',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(
                  'STEP 2: SELECT SERVICE & CUSTOM SPECIFICATIONS'),
              const SizedBox(height: 8),
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
                    const Text('Printing Service Type',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4B7A5E))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedService),
                      dropdownColor: const Color(0xFFF0FDF4),
                      initialValue: _serviceOptions.contains(_selectedService)
                          ? _selectedService
                          : null,
                      isExpanded: true,
                      style: const TextStyle(
                          color: Color(0xFF14532D), fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF0FDF4),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFBBF7D0))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFF16A34A))),
                      ),
                      items: _serviceOptions
                          .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                  _catalog[s] == null
                                      ? s
                                      : '${_catalog[s]!['name']} (${_catalog[s]!['unit'] ?? ''})',
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null)
                          setState(() {
                            _selectedService = val;
                            _requirementValues.clear();
                          });
                      },
                    ),
                    const SizedBox(height: 14),
                    ..._buildDynamicServiceFields(),
                    ..._buildCustomRequirements(),
                    if (_catalogError != null)
                      TextButton(
                          onPressed: _listenCatalog,
                          child: const Text('Could not load services. Retry')),
                    if (_catalogLoaded && _serviceOptions.isEmpty)
                      const Text('No services currently available.',
                          style: TextStyle(color: Colors.red)),
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
                      onTap: () =>
                          setState(() => _paymentMethod = 'GCash Online'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _paymentMethod == 'GCash Online'
                              ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                              : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _paymentMethod == 'GCash Online'
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFBBF7D0),
                              width: 1.5),
                        ),
                        child: Row(
                          children: [
                            // ignore: deprecated_member_use
                            Radio<String>(
                              value: 'GCash Online',
                              // ignore: deprecated_member_use
                              groupValue: _paymentMethod,
                              activeColor: const Color(0xFF15803D),
                              // ignore: deprecated_member_use
                              onChanged: (val) =>
                                  setState(() => _paymentMethod = val!),
                            ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('GCash Online',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFF0F172A))),
                                  Text('Pay instantly',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF4B7A5E))),
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
                      onTap: () =>
                          setState(() => _paymentMethod = 'Cash on Pickup'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _paymentMethod == 'Cash on Pickup'
                              ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                              : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _paymentMethod == 'Cash on Pickup'
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFBBF7D0),
                              width: 1.5),
                        ),
                        child: Row(
                          children: [
                            // ignore: deprecated_member_use
                            Radio<String>(
                              value: 'Cash on Pickup',
                              // ignore: deprecated_member_use
                              groupValue: _paymentMethod,
                              activeColor: const Color(0xFF15803D),
                              // ignore: deprecated_member_use
                              onChanged: (val) =>
                                  setState(() => _paymentMethod = val!),
                            ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cash on Pickup',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFF0F172A))),
                                  Text('Pay at counter',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF4B7A5E))),
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
              if (_paymentMethod == 'GCash Online') ...[
                TextButton.icon(
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.receipt_outlined),
                    label: Text(_receiptFile == null
                        ? 'Attach GCash receipt (optional)'
                        : _receiptName)),
                if (_receiptFile != null)
                  TextButton(
                      onPressed: () => setState(() {
                            _receiptFile = null;
                            _receiptName = '';
                          }),
                      child: const Text('Remove receipt')),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(children: [
                    Text(
                        '${_gcash['accountName'] ?? 'GCash'} · ${_gcash['accountNumber'] ?? 'Merchant details unavailable'}',
                        style: const TextStyle(color: Color(0xFF14532D))),
                    sharedImage(gcashQrSource(_gcash), height: 150),
                    TextField(
                      controller: _gcashReferenceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 16,
                      style: const TextStyle(
                          color: Color(0xFF14532D), fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'GCash Reference Number',
                        helperText:
                            '8–16 digits, usually 13, from your GCash receipt',
                        helperMaxLines: 2,
                        filled: true,
                        fillColor: const Color(0xFFF0FDF4),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFBBF7D0))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFF16A34A))),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
              ],
              _buildSectionHeader(
                  'STEP 4: SPECIAL INSTRUCTIONS / ORDER NOTE (OPTIONAL)'),
              const SizedBox(height: 8),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Order Note (Optional)',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4B7A5E)),
                        ),
                        Text(
                          '${_noteController.text.length}/$_maxNoteLength',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _noteController.text.length > _maxNoteLength
                                ? const Color(0xFFF43F5E)
                                : const Color(0xFF4B7A5E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noteController,
                      maxLines: 4,
                      maxLength: _maxNoteLength,
                      style: const TextStyle(
                          color: Color(0xFF14532D), fontSize: 13),
                      onChanged: (_) => setState(() {}),
                      buildCounter: (context,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          null,
                      decoration: InputDecoration(
                        hintText:
                            'Write any special instructions for your order...\n(e.g., orientation, paper preference, urgent timing)',
                        hintStyle: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF4B7A5E),
                            height: 1.4),
                        filled: true,
                        fillColor: const Color(0xFFF0FDF4),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFBBF7D0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF16A34A)),
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
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL SUMMARY',
                        style: TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    const Text('Subtotal:',
                        style:
                            TextStyle(color: Color(0xFF4B7A5E), fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      '₱${_calculatedTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w900,
                          fontSize: 28),
                    ),
                    PointsSelector(subtotal: _calculatedTotal, onChanged: (value) => setState(() => _pointsUsed = value), onDiscountChanged: (value) => setState(() => _pointsDiscount = value)),
                    const Divider(color: Color(0xFFBBF7D0), height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment:',
                            style: TextStyle(
                                color: Color(0xFF4B7A5E), fontSize: 11)),
                        Text(_paymentMethod,
                            style: const TextStyle(
                                color: Color(0xFF14532D),
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimated Pickup:',
                            style: TextStyle(
                                color: Color(0xFF4B7A5E), fontSize: 11)),
                        Text('Tomorrow 4:00 PM',
                            style: TextStyle(
                                color: Color(0xFF14532D),
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitOrder,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF14532D), strokeWidth: 2))
                            : const Icon(Icons.arrow_forward_rounded,
                                size: 16, color: Colors.white),
                        label: Text(
                            _isSubmitting
                                ? 'Uploading & Submitting...'
                                : 'Confirm & Submit Order →',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDynamicServiceFields() {
    if (_serviceKind.contains('Business Cards')) {
      return [
        _buildRowTwoFields(
          _buildTextField('Quantity (pcs)', _quantityController),
          _buildDropdownField(
              'Size',
              _bcSize,
              ['Standard (3.5 x 2 in)', 'Square (2.5 x 2.5 in)'],
              (v) => setState(() => _bcSize = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Paper Type & Thickness',
              _bcPaper,
              ['300 GSM Matte Cardstock', '350 GSM Glossy Cardstock'],
              (v) => setState(() => _bcPaper = v!)),
          _buildDropdownField(
              'Printing Sides',
              _bcSides,
              ['1-Side Printing', '2-Side Printing'],
              (v) => setState(() => _bcSides = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Finish',
              _bcFinish,
              ['Matte Finish', 'Glossy Finish', 'Soft Touch'],
              (v) => setState(() => _bcFinish = v!)),
          _buildDropdownField(
              'Corners',
              _bcCorners,
              ['Square Corners', 'Rounded Corners'],
              (v) => setState(() => _bcCorners = v!)),
        ),
      ];
    } else if (_serviceKind.contains('Tarpaulins')) {
      return [
        _buildRowTwoFields(
          _buildTextField('Width (ft)', _widthController),
          _buildTextField('Height (ft)', _heightController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildTextField('Quantity (pcs)', _quantityController),
          _buildDropdownField(
              'Material Thickness',
              _tarpThickness,
              ['10 oz Standard Tarpaulin', '13 oz Premium Heavy Duty'],
              (v) => setState(() => _tarpThickness = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Eyelets / Rings',
              _tarpEyelets,
              [
                'With Eyelets (4 Corners)',
                'With Eyelets (Every 2ft)',
                'No Eyelets'
              ],
              (v) => setState(() => _tarpEyelets = v!)),
          _buildDropdownField(
              'Finishing',
              _tarpFinishing,
              ['Folded Edge (Kaibe)', 'Cut to Size'],
              (v) => setState(() => _tarpFinishing = v!)),
        ),
      ];
    } else if (_serviceKind.contains('Flyers')) {
      return [
        _buildRowTwoFields(
          _buildDropdownField(
              'Size',
              _flyerSize,
              ['A4 Size', 'A5 Size', 'DL Size'],
              (v) => setState(() => _flyerSize = v!)),
          _buildTextField('Quantity (pcs)', _quantityController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Paper Type & Thickness',
              _flyerPaper,
              ['80 GSM Bond Paper', '115 GSM Glossy Paper'],
              (v) => setState(() => _flyerPaper = v!)),
          _buildDropdownField(
              'Printing Sides',
              _flyerSides,
              ['1-Side Printing', '2-Side Printing'],
              (v) => setState(() => _flyerSides = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Finish',
              _flyerFinish,
              ['Glossy Finish', 'Matte Finish'],
              (v) => setState(() => _flyerFinish = v!)),
          _buildDropdownField(
              'Folding Option',
              _flyerFold,
              ['No Fold (Flat)', 'Bi-Fold', 'Tri-Fold'],
              (v) => setState(() => _flyerFold = v!)),
        ),
      ];
    } else if (_serviceKind.contains('Stickers')) {
      return [
        _buildRowTwoFields(
          _buildDropdownField(
              'Size / Dimensions',
              _stickerSize,
              ['2x2 inches', '3x3 inches', 'A4 Sheet'],
              (v) => setState(() => _stickerSize = v!)),
          _buildTextField('Quantity (pcs)', _quantityController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Shape / Die-cut',
              _stickerShape,
              ['Die-Cut (Custom Shape)', 'Circle', 'Square', 'Rectangle'],
              (v) => setState(() => _stickerShape = v!)),
          _buildDropdownField(
              'Material',
              _stickerMaterial,
              [
                'Vinyl Sticker (Waterproof)',
                'Transparent Sticker',
                'Paper Sticker'
              ],
              (v) => setState(() => _stickerMaterial = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Finish',
              _stickerFinish,
              ['Glossy Laminated', 'Matte Laminated', '3D Holographic'],
              (v) => setState(() => _stickerFinish = v!)),
          _buildDropdownField(
              'Adhesive Type',
              _stickerAdhesive,
              ['Permanent Strong Adhesive', 'Removable Adhesive'],
              (v) => setState(() => _stickerAdhesive = v!)),
        ),
      ];
    } else if (_serviceKind.contains('Invitations')) {
      return [
        _buildRowTwoFields(
          _buildTextField('Quantity (pcs)', _quantityController),
          _buildDropdownField(
              'Card Size',
              _invSize,
              ['5 x 7 inches (Standard)', '4 x 6 inches'],
              (v) => setState(() => _invSize = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Paper Type & Thickness',
              _invPaper,
              ['250 GSM Linen Cardstock', '300 GSM Matte Cardstock'],
              (v) => setState(() => _invPaper = v!)),
          _buildDropdownField(
              'Printing Sides',
              _invSides,
              ['Front & Back Printing', 'Front Only'],
              (v) => setState(() => _invSides = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Finish & Folding',
              _invFinish,
              ['Flat Card', 'Folded Card'],
              (v) => setState(() => _invFinish = v!)),
          _buildDropdownField(
              'Envelope Included',
              _invEnvelope,
              ['With Matching Envelope', 'Without Envelope'],
              (v) => setState(() => _invEnvelope = v!)),
        ),
      ];
    } else if (_serviceKind.contains('Shirt')) {
      return [
        _buildRowTwoFields(
          _buildDropdownField(
              'Shirt Size',
              _shirtSize,
              ['Small (S)', 'Medium (M)', 'Large (L)', 'XL', '2XL'],
              (v) => setState(() => _shirtSize = v!)),
          _buildTextField('Quantity (pcs)', _quantityController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Shirt Color',
              _shirtColor,
              ['Black', 'White', 'Navy Blue', 'Red'],
              (v) => setState(() => _shirtColor = v!)),
          _buildDropdownField(
              'Shirt Type / Fabric',
              _shirtFabric,
              ['Cotton Blend 200 GSM', '100% Organic Cotton'],
              (v) => setState(() => _shirtFabric = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Printing Method',
              _shirtMethod,
              ['DTF (Direct to Film)', 'Sublimation Printing'],
              (v) => setState(() => _shirtMethod = v!)),
          _buildDropdownField(
              'Print Location',
              _shirtLocation,
              ['Front Chest (Standard)', 'Back Center', 'Front & Back'],
              (v) => setState(() => _shirtLocation = v!)),
        ),
      ];
    } else if (_serviceKind.contains('Photo')) {
      return [
        _buildRowTwoFields(
          _buildDropdownField(
              'Size / Dimensions',
              _photoSize,
              ['8 x 10 inches (₱120)', 'A4 Photo', '12 x 18 inches'],
              (v) => setState(() => _photoSize = v!)),
          _buildTextField('Quantity (pcs)', _quantityController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Material',
              _photoMaterial,
              ['Glossy Photo Paper', 'Satin Photo Paper', 'Canvas Fabric'],
              (v) => setState(() => _photoMaterial = v!)),
          _buildDropdownField(
              'Orientation',
              _photoOrientation,
              ['Portrait', 'Landscape'],
              (v) => setState(() => _photoOrientation = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Finish',
              _photoFinish,
              ['Gloss Lamination', 'Matte Lamination'],
              (v) => setState(() => _photoFinish = v!)),
          _buildDropdownField(
              'Frame Option',
              _photoFrame,
              ['Without Frame', 'With Black Frame', 'With Wooden Frame'],
              (v) => setState(() => _photoFrame = v!)),
        ),
      ];
    } else if (_serviceKind.contains('Booklets')) {
      return [
        _buildRowTwoFields(
          _buildDropdownField(
              'Size',
              _bookletSize,
              ['A4 Size Booklet', 'A5 Size Booklet'],
              (v) => setState(() => _bookletSize = v!)),
          _buildTextField('Quantity (pcs)', _quantityController),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildTextField('Number of Pages', _pagesController),
          _buildDropdownField(
              'Paper Type (Inner Pages)',
              _bookletPaper,
              ['80 GSM Bond Paper', '100 GSM Glossy Paper'],
              (v) => setState(() => _bookletPaper = v!)),
        ),
        const SizedBox(height: 12),
        _buildRowTwoFields(
          _buildDropdownField(
              'Cover Type & Thickness',
              _bookletCover,
              ['200 GSM Glossy Card Cover', '250 GSM Matte Cover'],
              (v) => setState(() => _bookletCover = v!)),
          _buildDropdownField(
              'Printing Sides & Binding',
              _bookletBinding,
              ['Saddle Stitch (Wire Staple)', 'Perfect Binding'],
              (v) => setState(() => _bookletBinding = v!)),
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

  List<Widget> _buildCustomRequirements() {
    return _requirements.asMap().entries.map((entry) {
      final req = entry.value;
      final label =
          '${req['label'] ?? req['name'] ?? 'Requirement ${entry.key + 1}'}';
      final raw = req['options'];
      final options = (raw is List
              ? raw.map((o) => o.toString())
              : raw.toString().split(RegExp(r'[,/]')))
          .where((o) => o.trim().isNotEmpty && o != 'null')
          .map((o) => o.trim())
          .toSet()
          .toList();
      final type = req['type'];
      Widget input;
      if (type == 'select' || type == 'radio') {
        input = DropdownButtonFormField<String>(
          key: ValueKey('$_selectedService-$label'),
          initialValue: _requirementValues[label] as String?,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
              labelText: '$label${req['required'] != false ? ' *' : ''}',
              border: const OutlineInputBorder()),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _requirementValues[label] = v),
        );
      } else if (type == 'checkboxes') {
        final selected =
            List<String>.from(_requirementValues[label] as List? ?? []);
        input = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$label${req['required'] != false ? ' *' : ''}',
              style: const TextStyle(color: Colors.black87)),
          ...options.map((o) => CheckboxListTile(
              title: Text(o, style: const TextStyle(color: Colors.black87)),
              value: selected.contains(o),
              onChanged: (v) => setState(() {
                    if (v == true) {
                      selected.add(o);
                    } else {
                      selected.remove(o);
                    }
                    _requirementValues[label] = selected;
                  }))),
        ]);
      } else {
        final numeric = type == 'number';
        input = TextFormField(
          key: ValueKey('$_selectedService-$label'),
          style: const TextStyle(color: Colors.black87),
          maxLength: numeric ? 6 : 150,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          inputFormatters:
              numeric ? [OrderNumberInputFormatter(maximum: 100000)] : [],
          decoration: InputDecoration(
              labelText: '$label${req['required'] != false ? ' *' : ''}',
              border: const OutlineInputBorder()),
          onChanged: (v) => _requirementValues[label] = v,
        );
      }
      return Padding(padding: const EdgeInsets.only(top: 12), child: input);
    }).toList();
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
    final isDimension =
        controller == _widthController || controller == _heightController;
    final maximum = isDimension
        ? 100
        : controller == _pagesController
            ? 5000
            : 100000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4B7A5E))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: isDimension),
          inputFormatters: [
            OrderNumberInputFormatter(
                maximum: maximum, allowDecimals: isDimension),
          ],
          style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            helperText:
                isDimension ? 'Max 100 ft · 2 decimal places' : 'Max $maximum',
            helperMaxLines: 2,
            filled: true,
            fillColor: const Color(0xFFF0FDF4),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF16A34A))),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4B7A5E))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          dropdownColor: const Color(0xFFF0FDF4),
          initialValue: items.contains(value) ? value : items.first,
          isExpanded: true,
          style: const TextStyle(color: Color(0xFF14532D), fontSize: 11),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF0FDF4),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF16A34A))),
          ),
          items: items
              .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF15803D),
            letterSpacing: 1.1));
  }
}
