import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/document_contrast_service.dart';
import '../utils/image_export.dart';

class DocumentContrastScreen extends StatefulWidget {
  const DocumentContrastScreen({super.key});
  @override
  State<DocumentContrastScreen> createState() => _DocumentContrastScreenState();
}

class _DocumentContrastScreenState extends State<DocumentContrastScreen> {
  final _service = DocumentContrastService();
  DocumentContrastMode _mode = DocumentContrastMode.balanced;
  Uint8List? _original;
  Uint8List? _result;
  String _name = 'document';
  String? _error;
  bool _processing = false;

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true);
    final file = picked?.files.single;
    if (file?.bytes == null || file!.size == 0) return;
    setState(() {
      _original = file.bytes;
      _result = null;
      _name = file.name;
      _error = null;
    });
  }

  Future<void> _process() async {
    if (_original == null) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final result = await _service.process(_original!, mode: _mode);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Document contrast မလုပ်နိုင်ပါ: $error');
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan Document သန့်မယ်')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              'စာရွက်အလင်းမညီမှုကို browser ထဲတွင်သာ local processing ဖြင့် ညှိပေးပါသည်။',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                    onPressed: _processing ? null : _pick,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Document ရွေးရန်')),
                DropdownButton<DocumentContrastMode>(
                    value: _mode,
                    items: DocumentContrastMode.values
                        .map((v) => DropdownMenuItem(
                            value: v, child: Text(v.name.toUpperCase())))
                        .toList(),
                    onChanged:
                        _processing ? null : (v) => setState(() => _mode = v!)),
                FilledButton.icon(
                    onPressed:
                        _original == null || _processing ? null : _process,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('သန့်စင်ရန်')),
                if (_result != null)
                  OutlinedButton.icon(
                      onPressed: () => downloadBytes(
                          _result!,
                          '${_name.replaceFirst(RegExp(r'\.[^.]+$'), '')}_contrast.jpg',
                          'image/jpeg'),
                      icon: const Icon(Icons.download),
                      label: const Text('Download')),
              ]),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_processing)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator())),
          if (_original != null) ...[
            const SizedBox(height: 24),
            const Text('Before / After',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            LayoutBuilder(
                builder: (context, constraints) =>
                    Wrap(spacing: 16, runSpacing: 16, children: [
                      _preview('Original', _original!),
                      if (_result != null)
                        _preview('Contrast result', _result!),
                    ])),
          ],
        ])),
      );

  Widget _preview(String label, Uint8List bytes) => SizedBox(
      width: 390,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label),
        const SizedBox(height: 6),
        Image.memory(bytes, fit: BoxFit.contain)
      ]));
}
