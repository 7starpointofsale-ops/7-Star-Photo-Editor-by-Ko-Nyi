import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

class PreviewPanel extends StatelessWidget {
  const PreviewPanel(
      {super.key,
      required this.boundaryKey,
      required this.imageBytes,
      required this.background,
      required this.brightness,
      required this.contrast,
      required this.saturation,
      required this.rotationDegrees,
      required this.aspectRatio,
      required this.outputWidthPx,
      this.cropCenter = const Offset(.5, .5),
      this.cropScale = 1,
      this.cropEditing = false,
      this.onCropPan});
  final GlobalKey boundaryKey;
  final Uint8List? imageBytes;
  final Color background;
  final double brightness,
      contrast,
      saturation,
      rotationDegrees,
      aspectRatio,
      outputWidthPx;
  final Offset cropCenter;
  final double cropScale;
  final bool cropEditing;
  final ValueChanged<Offset>? onCropPan;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: AspectRatio(
          aspectRatio: aspectRatio,
          child: LayoutBuilder(builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final image = imageBytes == null
                ? const Icon(Icons.person, size: 100)
                : ColorFiltered(
                    colorFilter: ColorFilter.matrix(_matrix()),
                    child: ClipRect(
                        child: Transform.rotate(
                            angle: rotationDegrees * 3.141592653589793 / 180,
                            child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..translateByDouble(
                                    (.5 - cropCenter.dx) *
                                        size.width *
                                        cropScale,
                                    (.5 - cropCenter.dy) *
                                        size.height *
                                        cropScale,
                                    0,
                                    1,
                                  )
                                  ..scaleByDouble(cropScale, cropScale, 1, 1),
                                child: Image.memory(imageBytes!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    gaplessPlayback: true)))));
            return GestureDetector(
                onPanUpdate: !cropEditing || onCropPan == null
                    ? null
                    : (details) => onCropPan!(Offset(
                        details.delta.dx / (size.width * cropScale),
                        details.delta.dy / (size.height * cropScale))),
                child: Container(
                    color: background,
                    alignment: Alignment.center,
                    foregroundDecoration: cropEditing
                        ? BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2))
                        : null,
                    child: image));
          })),
    );
  }

  List<double> _matrix() {
    final c = contrast;
    final t = 128 * (1 - c) + (brightness - 1) * 255;
    final s = saturation;
    const r = .213, g = .715, b = .072;
    return [
      c * (r + (1 - r) * s),
      c * (g - g * s),
      c * (b - b * s),
      0,
      t,
      c * (r - r * s),
      c * (g + (1 - g) * s),
      c * (b - b * s),
      0,
      t,
      c * (r - r * s),
      c * (g - g * s),
      c * (b + (1 - b) * s),
      0,
      t,
      0,
      0,
      0,
      1,
      0
    ];
  }

  double get _pixelRatio {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    return outputWidthPx > 0 ? outputWidthPx / boundary.size.width : 2;
  }

  Future<Uint8List> capturePng() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: _pixelRatio);
    final data = await picture.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> captureJpg() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: _pixelRatio);
    final raw = await picture.toByteData(format: ui.ImageByteFormat.rawRgba);
    final encoded = img.Image.fromBytes(
      width: picture.width,
      height: picture.height,
      bytes: raw!.buffer,
      order: img.ChannelOrder.rgba,
    );
    return Uint8List.fromList(img.encodeJpg(encoded, quality: 94));
  }
}
