import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/local_ocr_service.dart';
import '../utils/image_export.dart';

class ImageToTextScreen extends StatefulWidget {
  const ImageToTextScreen({super.key});

  @override
  State<ImageToTextScreen> createState() => _ImageToTextScreenState();
}

class _ImageToTextScreenState extends State<ImageToTextScreen> {
  final _ocr = LocalOcrService();
  final _text = TextEditingController();
  Uint8List? _image;
  String _name = '';
  String _languages = 'mya+eng';
  String _status = '';
  String? _error;
  double _progress = 0;
  double? _confidence;
  bool _running = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = selected?.files.single;
    if (file?.bytes == null || file!.size == 0) return;
    if (file.size > 20 * 1024 * 1024) {
      setState(() => _error = 'ပုံဖိုင်အရွယ်အစား 20 MB ထက် မကျော်ရပါ။');
      return;
    }
    setState(() {
      _image = file.bytes;
      _name = file.name;
      _text.clear();
      _status = '';
      _progress = 0;
      _confidence = null;
      _error = null;
    });
  }

  Future<void> _recognize() async {
    if (_image == null || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _progress = 0;
      _status = 'Starting local OCR…';
    });
    try {
      final result = await _ocr.recognize(
        _image!,
        languages: _languages,
        onProgress: (update) {
          if (!mounted) return;
          setState(() {
            _status = update.status;
            _progress = update.value.clamp(0.0, 1.0);
          });
        },
      );
      if (mounted) {
        setState(() {
          _text.text = result.text.trim();
          _confidence = result.confidence;
          _progress = 1;
          _status = 'Complete';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'OCR မလုပ်နိုင်ပါ: $error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text ကို copy လုပ်ပြီးပါပြီ။')));
    }
  }

  void _download() {
    final base = _name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    downloadBytes(Uint8List.fromList(_text.text.codeUnits), '$base.txt',
        'text/plain;charset=utf-8');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Image to Text')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 820;
                  final input = _InputPanel(
                    image: _image,
                    name: _name,
                    languages: _languages,
                    fillHeight: desktop,
                    running: _running,
                    progress: _progress,
                    status: _status,
                    onPick: _pick,
                    onLanguage: (value) => setState(() => _languages = value),
                    onRecognize: _recognize,
                  );
                  final output = _OutputPanel(
                    controller: _text,
                    confidence: _confidence,
                    fillHeight: desktop,
                    enabled: _text.text.isNotEmpty,
                    onCopy: _copy,
                    onDownload: _download,
                  );
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Image to Text',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text(
                            'OCR ကို browser Web Worker ထဲတွင် လုပ်ဆောင်ပါသည်။ ပုံကို app server သို့ upload မလုပ်ပါ။'),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          MaterialBanner(content: Text(_error!), actions: [
                            TextButton(
                                onPressed: () => setState(() => _error = null),
                                child: const Text('ပိတ်ရန်'))
                          ]),
                        ],
                        const SizedBox(height: 18),
                        Expanded(
                            child: desktop
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                        Expanded(child: input),
                                        const SizedBox(width: 18),
                                        Expanded(child: output)
                                      ])
                                : ListView(children: [
                                    input,
                                    const SizedBox(height: 16),
                                    output
                                  ])),
                      ]);
                }),
              ),
            ),
          ),
        ),
      );
}

class _InputPanel extends StatelessWidget {
  const _InputPanel(
      {required this.image,
      required this.name,
      required this.languages,
      required this.fillHeight,
      required this.running,
      required this.progress,
      required this.status,
      required this.onPick,
      required this.onLanguage,
      required this.onRecognize});
  final Uint8List? image;
  final String name, languages, status;
  final bool fillHeight, running;
  final double progress;
  final VoidCallback onPick, onRecognize;
  final ValueChanged<String> onLanguage;

  Widget _preview() => Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: const Color(0xffEEF2F8),
          borderRadius: BorderRadius.circular(12)),
      child: image == null
          ? const Center(child: Text('JPG / PNG / WEBP ပုံကိုရွေးပါ'))
          : Image.memory(image!, fit: BoxFit.contain));

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.image_search_outlined),
              SizedBox(width: 8),
              Text('Source image',
                  style: TextStyle(fontWeight: FontWeight.w800))
            ]),
            const SizedBox(height: 14),
            fillHeight
                ? Expanded(child: _preview())
                : SizedBox(height: 260, child: _preview()),
            const SizedBox(height: 12),
            Text(name.isEmpty ? 'No image selected' : name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(languages),
              initialValue: languages,
              decoration: const InputDecoration(
                  labelText: 'Recognition language',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: const [
                DropdownMenuItem(
                    value: 'mya+eng', child: Text('Myanmar + English')),
                DropdownMenuItem(value: 'mya', child: Text('Myanmar')),
                DropdownMenuItem(value: 'eng', child: Text('English'))
              ],
              onChanged: running
                  ? null
                  : (value) {
                      if (value != null) onLanguage(value);
                    },
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton.icon(
                  onPressed: running ? null : onPick,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('ပုံရွေးရန်')),
              FilledButton.icon(
                  onPressed: image == null || running ? null : onRecognize,
                  icon: running
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.text_fields),
                  label: Text(running ? 'OCR လုပ်နေသည်…' : 'Text ထုတ်ရန်')),
            ]),
            if (running || status.isNotEmpty) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: running ? progress : 1),
              const SizedBox(height: 5),
              Text(status,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xff5B6880)))
            ],
          ])));
}

class _OutputPanel extends StatelessWidget {
  const _OutputPanel(
      {required this.controller,
      required this.confidence,
      required this.fillHeight,
      required this.enabled,
      required this.onCopy,
      required this.onDownload});
  final TextEditingController controller;
  final double? confidence;
  final bool fillHeight, enabled;
  final VoidCallback onCopy, onDownload;

  Widget _editor() => TextField(
      controller: controller,
      expands: true,
      maxLines: null,
      minLines: null,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
          hintText:
              'Extracted text will appear here. You can edit it before copying or downloading.',
          border: OutlineInputBorder()));

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.article_outlined),
              const SizedBox(width: 8),
              const Text('Extracted text',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (confidence != null)
                Chip(
                    label:
                        Text('Confidence ${confidence!.toStringAsFixed(0)}%'))
            ]),
            const SizedBox(height: 12),
            fillHeight
                ? Expanded(child: _editor())
                : SizedBox(height: 300, child: _editor()),
            const SizedBox(height: 12),
            Wrap(spacing: 10, children: [
              OutlinedButton.icon(
                  onPressed: enabled ? onCopy : null,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy')),
              FilledButton.icon(
                  onPressed: enabled ? onDownload : null,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('TXT Download'))
            ]),
          ])));
}
