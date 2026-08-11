import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/cloth_change_service.dart';
import '../services/remove_background_service.dart';
import '../utils/image_export.dart';
import '../widgets/background_selector.dart';
import '../widgets/cloth_change_panel.dart';
import '../widgets/enhancement_controls.dart';
import '../widgets/image_uploader.dart';
import '../widgets/preview_panel.dart';
import '../widgets/step_indicator.dart';
import '../widgets/transform_controls.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int step = 0;
  Uint8List? original, working, garment;
  String filename = 'passport-photo';
  Color background = Colors.blue;
  double brightness = 1, contrast = 1, saturation = 1, rotation = 0;
  bool loading = false;
  String? error;
  PrintUnit unit = PrintUnit.mm;
  final previewKey = GlobalKey();
  final removeService = RemoveBackgroundService();
  final clothService = UnavailableClothChangeService();
  final width = TextEditingController(text: '35'),
      height = TextEditingController(text: '45'),
      dpi = TextEditingController(text: '300');
  @override
  void dispose() {
    width.dispose();
    height.dispose();
    dpi.dispose();
    super.dispose();
  }

  void _err(String v) => setState(() => error = v);
  double _num(TextEditingController c, double fallback) =>
      double.tryParse(c.text) ?? fallback;
  double get _ratio {
    final w = _num(width, 35), h = _num(height, 45);
    return w > 0 && h > 0 ? w / h : 3 / 4;
  }

  double get _outputWidth {
    final v = _num(width, 35);
    final d = _num(dpi, 300);
    return switch (unit) {
      PrintUnit.px => v,
      PrintUnit.inch => v * d,
      PrintUnit.mm => v / 25.4 * d,
      PrintUnit.cm => v / 2.54 * d
    };
  }

  Future<void> _remove() async {
    if (original == null) return;
    setState(() => loading = true);
    try {
      final result =
          await removeService.remove(bytes: original!, filename: filename);
      final bytes = await removeService.download(result.uuid);
      if (mounted) {
        setState(() {
          working = bytes;
          step = 2;
        });
      }
    } on BackgroundRemovalException catch (e) {
      if (mounted) _err(e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _cloth() async {
    if (working == null || garment == null) return;
    setState(() => loading = true);
    try {
      await clothService.change(person: working!, garment: garment!);
    } on ClothChangeException catch (e) {
      if (mounted) _err(e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _reset() => setState(() {
        step = 0;
        original = working = garment = null;
        background = Colors.blue;
        brightness = contrast = saturation = 1;
        rotation = 0;
        error = null;
        width.text = '35';
        height.text = '45';
        dpi.text = '300';
        unit = PrintUnit.mm;
      });
  PreviewPanel _panel(Uint8List? image) => PreviewPanel(
      boundaryKey: previewKey,
      imageBytes: image,
      background: background,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
      rotationDegrees: rotation,
      aspectRatio: _ratio,
      outputWidthPx: _outputWidth);
  Future<void> _export(bool jpg) async {
    try {
      final panel = _panel(working ?? original);
      final bytes = jpg ? await panel.captureJpg() : await panel.capturePng();
      downloadBytes(
          bytes,
          '${filename.replaceAll(RegExp(r'\.[^.]+$'), '')}.${jpg ? 'jpg' : 'png'}',
          jpg ? 'image/jpeg' : 'image/png');
    } catch (_) {
      if (mounted) _err('ဒေါင်းလုဒ်လုပ်ရာတွင် အခက်အခဲရှိပါသည်။');
    }
  }

  void _next() {
    if (step == 0 && original == null) {
      _err('ပထမဦးစွာ ပုံတင်ပါ။');
      return;
    }
    if (step == 1 && working == null) {
      _err('နောက်ခံဖယ်ပါ၊ သို့မဟုတ် ကျော်ရန်ကို ရွေးပါ။');
      return;
    }
    if (step < 6) setState(() => step++);
  }

  void _skip() {
    if (step == 1 && original != null) working = original;
    if (step < 6) setState(() => step++);
  }

  @override
  Widget build(BuildContext context) {
    final image = working ?? original;
    return Scaffold(
        appBar: AppBar(
            title: const Text('မြန်မာ Passport / License Photo Editor'),
            actions: [
              IconButton(
                  tooltip: 'အစမှပြန်လုပ်ရန်',
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt))
            ]),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          StepIndicator(current: step),
                          if (error != null)
                            MaterialBanner(content: Text(error!), actions: [
                              TextButton(
                                  onPressed: () => setState(() => error = null),
                                  child: const Text('ပိတ်ရန်'))
                            ]),
                          Expanded(child: LayoutBuilder(builder: (context, c) {
                            final controls = _controls();
                            final panel = _panel(image);
                            return c.maxWidth > 700
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                        Expanded(
                                            child: SingleChildScrollView(
                                                child: controls)),
                                        const SizedBox(width: 28),
                                        Expanded(child: Center(child: panel))
                                      ])
                                : SingleChildScrollView(
                                    child: Column(children: [
                                    controls,
                                    const SizedBox(height: 20),
                                    panel
                                  ]));
                          })),
                          if (loading)
                            const Padding(
                                padding: EdgeInsets.all(12),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(width: 12),
                                      Text('လုပ်ဆောင်နေပါသည်...')
                                    ]))
                        ]))))));
  }

  Widget _controls() {
    Widget content;
    switch (step) {
      case 0:
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📷 ပုံတင်ရန်',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ImageUploader(
              onImage: (b, n) => setState(() {
                    original = b;
                    working = null;
                    filename = n;
                    error = null;
                  }))
        ]);
        break;
      case 1:
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('✂️ နောက်ခံဖယ်ရန်',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: loading ? null : _remove,
              child: const Text('နောက်ခံဖယ်ရန်'))
        ]);
        break;
      case 2:
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🎨 နောက်ခံအရောင်',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          BackgroundSelector(
              color: background,
              onChanged: (v) => setState(() => background = v))
        ]);
        break;
      case 3:
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💡 အလင်းအမှောင်',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          EnhancementControls(
              brightness: brightness,
              contrast: contrast,
              saturation: saturation,
              onBrightness: (v) => setState(() => brightness = v),
              onContrast: (v) => setState(() => contrast = v),
              onSaturation: (v) => setState(() => saturation = v),
              onAuto: () => setState(() {
                    brightness = 1.08;
                    contrast = 1.08;
                    saturation = 1.04;
                  }))
        ]);
        break;
      case 4:
        content = TransformControls(
            rotation: rotation,
            onRotation: (v) =>
                setState(() => rotation = v.clamp(-180, 180).toDouble()),
            unit: unit,
            onUnit: (v) => setState(() => unit = v),
            width: width,
            height: height,
            dpi: dpi,
            onWidth: () => setState(() {}),
            onHeight: () => setState(() {}),
            onDpi: () => setState(() {}),
            onReset: () => setState(() => rotation = 0));
        break;
      case 5:
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('👕 အဝတ်အစားပြောင်းရန်',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClothChangePanel(
              garment: garment,
              onGarment: (b) => setState(() => garment = b),
              onGenerate: _cloth)
        ]);
        break;
      default:
        content =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('⬇️ ဒေါင်းလုဒ်',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: () => _export(true),
              icon: const Icon(Icons.download),
              label: const Text('JPG ဒေါင်းလုဒ်')),
          OutlinedButton.icon(
              onPressed: () => _export(false),
              icon: const Icon(Icons.download),
              label: const Text('PNG ဒေါင်းလုဒ်'))
        ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      content,
      const SizedBox(height: 28),
      Row(children: [
        if (step > 0)
          OutlinedButton(
              onPressed: loading ? null : () => setState(() => step--),
              child: const Text('နောက်သို့')),
        const Spacer(),
        if (step >= 1 && step <= 5)
          TextButton(
              onPressed: loading ? null : _skip, child: const Text('ကျော်ရန်')),
        const SizedBox(width: 8),
        FilledButton(
            onPressed: loading || step == 6 ? null : _next,
            child: const Text('ဆက်ရန်'))
      ])
    ]);
  }
}
