import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

import 'document_contrast_service.dart';

enum BatchItemState { waiting, processing, done, failed }

class DocumentBatchItem {
  DocumentBatchItem({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  Uint8List? thumbnail;
  BatchItemState state = BatchItemState.waiting;
  String? error;
}

class ProcessedDocument {
  const ProcessedDocument({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });
  final String name;
  final Uint8List bytes;
  final String mimeType;
}

/// Processes a bounded group of independent images in dedicated web workers.
/// PDF pages are rendered lazily, then fed to the same worker pool.  The queue
/// never decodes every selected image/page at once.
class DocumentBatchService {
  DocumentBatchService({DocumentContrastService? fallback})
      : _fallback = fallback ?? DocumentContrastService();
  final DocumentContrastService _fallback;

  int get recommendedParallelism {
    final cores = html.window.navigator.hardwareConcurrency ?? 2;
    // Leave one core for the Flutter UI; cap memory-heavy image workers.
    return (cores - 1).clamp(1, 4);
  }

  Future<List<ProcessedDocument>> processAll(
    List<DocumentBatchItem> items, {
    required DocumentContrastMode mode,
    required bool autoCrop,
    required void Function() onProgress,
  }) async {
    final output = <ProcessedDocument>[];
    final pending = <Future<void>>[];
    for (final item in items) {
      pending.add(_processItem(item, mode, autoCrop).then((result) {
        output.add(result);
      }).catchError((Object error) {
        item.state = BatchItemState.failed;
        item.error = error.toString();
      }).whenComplete(onProgress));
      // Bounded concurrency gives desktop browsers real parallel workers while
      // preventing a 100-file selection from exhausting mobile memory.
      if (pending.length == recommendedParallelism) {
        await Future.wait(pending);
        pending.clear();
      }
    }
    await Future.wait(pending);
    return output;
  }

  Future<ProcessedDocument> _processItem(
      DocumentBatchItem item, DocumentContrastMode mode, bool autoCrop) async {
    item.state = BatchItemState.processing;
    if (_isPdf(item.name)) return _processPdf(item, mode, autoCrop);
    if (!_isImage(item.name)) {
      throw const FormatException(
          'JPG, PNG, WEBP သို့မဟုတ် PDF ဖိုင်သာရပါသည်။');
    }
    final isPng = item.name.toLowerCase().endsWith('.png');
    final bytes = await _processImageInWorker(item.bytes, mode,
        outputType: isPng ? 'image/png' : 'image/jpeg', autoCrop: autoCrop);
    item.state = BatchItemState.done;
    return ProcessedDocument(
      name: '${_stem(item.name)}_contrast.${isPng ? 'png' : 'jpg'}',
      bytes: bytes,
      mimeType: isPng ? 'image/png' : 'image/jpeg',
    );
  }

  Future<ProcessedDocument> _processPdf(
      DocumentBatchItem item, DocumentContrastMode mode, bool autoCrop) async {
    final source = await pdfx.PdfDocument.openData(item.bytes);
    final output = pw.Document();
    try {
      for (var index = 1; index <= source.pagesCount; index++) {
        final page = await source.getPage(index);
        try {
          // ~150 DPI for A4 gives readable output without decoding every page
          // at a costly full camera resolution.
          const scale = 2.1;
          final rendered = await page.render(
              width: page.width * scale, height: page.height * scale);
          if (rendered == null) {
            throw FormatException('PDF page $index ကို render မလုပ်နိုင်ပါ။');
          }
          final clean = await _processImageInWorker(
            Uint8List.fromList(rendered.bytes),
            mode,
            outputType: 'image/png',
            autoCrop: autoCrop,
          );
          final pageFormat = PdfPageFormat(page.width, page.height);
          output.addPage(pw.Page(
              pageFormat: pageFormat,
              margin: pw.EdgeInsets.zero,
              build: (_) =>
                  pw.Image(pw.MemoryImage(clean), fit: pw.BoxFit.fill)));
        } finally {
          await page.close();
        }
      }
      item.state = BatchItemState.done;
      return ProcessedDocument(
        name: '${_stem(item.name)}_contrast.pdf',
        bytes: Uint8List.fromList(await output.save()),
        mimeType: 'application/pdf',
      );
    } finally {
      await source.close();
    }
  }

  Future<Uint8List> _processImageInWorker(
      Uint8List bytes, DocumentContrastMode mode,
      {required String outputType, required bool autoCrop}) async {
    try {
      final worker = html.Worker('document_worker.js');
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final message =
          worker.onMessage.first.timeout(const Duration(minutes: 3));
      final transferable = Uint8List.fromList(bytes);
      worker.postMessage({
        'id': id,
        'buffer': transferable.buffer,
        'mode': mode.name,
        'outputType': outputType,
        'autoCrop': autoCrop,
      }, [
        transferable.buffer
      ]);
      final data = await message;
      worker.terminate();
      final map = Map<String, dynamic>.from(data.data as Map);
      if (map['error'] != null) throw StateError(map['error'].toString());
      return Uint8List.view(map['buffer'] as ByteBuffer);
    } catch (_) {
      if (autoCrop) {
        throw UnsupportedError(
            'Auto crop / perspective correction ကို ဤ browser တွင် မလုပ်နိုင်ပါ။ Chrome သို့မဟုတ် Edge ကိုသုံးပါ။');
      }
      // Safari/older browsers can lack OffscreenCanvas. The fallback remains
      // local and correct, although it runs on the UI thread.
      return _fallback.process(bytes, mode: mode);
    }
  }

  Future<Uint8List?> createThumbnail(DocumentBatchItem item) async {
    if (_isImage(item.name)) return item.bytes;
    if (!_isPdf(item.name)) return null;
    final source = await pdfx.PdfDocument.openData(item.bytes);
    try {
      if (source.pagesCount == 0) return null;
      final page = await source.getPage(1);
      try {
        final ratio = 160 / page.width;
        final image =
            await page.render(width: 160, height: page.height * ratio);
        return image == null ? null : Uint8List.fromList(image.bytes);
      } finally {
        await page.close();
      }
    } finally {
      await source.close();
    }
  }

  Uint8List zip(List<ProcessedDocument> files) {
    final archive = Archive();
    for (final file in files) {
      archive.addFile(ArchiveFile(file.name, file.bytes.length, file.bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  bool _isPdf(String name) => name.toLowerCase().endsWith('.pdf');
  bool _isImage(String name) =>
      RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(name);
  String _stem(String name) => name.replaceFirst(RegExp(r'\.[^.]+$'), '');
}
