import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:myanmar_photo_editor/services/document_contrast_service.dart';

void main() {
  test('normalises uneven paper while retaining dark and blue marks', () async {
    final input = img.Image(width: 240, height: 120);
    for (var y = 0; y < input.height; y++) {
      for (var x = 0; x < input.width; x++) {
        // Simulates a document whose right side has much less illumination.
        final paper = 220 - (x * 105 ~/ input.width);
        input.setPixelRgba(x, y, paper, paper, paper, 255);
      }
    }
    for (var x = 30; x < 210; x++) {
      input.setPixelRgba(x, 35, 36, 36, 36, 255);
      input.setPixelRgba(x, 80, 35, 70, 175, 255);
    }

    final bytes = Uint8List.fromList(img.encodeJpg(input, quality: 100));
    final result = await DocumentContrastService()
        .process(bytes, mode: DocumentContrastMode.quality);
    final output = img.decodeImage(result)!;
    final leftPaper = output.getPixel(15, 15);
    final rightPaper = output.getPixel(225, 15);
    final blackInk = output.getPixel(120, 35);
    final blueInk = output.getPixel(120, 80);

    expect((leftPaper.r + leftPaper.g + leftPaper.b) / 3, greaterThan(225));
    expect((rightPaper.r + rightPaper.g + rightPaper.b) / 3, greaterThan(225));
    expect(blackInk.r, lessThan(135));
    expect(blueInk.b, greaterThan(blueInk.r + 25));
  });
}
