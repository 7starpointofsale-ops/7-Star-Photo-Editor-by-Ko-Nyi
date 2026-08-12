import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum DocumentContrastMode { auto, fast, balanced, quality }

/// Local, document-aware illumination normalisation.  A small luminance map is
/// blurred to estimate paper illumination, then interpolated over the original
/// image.  RGB channels are scaled together so coloured handwriting is kept.
class DocumentContrastService {
  Future<Uint8List> process(Uint8List input,
      {DocumentContrastMode mode = DocumentContrastMode.balanced}) async {
    final source = img.decodeImage(input);
    if (source == null) throw const FormatException('ပုံဖိုင်ကို ဖတ်မရပါ။');
    final maxSide = switch (mode) {
      DocumentContrastMode.fast => 520,
      DocumentContrastMode.balanced || DocumentContrastMode.auto => 800,
      DocumentContrastMode.quality => 1100,
    };
    final scale =
        math.min(1.0, maxSide / math.max(source.width, source.height));
    final mapW = math.max(1, (source.width * scale).round()).toInt();
    final mapH = math.max(1, (source.height * scale).round()).toInt();
    final small = img.copyResize(source,
        width: mapW, height: mapH, interpolation: img.Interpolation.linear);
    final luminance = List<double>.filled(mapW * mapH, 0);
    for (var yy = 0; yy < mapH; yy++) {
      for (var xx = 0; xx < mapW; xx++) {
        final p = small.getPixel(xx, yy);
        luminance[yy * mapW + xx] = .2126 * p.r + .7152 * p.g + .0722 * p.b;
      }
    }
    final radius = switch (mode) {
      DocumentContrastMode.fast => 18,
      DocumentContrastMode.balanced || DocumentContrastMode.auto => 30,
      DocumentContrastMode.quality => 42,
    };
    final background = _boxBlur(luminance, mapW, mapH, radius);
    final target = _percentile(background, .72).clamp(150, 238);
    final output = img.Image.from(source);
    for (var yy = 0; yy < source.height; yy++) {
      final fy = yy * (mapH - 1) / math.max(1, source.height - 1);
      for (var xx = 0; xx < source.width; xx++) {
        final bg = _bilinear(background, mapW, mapH,
            xx * (mapW - 1) / math.max(1, source.width - 1), fy);
        // A restrained gain avoids turning faint paper texture into noise.
        final gain = (target / math.max(35, bg)).clamp(.58, 1.85);
        final p = source.getPixel(xx, yy);
        final rr = _tone(p.r * gain);
        final gg = _tone(p.g * gain);
        final bb = _tone(p.b * gain);
        output.setPixelRgba(xx, yy, rr, gg, bb, p.a);
      }
    }
    return Uint8List.fromList(img.encodeJpg(output, quality: 94));
  }

  List<double> _boxBlur(
      List<double> values, int width, int height, int radius) {
    final integral = List<double>.filled((width + 1) * (height + 1), 0);
    for (var y = 1; y <= height; y++) {
      var row = 0.0;
      for (var x = 1; x <= width; x++) {
        row += values[(y - 1) * width + x - 1];
        integral[y * (width + 1) + x] =
            integral[(y - 1) * (width + 1) + x] + row;
      }
    }
    final result = List<double>.filled(values.length, 0);
    for (var y = 0; y < height; y++) {
      final top = math.max(0, y - radius).toInt();
      final bottom = math.min(height - 1, y + radius).toInt();
      for (var x = 0; x < width; x++) {
        final left = math.max(0, x - radius).toInt();
        final right = math.min(width - 1, x + radius).toInt();
        final sum = integral[(bottom + 1) * (width + 1) + right + 1] -
            integral[top * (width + 1) + right + 1] -
            integral[(bottom + 1) * (width + 1) + left] +
            integral[top * (width + 1) + left];
        result[y * width + x] = sum / ((right - left + 1) * (bottom - top + 1));
      }
    }
    return result;
  }

  double _bilinear(
      List<double> values, int width, int height, double x, double y) {
    final x0 = x.floor().clamp(0, width - 1);
    final y0 = y.floor().clamp(0, height - 1);
    final x1 = math.min(width - 1, x0 + 1).toInt();
    final y1 = math.min(height - 1, y0 + 1).toInt();
    final dx = x - x0, dy = y - y0;
    return values[y0 * width + x0] * (1 - dx) * (1 - dy) +
        values[y0 * width + x1] * dx * (1 - dy) +
        values[y1 * width + x0] * (1 - dx) * dy +
        values[y1 * width + x1] * dx * dy;
  }

  double _percentile(List<double> values, double fraction) {
    final copy = [...values]..sort();
    return copy[(copy.length * fraction).floor().clamp(0, copy.length - 1)];
  }

  int _tone(num value) {
    final normalized = (value / 255).clamp(0.0, 1.0);
    return (255 * math.pow(normalized, .94)).round().clamp(0, 255);
  }
}
