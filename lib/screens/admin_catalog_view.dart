import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../services/admin_repository.dart';
import '../services/supabase_storage_service.dart';

Widget sharedImage(String url,
    {double height = 100, BoxFit fit = BoxFit.contain}) {
  Widget missing() => SizedBox(
      height: height,
      child:
          const Center(child: Icon(Icons.image_outlined, color: Colors.green)));
  try {
    if (url.startsWith('data:image/'))
      return Image.memory(base64Decode(url.split(',').last),
          height: height, fit: fit, errorBuilder: (_, __, ___) => missing());
    if (url.startsWith('/')) {
      const host = String.fromEnvironment('WEBSITE_BASE_URL');
      if (host.isEmpty) return missing();
      url = Uri.parse(host).resolve(url).toString();
    }
    if (!url.startsWith('https://') && !url.startsWith('http://'))
      return missing();
    return Image.network(url,
        height: height, fit: fit, errorBuilder: (_, __, ___) => missing());
  } catch (_) {
    return missing();
  }
}

class AdminCatalogView extends StatefulWidget {
  final bool services;
  const AdminCatalogView({super.key, required this.services});
  @override
  State<AdminCatalogView> createState() => _AdminCatalogViewState();
}

class _AdminCatalogViewState extends State<AdminCatalogView> {
  String _search = '';
  String get collection => widget.services ? 'services' : 'sample_products';
  void message(Object error) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> edit([DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => AdminCatalogEditor(
            services: widget.services,
            id: doc?.id,
            initial: doc?.data() ?? {}));
    if (saved == true) message('Saved. Changes are shared with the website.');
  }

  Future<void> archive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Move to Archive?'),
              content: const Text('This item can be restored from Archive.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Archive'))
              ],
            ));
    if (confirmed != true) return;
    try {
      await AdminRepository().archive(
          widget.services ? 'service' : 'sample_product', doc.id, doc.data()!);
      message('Moved to Archive.');
    } catch (e) {
      message(e);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: Text(
                        widget.services
                            ? 'Printing Services Manager'
                            : 'Samples & Services',
                        style: const TextStyle(
                            color: Color(0xFF14532D),
                            fontWeight: FontWeight.bold))),
                FilledButton.icon(
                    onPressed: () => edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'))
              ]),
              TextField(
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search name or category'),
                  onChanged: (v) => setState(() => _search = v.toLowerCase())),
            ])),
        Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection(collection).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                  child: Text('Unable to load: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red)));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs
                .where((d) =>
                    d.data()['archived'] != true &&
                    '${d.data()['name'] ?? d.data()['title']} ${d.data()['category'] ?? ''}'
                        .toLowerCase()
                        .contains(_search))
                .toList();
            docs.sort((a, b) => ((a.data()['sortOrder'] as num?) ?? 0)
                .compareTo((b.data()['sortOrder'] as num?) ?? 0));
            if (docs.isEmpty)
              return const Center(
                  child: Text('No matching items.',
                      style: TextStyle(color: Colors.black87)));
            return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                itemCount: docs.length,
                itemBuilder: (_, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  return Card(
                      color: Colors.white,
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!widget.services)
                                  Center(
                                      child: sharedImage(
                                          '${data['imageUrl'] ?? ''}')),
                                Text(
                                    '${data['emoji'] ?? ''} ${data['name'] ?? data['title'] ?? doc.id}',
                                    style: const TextStyle(
                                        color: Color(0xFF14532D),
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    widget.services
                                        ? '${doc.id} · ₱${data['basePrice'] ?? 0} · ${data['unit'] ?? ''}\nOrder: ${data['sortOrder'] ?? 0} · ${(data['requirements'] as List? ?? []).length} requirements'
                                        : '${data['category'] ?? ''} · ${data['price'] ?? ''}\n${data['badge'] ?? ''}\n${data['description'] ?? ''}',
                                    style:
                                        const TextStyle(color: Colors.black87)),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                          onPressed: () => edit(doc),
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Edit')),
                                      TextButton.icon(
                                          onPressed: () => archive(doc),
                                          icon: const Icon(
                                              Icons.archive_outlined),
                                          label: const Text('Archive'))
                                    ]),
                              ])));
                });
          },
        )),
      ]);
}

class AdminCatalogEditor extends StatefulWidget {
  final bool services;
  final String? id;
  final Map<String, dynamic> initial;
  const AdminCatalogEditor(
      {required this.services, required this.id, required this.initial});
  @override
  State<AdminCatalogEditor> createState() => AdminCatalogEditorState();
}

class AdminCatalogEditorState extends State<AdminCatalogEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final requirements = <Map<String, dynamic>>[];
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    for (final key in [
      'id',
      'name',
      'emoji',
      'basePrice',
      'unit',
      'sortOrder',
      'title',
      'category',
      'serviceVal',
      'price',
      'badge',
      'imageUrl',
      'description'
    ]) {
      fields[key] = TextEditingController(
          text: (key == 'id'
                  ? widget.id ?? ''
                  : widget.initial[key] ?? (key == 'sortOrder' ? 1 : ''))
              .toString());
    }
    for (final r in (widget.initial['requirements'] as List? ?? [])) {
      final row = Map<String, dynamic>.from(r as Map);
      final options = row['options'];
      requirements.add({
        'label': row['label'] ?? '',
        'type': row['type'] ?? 'text',
        'required': row['required'] != false,
        'options':
            options is List ? options.join('\n') : (options ?? '').toString()
      });
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String key, String label,
          {bool required = false, bool numeric = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: fields[key],
            maxLength: key == 'description' ? 2000 : 500,
            maxLines: lines,
            readOnly: key == 'id' && widget.id != null,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
                labelText: label,
                counterText: '',
                border: const OutlineInputBorder()),
            validator: (v) {
              final value = v!.trim();
              if (required && value.isEmpty) return 'Required';
              if (key == 'id' && (value.contains('/') || value.length > 100))
                return 'Use a key without / (max 100 characters)';
              if (numeric) {
                final n = double.tryParse(value);
                if (n == null ||
                    !n.isFinite ||
                    n < 0 ||
                    n > (key == 'basePrice' ? 5000000 : 100000))
                  return 'Enter a valid non-negative number';
                if (key == 'sortOrder' && int.tryParse(value) == null)
                  return 'Whole number only';
              }
              return null;
            },
          ));
  Future<void> upload() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selected = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
      if (selected != null && selected.files.single.path != null) {
        final f = selected.files.single;
        fields['imageUrl']!.text = await SupabaseStorageService.uploadFile(
            file: File(f.path!), originalFilename: f.name);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final rows = <Map<String, dynamic>>[];
    for (final row in requirements) {
      final label = row['label'].toString().trim();
      final options = row['options']
          .toString()
          .split(RegExp(r'[\n,]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (label.isEmpty ||
          (['select', 'radio', 'checkboxes'].contains(row['type']) &&
              options.isEmpty) ||
          rows.any((r) => r['label'] == label)) {
        setState(() => error =
            'Each requirement needs a unique label and choices for select/radio/checkboxes.');
        return;
      }
      rows.add({...row, 'label': label, 'options': options});
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final collection = FirebaseFirestore.instance
          .collection(widget.services ? 'services' : 'sample_products');
      final id = widget.id ??
          (widget.services ? fields['id']!.text.trim() : collection.doc().id);
      final data = <String, dynamic>{
        'id': id,
        'archived': false,
        'isArchived': false,
        'updatedAt': DateTime.now().toUtc().toIso8601String()
      };
      for (final key in widget.services
          ? ['name', 'emoji', 'unit']
          : [
              'title',
              'category',
              'serviceVal',
              'price',
              'badge',
              'imageUrl',
              'description'
            ]) {
        data[key] = fields[key]!.text.trim();
      }
      if (widget.services) {
        data.addAll({
          'basePrice': double.parse(fields['basePrice']!.text),
          'sortOrder': int.parse(fields['sortOrder']!.text),
          'requirements': rows
        });
      }
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final existing = await tx.get(collection.doc(id));
        if (widget.id == null && existing.exists)
          throw StateError('This ID already exists. Choose another key.');
        if (widget.id != null &&
            (!existing.exists || existing.data()?['archived'] == true))
          throw StateError('Item is missing or archived.');
        tx.set(collection.doc(id), data, SetOptions(merge: true));
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AlertDialog(
        backgroundColor: const Color(0xFFF8FFF9),
        title: Text(
            '${widget.id == null ? 'Add' : 'Edit'} ${widget.services ? 'service' : 'sample'}',
            style: const TextStyle(color: Color(0xFF14532D))),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: AbsorbPointer(
                    absorbing: busy,
                    child: Form(
                        key: form,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          if (widget.services) ...[
                            field('id', 'Value key / ID', required: true),
                            field('name', 'Service name', required: true),
                            field('emoji', 'Emoji'),
                            field('basePrice', 'Base price',
                                required: true, numeric: true),
                            field('unit', 'Unit label', required: true),
                            field('sortOrder', 'Display order',
                                required: true, numeric: true),
                            ...requirements.asMap().entries.map((entry) {
                              final row = entry.value;
                              return Card(
                                  key: ObjectKey(row),
                                  color: Colors.white,
                                  child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(children: [
                                        TextFormField(
                                            initialValue: row['label'],
                                            maxLength: 150,
                                            style: const TextStyle(
                                                color: Colors.black87),
                                            decoration: const InputDecoration(
                                                labelText: 'Requirement label'),
                                            onChanged: (v) => row['label'] = v),
                                        DropdownButtonFormField<String>(
                                            initialValue: [
                                              'text',
                                              'number',
                                              'select',
                                              'radio',
                                              'checkboxes'
                                            ].contains(row['type'])
                                                ? row['type']
                                                : 'text',
                                            dropdownColor: Colors.white,
                                            style: const TextStyle(
                                                color: Colors.black87),
                                            items: [
                                              'text',
                                              'number',
                                              'select',
                                              'radio',
                                              'checkboxes'
                                            ]
                                                .map((v) => DropdownMenuItem(
                                                    value: v, child: Text(v)))
                                                .toList(),
                                            onChanged: (v) => setState(
                                                () => row['type'] = v)),
                                        SwitchListTile(
                                            title: const Text('Required',
                                                style: TextStyle(
                                                    color: Colors.black87)),
                                            value: row['required'] == true,
                                            onChanged: (v) => setState(
                                                () => row['required'] = v)),
                                        if (['select', 'radio', 'checkboxes']
                                            .contains(row['type']))
                                          TextFormField(
                                              initialValue: row['options'],
                                              maxLines: 3,
                                              maxLength: 2000,
                                              style: const TextStyle(
                                                  color: Colors.black87),
                                              decoration: const InputDecoration(
                                                  labelText:
                                                      'Choices (one per line)'),
                                              onChanged: (v) =>
                                                  row['options'] = v),
                                        TextButton.icon(
                                            onPressed: () => setState(() =>
                                                requirements
                                                    .removeAt(entry.key)),
                                            icon:
                                                const Icon(Icons.remove_circle),
                                            label: const Text(
                                                'Remove requirement')),
                                      ])));
                            }),
                            TextButton.icon(
                                onPressed: () => setState(() => requirements
                                        .add({
                                      'label': '',
                                      'type': 'text',
                                      'required': true,
                                      'options': ''
                                    })),
                                icon: const Icon(Icons.add),
                                label: const Text('Add requirement')),
                          ] else ...[
                            field('title', 'Title', required: true),
                            field('category', 'Category', required: true),
                            field('serviceVal', 'Service value key',
                                required: true),
                            field('price', 'Price label', required: true),
                            field('badge', 'Badge'),
                            field('imageUrl', 'Image URL'),
                            TextButton.icon(
                                onPressed: upload,
                                icon: const Icon(Icons.upload),
                                label: const Text('Upload image')),
                            field('description', 'Description', lines: 3),
                          ],
                          if (error != null)
                            Text(error!,
                                style: const TextStyle(color: Colors.red)),
                        ]))))),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving...' : 'Save'))
        ],
      ));
}

class AdminGcashView extends StatefulWidget {
  const AdminGcashView({super.key});
  @override
  State<AdminGcashView> createState() => _AdminGcashViewState();
}

class _AdminGcashViewState extends State<AdminGcashView> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      number = TextEditingController(),
      qr = TextEditingController();
  bool busy = false, loaded = false, active = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = (await FirebaseFirestore.instance
                  .collection('settings')
                  .doc('gcash_config')
                  .get())
              .data() ??
          {};
      if (!mounted) return;
      name.text = '${data['accountName'] ?? ''}';
      number.text = '${data['accountNumber'] ?? ''}';
      qr.text = '${data['qrUrl'] ?? ''}';
      setState(() {
        active = data['isActive'] != false;
        loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  void dispose() {
    name.dispose();
    number.dispose();
    qr.dispose();
    super.dispose();
  }

  Future<void> upload() async {
    setState(() => busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png']);
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        qr.text = await SupabaseStorageService.uploadFile(
            file: File(file.path!), originalFilename: file.name);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('gcash_config')
          .set({
        'accountName': name.text.trim(),
        'accountNumber': number.text.trim(),
        'qrUrl': qr.text.trim(),
        'isActive': active,
        'updatedAt': DateTime.now().toUtc().toIso8601String()
      }, SetOptions(merge: true));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('GCash settings saved for web and mobile.')));
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded)
      return Center(
          child: error == null
              ? const CircularProgressIndicator()
              : TextButton(onPressed: load, child: Text('Retry: $error')));
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Form(
              key: form,
              child: Column(children: [
                const Text('GCash Merchant Settings',
                    style: TextStyle(
                        color: Color(0xFF14532D),
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                TextFormField(
                    controller: name,
                    maxLength: 150,
                    style: const TextStyle(color: Colors.black87),
                    decoration:
                        const InputDecoration(labelText: 'Account name'),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                TextFormField(
                    controller: number,
                    maxLength: 11,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.black87),
                    decoration:
                        const InputDecoration(labelText: 'GCash mobile number'),
                    validator: (v) => RegExp(r'^09[0-9]{9}$').hasMatch(v!)
                        ? null
                        : 'Use an 11-digit number starting with 09'),
                TextFormField(
                    controller: qr,
                    maxLength: 2000,
                    style: const TextStyle(color: Colors.black87),
                    decoration:
                        const InputDecoration(labelText: 'QR image URL'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v!.isNotEmpty &&
                            !(v.startsWith('https://') ||
                                v.startsWith('http://') ||
                                v.startsWith('/'))
                        ? 'Use an image URL or upload a QR image'
                        : null),
                sharedImage(qr.text, height: 180),
                TextButton.icon(
                    onPressed: busy ? null : upload,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload QR image')),
                SwitchListTile(
                    title: const Text('Accept GCash payments',
                        style: TextStyle(color: Colors.black87)),
                    value: active,
                    onChanged: busy ? null : (v) => setState(() => active = v)),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? 'Saving...' : 'Save settings')),
              ]))
        ]);
  }
}
