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
import '../widgets/transform_controls.dart';

enum _EditorTool {
  photo,
  removeBackground,
  background,
  enhance,
  crop,
  cloth,
  export
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _EditorTool _tool = _EditorTool.photo;
  Uint8List? original, working, garment;
  String filename = 'passport-photo';
  Color background = Colors.blue;
  double brightness = 1, contrast = 1, saturation = 1, rotation = 0;
  Offset cropCenter = const Offset(.5, .5);
  double cropScale = 1;
  bool loading = false;
  String? error;
  PrintUnit unit = PrintUnit.mm;
  final previewKey = GlobalKey();
  final removeService = RemoveBackgroundService();
  final clothService = UnavailableClothChangeService();
  final width = TextEditingController(text: '35');
  final height = TextEditingController(text: '45');
  final dpi = TextEditingController(text: '300');

  @override
  void dispose() {
    width.dispose();
    height.dispose();
    dpi.dispose();
    super.dispose();
  }

  void _err(String value) => setState(() => error = value);
  double _num(TextEditingController controller, double fallback) =>
      double.tryParse(controller.text) ?? fallback;

  double get _ratio {
    final w = _num(width, 35);
    final h = _num(height, 45);
    return w > 0 && h > 0 ? w / h : 3 / 4;
  }

  double get _outputWidth {
    final value = _num(width, 35);
    final resolution = _num(dpi, 300);
    return switch (unit) {
      PrintUnit.px => value,
      PrintUnit.inch => value * resolution,
      PrintUnit.mm => value / 25.4 * resolution,
      PrintUnit.cm => value / 2.54 * resolution,
    };
  }

  bool get _hasPhoto => original != null;
  Uint8List? get _image => working ?? original;

  Future<void> _remove() async {
    if (original == null) {
      _err('ပထမဦးစွာ ပုံတင်ပါ။');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result =
          await removeService.remove(bytes: original!, filename: filename);
      final bytes = await removeService.download(result.uuid);
      if (mounted) {
        setState(() {
          working = bytes;
          _tool = _EditorTool.background;
        });
      }
    } on BackgroundRemovalException catch (exception) {
      if (mounted) _err(exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _cloth() async {
    if (working == null || garment == null) return;
    setState(() => loading = true);
    try {
      await clothService.change(person: working!, garment: garment!);
    } on ClothChangeException catch (exception) {
      if (mounted) _err(exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _reset() => setState(() {
        _tool = _EditorTool.photo;
        original = working = garment = null;
        background = Colors.blue;
        brightness = contrast = saturation = 1;
        rotation = 0;
        cropCenter = const Offset(.5, .5);
        cropScale = 1;
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
        outputWidthPx: _outputWidth,
        cropCenter: cropCenter,
        cropScale: cropScale,
        cropEditing: _tool == _EditorTool.crop,
        onCropPan: (delta) => setState(() {
          cropCenter = Offset(
            (cropCenter.dx + delta.dx).clamp(0.0, 1.0).toDouble(),
            (cropCenter.dy + delta.dy).clamp(0.0, 1.0).toDouble(),
          );
        }),
      );

  Future<void> _export(bool jpg) async {
    if (_image == null) {
      _err('ပထမဦးစွာ ပုံတင်ပါ။');
      return;
    }
    try {
      final panel = _panel(_image);
      final bytes = jpg ? await panel.captureJpg() : await panel.capturePng();
      downloadBytes(
        bytes,
        '${filename.replaceAll(RegExp(r'\.[^.]+$'), '')}.${jpg ? 'jpg' : 'png'}',
        jpg ? 'image/jpeg' : 'image/png',
      );
    } catch (_) {
      if (mounted) _err('ဒေါင်းလုဒ်လုပ်ရာတွင် အခက်အခဲရှိပါသည်။');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('License Photo Editor'),
        actions: [
          IconButton(
            tooltip: 'အစမှပြန်လုပ်ရန်',
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                children: [
                  if (error != null)
                    MaterialBanner(
                      content: Text(error!),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => error = null),
                          child: const Text('ပိတ်ရန်'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tools = _ToolBar(
                          selected: _tool,
                          hasPhoto: _hasPhoto,
                          onSelected: (tool) => setState(() => _tool = tool),
                        );
                        final controls = _ControlCard(child: _controls());
                        final preview = _PreviewCard(panel: _panel(_image));
                        if (constraints.maxWidth > 860) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 96, child: tools),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 350,
                                child: SingleChildScrollView(child: controls),
                              ),
                              const SizedBox(width: 18),
                              Expanded(child: preview),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            SizedBox(height: 72, child: tools),
                            const SizedBox(height: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    controls,
                                    const SizedBox(height: 14),
                                    preview
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 12),
                          Text('လုပ်ဆောင်နေပါသည်...'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    switch (_tool) {
      case _EditorTool.photo:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _ControlTitle(
              icon: Icons.add_a_photo_outlined, text: 'ပုံတင်ရန်'),
          const SizedBox(height: 8),
          const Text(
              'JPG, JPEG သို့မဟုတ် PNG ပုံကိုရွေးပါ။ ပုံတင်ပြီးလျှင် tools အားလုံးကို ချက်ချင်းသုံးနိုင်ပါသည်။'),
          const SizedBox(height: 16),
          ImageUploader(
            onImage: (bytes, name) => setState(() {
              original = bytes;
              working = null;
              filename = name;
              error = null;
              _tool = _EditorTool.removeBackground;
            }),
          ),
        ]);
      case _EditorTool.removeBackground:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _ControlTitle(icon: Icons.content_cut, text: 'နောက်ခံဖယ်ရန်'),
          const SizedBox(height: 8),
          const Text(
              'နောက်ခံဖယ်ရန်ကို နှိပ်မှသာ FileConv service ကိုခေါ်ပါမည်။ မဖယ်ဘဲ အခြား tools များကိုလည်း ဆက်သုံးနိုင်ပါသည်။'),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: loading ? null : _remove,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('နောက်ခံဖယ်ရန်'),
          ),
          if (!_hasPhoto)
            const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('ပထမဦးစွာ Photo tool မှ ပုံတင်ပါ။')),
        ]);
      case _EditorTool.background:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _ControlTitle(
              icon: Icons.palette_outlined, text: 'နောက်ခံအရောင်'),
          const SizedBox(height: 8),
          const Text(
              'ရွေးလိုက်သော အရောင်သည် preview တွင် ချက်ချင်းပြောင်းပါမည်။'),
          const SizedBox(height: 16),
          BackgroundSelector(
              color: background,
              onChanged: (value) => setState(() => background = value)),
        ]);
      case _EditorTool.enhance:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _ControlTitle(icon: Icons.tune, text: 'အလင်းအမှောင်'),
          const SizedBox(height: 12),
          EnhancementControls(
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            onBrightness: (value) => setState(() => brightness = value),
            onContrast: (value) => setState(() => contrast = value),
            onSaturation: (value) => setState(() => saturation = value),
            onAuto: () => setState(() {
              brightness = 1.08;
              contrast = 1.08;
              saturation = 1.04;
            }),
          ),
        ]);
      case _EditorTool.crop:
        return TransformControls(
          rotation: rotation,
          onRotation: (value) =>
              setState(() => rotation = value.clamp(-180, 180).toDouble()),
          unit: unit,
          onUnit: (value) => setState(() => unit = value),
          width: width,
          height: height,
          dpi: dpi,
          onWidth: () => setState(() {}),
          onHeight: () => setState(() {}),
          onDpi: () => setState(() {}),
          cropScale: cropScale,
          onCropScale: (value) => setState(() => cropScale = value),
          onReset: () => setState(() {
            rotation = 0;
            cropCenter = const Offset(.5, .5);
            cropScale = 1;
          }),
        );
      case _EditorTool.cloth:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _ControlTitle(
              icon: Icons.checkroom_outlined, text: 'အဝတ်အစားပြောင်းရန်'),
          const SizedBox(height: 12),
          ClothChangePanel(
              garment: garment,
              onGarment: (bytes) => setState(() => garment = bytes),
              onGenerate: _cloth),
        ]);
      case _EditorTool.export:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _ControlTitle(icon: Icons.download_outlined, text: 'Export'),
          const SizedBox(height: 8),
          Text(
              'Output: ${_outputWidth.round()} × ${(_outputWidth / _ratio).round()} px'),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _hasPhoto ? () => _export(true) : null,
              icon: const Icon(Icons.download),
              label: const Text('JPG ဒေါင်းလုဒ်')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: _hasPhoto ? () => _export(false) : null,
              icon: const Icon(Icons.download),
              label: const Text('PNG ဒေါင်းလုဒ်')),
        ]);
    }
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar(
      {required this.selected,
      required this.hasPhoto,
      required this.onSelected});
  final _EditorTool selected;
  final bool hasPhoto;
  final ValueChanged<_EditorTool> onSelected;

  static const _items = [
    (_EditorTool.photo, Icons.add_a_photo_outlined, 'Photo'),
    (_EditorTool.removeBackground, Icons.content_cut, 'Remove BG'),
    (_EditorTool.background, Icons.palette_outlined, 'Background'),
    (_EditorTool.enhance, Icons.tune, 'Adjust'),
    (_EditorTool.crop, Icons.crop_free_outlined, 'Crop'),
    (_EditorTool.cloth, Icons.checkroom_outlined, 'Cloth'),
    (_EditorTool.export, Icons.download_outlined, 'Export'),
  ];

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final vertical = MediaQuery.sizeOf(context).width > 860;
        final buttons = _items.map((item) {
          final (tool, icon, label) = item;
          final enabled = tool == _EditorTool.photo || hasPhoto;
          final active = selected == tool;
          return Tooltip(
            message: label,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? () => onSelected(tool) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: vertical ? double.infinity : 76,
                height: vertical ? 58 : double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: vertical
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(icon, color: enabled ? null : Colors.grey),
                            const SizedBox(height: 4),
                            Text(label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: enabled ? null : Colors.grey))
                          ])
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(icon, color: enabled ? null : Colors.grey),
                            const SizedBox(width: 6),
                            Text(label,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: enabled ? null : Colors.grey))
                          ]),
              ),
            ),
          );
        }).toList();
        return Card(
          clipBehavior: Clip.antiAlias,
          child: vertical
              ? Column(children: buttons)
              : ListView(scrollDirection: Axis.horizontal, children: buttons),
        );
      });
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(padding: const EdgeInsets.all(20), child: child));
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.panel});
  final Widget panel;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.visibility_outlined, size: 19),
                SizedBox(width: 8),
                Text('Live canvas',
                    style: TextStyle(fontWeight: FontWeight.w800))
              ]),
              const SizedBox(height: 14),
              Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 640),
                      child: panel)),
            ],
          ),
        ),
      );
}

class _ControlTitle extends StatelessWidget {
  const _ControlTitle({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon),
        const SizedBox(width: 9),
        Text(text,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))
      ]);
}
