import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class OcrProgress {
  const OcrProgress(this.status, this.value);
  final String status;
  final double value;
}

class OcrResult {
  const OcrResult({required this.text, required this.confidence});
  final String text;
  final double confidence;
}

/// Runs OCR inside a browser Web Worker. Image pixels never go through this
/// app's server: the worker only downloads the public OCR engine/language data.
class LocalOcrService {
  Future<OcrResult> recognize(
    Uint8List bytes, {
    required String languages,
    required void Function(OcrProgress) onProgress,
  }) async {
    final worker = html.Worker('ocr_worker.js');
    final completer = Completer<OcrResult>();
    late final StreamSubscription<html.MessageEvent> subscription;
    subscription = worker.onMessage.listen((event) {
      final message = Map<String, dynamic>.from(event.data as Map);
      switch (message['type']) {
        case 'progress':
          onProgress(OcrProgress(
            message['status']?.toString() ?? 'Processing',
            (message['progress'] as num? ?? 0).toDouble(),
          ));
        case 'result':
          if (!completer.isCompleted) {
            completer.complete(OcrResult(
              text: message['text']?.toString() ?? '',
              confidence: (message['confidence'] as num? ?? 0).toDouble(),
            ));
          }
        case 'error':
          if (!completer.isCompleted) {
            completer.completeError(
                StateError(message['message']?.toString() ?? 'OCR failed'));
          }
      }
    });
    try {
      final transferable = Uint8List.fromList(bytes);
      worker.postMessage({
        'bytes': transferable.buffer,
        'languages': languages,
      }, [
        transferable.buffer
      ]);
      return await completer.future.timeout(const Duration(minutes: 5));
    } finally {
      await subscription.cancel();
      worker.terminate();
    }
  }
}
