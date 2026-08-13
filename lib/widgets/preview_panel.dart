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
            if (cropEditing && imageBytes != null) {
              return _CropEditor(
                imageBytes: imageBytes!,
                background: background,
                matrix: _matrix(),
                rotationDegrees: rotationDegrees,
                cropCenter: cropCenter,
                cropScale: cropScale,
                onPan: onCropPan,
              );
            }
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

/// An editing-only view: the complete original stays visible beneath a movable
/// crop frame. Export uses the regular output canvas, so no dimmer or guide is
/// ever included in the saved JPG/PNG.
class _CropEditor extends StatelessWidget {
  const _CropEditor({
    required this.imageBytes,
    required this.background,
    required this.matrix,
    required this.rotationDegrees,
    required this.cropCenter,
    required this.cropScale,
    required this.onPan,
  });

  final Uint8List imageBytes;
  final Color background;
  final List<double> matrix;
  final double rotationDegrees;
  final Offset cropCenter;
  final double cropScale;
  final ValueChanged<Offset>? onPan;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanUpdate: onPan == null
                ? null
                : (details) => onPan!(Offset(
                      details.delta.dx / size.width,
                      details.delta.dy / size.height,
                    )),
            child: Stack(fit: StackFit.expand, children: [
              Container(color: background),
              ColorFiltered(
                colorFilter: ColorFilter.matrix(matrix),
                child: Transform.rotate(
                  angle: rotationDegrees * 3.141592653589793 / 180,
                  child: Image.memory(imageBytes,
                      fit: BoxFit.contain, gaplessPlayback: true),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _CropFramePainter(
                    center: cropCenter,
                    scale: cropScale,
                  ),
                ),
              ),
              const Positioned(
                left: 10,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Color(0xB0000000),
                      borderRadius: BorderRadius.all(Radius.circular(6))),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Text('Crop box ကို drag လုပ်ရွှေ့ပါ',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
            ]),
          );
        },
      );
}

class _CropFramePainter extends CustomPainter {
  const _CropFramePainter({required this.center, required this.scale});
  final Offset center;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    // A smaller frame means a tighter crop. Its aspect ratio remains the
    // output ratio because the enclosing canvas is already that ratio.
    final zoom = scale.clamp(1.0, 4.0).toDouble();
    final frameWidth = size.width / zoom;
    final frameHeight = size.height / zoom;
    final origin = Offset(
      (center.dx * size.width - frameWidth / 2)
          .clamp(0.0, size.width - frameWidth)
          .toDouble(),
      (center.dy * size.height - frameHeight / 2)
          .clamp(0.0, size.height - frameHeight)
          .toDouble(),
    );
    final frame = Rect.fromLTWH(origin.dx, origin.dy, frameWidth, frameHeight);
    final shade = Paint()..color = const Color(0x99000000);
    final all = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(all, shade);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(frame, border);
    final grid = Paint()
      ..color = const Color(0xBFFFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(frame.left + frame.width * i / 3, frame.top),
          Offset(frame.left + frame.width * i / 3, frame.bottom), grid);
      canvas.drawLine(Offset(frame.left, frame.top + frame.height * i / 3),
          Offset(frame.right, frame.top + frame.height * i / 3), grid);
    }
    for (final point in [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight
    ]) {
      canvas.drawCircle(point, 5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_CropFramePainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.scale != scale;
}
