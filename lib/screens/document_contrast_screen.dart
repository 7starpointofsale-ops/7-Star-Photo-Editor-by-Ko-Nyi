import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/document_batch_service.dart';
import '../services/document_contrast_service.dart';
import '../utils/image_export.dart';

class DocumentContrastScreen extends StatefulWidget {
  const DocumentContrastScreen({super.key});
  @override
  State<DocumentContrastScreen> createState() => _DocumentContrastScreenState();
}

class _DocumentContrastScreenState extends State<DocumentContrastScreen> {
  final _batch = DocumentBatchService();
  final List<DocumentBatchItem> _items = [];
  DocumentContrastMode _mode = DocumentContrastMode.quality;
  List<ProcessedDocument> _results = [];
  String? _error;
  bool _processing = false;
  bool _autoCrop = false;

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    if (picked == null) {
      return;
    }
    final accepted = <DocumentBatchItem>[];
    for (final file in picked.files) {
      if (file.bytes == null || file.size == 0) continue;
      accepted.add(DocumentBatchItem(name: file.name, bytes: file.bytes!));
    }
    if (accepted.isEmpty) {
      setState(() => _error = 'အသုံးပြုနိုင်သော ဖိုင်မတွေ့ပါ။');
      return;
    }
    setState(() {
      _items.addAll(accepted);
      _results = [];
      _error = null;
    });
    for (final item in accepted) {
      _batch.createThumbnail(item).then((thumbnail) {
        if (mounted) {
          setState(() => item.thumbnail = thumbnail);
        }
      }).catchError((_) {});
    }
  }

  Future<void> _process() async {
    if (_items.isEmpty) return;
    setState(() {
      _processing = true;
      _results = [];
      _error = null;
      for (final item in _items) {
        item.state = BatchItemState.waiting;
        item.error = null;
      }
    });
    try {
      final results = await _batch
          .processAll(_items, mode: _mode, autoCrop: _autoCrop, onProgress: () {
        if (mounted) setState(() {});
      });
      if (mounted) {
        setState(() => _results = results);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Batch processing မလုပ်နိုင်ပါ: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  void _downloadAll() {
    if (_results.isEmpty) return;
    if (_results.length == 1) {
      final file = _results.single;
      downloadBytes(file.bytes, file.name, file.mimeType);
      return;
    }
    downloadBytes(_batch.zip(_results), 'document_contrast_results.zip',
        'application/zip');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan Document သန့်မယ်')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                const Text('Document Contrast',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                    'JPG, PNG, WEBP နှင့် multi-page PDF များကိုရွေးပါ။ Images များကို device CPU အလိုက် worker များဖြင့် parallel လုပ်ပြီး PDF ကို page အားလုံးပါသော PDF အသစ်အဖြစ် ပြန်ထုတ်ပေးပါသည်။'),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                            onPressed: _processing ? null : _pick,
                            icon: const Icon(Icons.add_to_photos_outlined),
                            label: const Text('Files ရွေးရန်')),
                        DropdownButton<DocumentContrastMode>(
                          value: _mode,
                          items: DocumentContrastMode.values
                              .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.name.toUpperCase())))
                              .toList(),
                          onChanged: _processing
                              ? null
                              : (value) => setState(() => _mode = value!),
                        ),
                        FilterChip(
                            selected: _autoCrop,
                            avatar:
                                const Icon(Icons.crop_free_outlined, size: 18),
                            label: const Text('Auto crop / perspective'),
                            onSelected: _processing
                                ? null
                                : (value) => setState(() => _autoCrop = value)),
                        FilledButton.icon(
                            onPressed:
                                _items.isEmpty || _processing ? null : _process,
                            icon: _processing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.auto_fix_high),
                            label: Text(_processing
                                ? 'လုပ်ဆောင်နေသည်…'
                                : '${_items.length} ဖိုင် သန့်စင်ရန်')),
                        if (_results.isNotEmpty)
                          FilledButton.icon(
                              onPressed: _downloadAll,
                              icon: const Icon(Icons.archive_outlined),
                              label: Text(_results.length == 1
                                  ? 'Download'
                                  : 'ZIP Download (${_results.length})')),
                        if (_items.isNotEmpty && !_processing)
                          TextButton.icon(
                              onPressed: () => setState(() {
                                    _items.clear();
                                    _results = [];
                                  }),
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Clear')),
                      ],
                    ),
                  ),
                ),
                if (_autoCrop)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                        'Optional: အနား ၄ ဖက်ကို ယုံကြည်စွာတွေ့မှသာ crop + perspective warp လုပ်ပါမည်။ အနားပျောက်နေခြင်း/တွန့်လိမ်မှု ပြင်းထန်ခြင်းတွင် original geometry ကိုထိန်းထားပါမည်။',
                        style:
                            TextStyle(color: Color(0xff5B6880), height: 1.4)),
                  ),
                const SizedBox(height: 18),
                Text(
                    '${_items.length} files • ${_batch.recommendedParallelism} parallel workers',
                    style: const TextStyle(
                        color: Color(0xff5B6880), fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                if (_items.isEmpty)
                  const _EmptyState()
                else
                  Card(
                    child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) =>
                            _FileRow(item: _items[index])),
                  ),
              ]),
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffE3E8F2))),
        child: const Column(children: [
          Icon(Icons.folder_copy_outlined, size: 46, color: Color(0xff6C7A92)),
          SizedBox(height: 12),
          Text('ဖိုင်အများကြီးကို တစ်ခါတည်းရွေးနိုင်ပါသည်။'),
          SizedBox(height: 4),
          Text('PDF တစ်ဖိုင်ထဲက page အားလုံးကိုလည်း processing လုပ်ပါသည်။',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff60708C))),
        ]),
      );
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.item});
  final DocumentBatchItem item;
  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = switch (item.state) {
      BatchItemState.waiting => (
          Icons.schedule,
          'Waiting',
          const Color(0xff64748B)
        ),
      BatchItemState.processing => (
          Icons.sync,
          'Processing',
          const Color(0xff2563EB)
        ),
      BatchItemState.done => (
          Icons.check_circle,
          'Done',
          const Color(0xff059669)
        ),
      BatchItemState.failed => (
          Icons.error_outline,
          item.error ?? 'Failed',
          const Color(0xffDC2626)
        ),
    };
    return ListTile(
      minVerticalPadding: 8,
      leading: _Thumbnail(item: item),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 6),
        SizedBox(
            width: 78,
            child: Text(text,
                style: TextStyle(color: color),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item});
  final DocumentBatchItem item;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 58,
          height: 44,
          color: const Color(0xffEEF2F8),
          child: item.thumbnail == null
              ? Icon(item.name.toLowerCase().endsWith('.pdf')
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined)
              : Image.memory(item.thumbnail!,
                  cacheWidth: 116,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined)),
        ),
      );
}
