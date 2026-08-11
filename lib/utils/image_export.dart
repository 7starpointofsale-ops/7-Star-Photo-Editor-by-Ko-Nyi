import 'dart:html' as html;
import 'dart:typed_data';

void downloadBytes(Uint8List bytes, String filename, String mimeType) {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = filename;
  anchor.click();
  html.Url.revokeObjectUrl(url);
}
