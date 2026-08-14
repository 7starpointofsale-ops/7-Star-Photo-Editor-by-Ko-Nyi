import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

enum WordDocumentKind { office, contract, other }

class WordExportService {
  Future<Uint8List> create({
    required String text,
    required WordDocumentKind kind,
    required int fontSize,
  }) async {
    final worker = html.Worker('word_export_worker.js');
    final completer = Completer<Uint8List>();
    late final StreamSubscription<html.MessageEvent> subscription;
    subscription = worker.onMessage.listen((event) {
      final message = Map<String, dynamic>.from(event.data as Map);
      if (message['error'] != null && !completer.isCompleted) {
        completer.completeError(StateError(message['error'].toString()));
      } else if (message['buffer'] != null && !completer.isCompleted) {
        completer.complete(Uint8List.view(message['buffer'] as ByteBuffer));
      }
    });
    try {
      worker.postMessage({
        'text': text,
        'kind': kind.name,
        'fontSize': fontSize,
      });
      return await completer.future.timeout(const Duration(minutes: 1));
    } finally {
      await subscription.cancel();
      worker.terminate();
    }
  }
}
