import 'package:flutter/material.dart';

enum PrintUnit { px, inch, mm, cm }

class TransformControls extends StatelessWidget {
  const TransformControls(
      {super.key,
      required this.rotation,
      required this.onRotation,
      required this.unit,
      required this.onUnit,
      required this.width,
      required this.height,
      required this.onWidth,
      required this.onHeight,
      required this.dpi,
      required this.onDpi,
      required this.cropScale,
      required this.onCropScale,
      required this.onReset});
  final double rotation;
  final ValueChanged<double> onRotation;
  final PrintUnit unit;
  final ValueChanged<PrintUnit> onUnit;
  final TextEditingController width, height, dpi;
  final double cropScale;
  final ValueChanged<double> onCropScale;
  final VoidCallback onWidth, onHeight, onDpi, onReset;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('↻ လှည့်ခြင်း / ဖြောင့်တန်းခြင်း',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
              onPressed: () => onRotation(rotation - 90),
              icon: const Icon(Icons.rotate_left),
              label: const Text('ဘယ်လှည့်')),
          OutlinedButton.icon(
              onPressed: () => onRotation(rotation + 90),
              icon: const Icon(Icons.rotate_right),
              label: const Text('ညာလှည့်')),
          TextButton(onPressed: onReset, child: const Text('ပြန်လည်သတ်မှတ်'))
        ]),
        Slider(
            value: rotation.clamp(-180, 180).toDouble(),
            min: -180,
            max: 180,
            divisions: 360,
            label: '${rotation.toStringAsFixed(1)}°',
            onChanged: onRotation),
        Text('ဖြောင့်တန်း: ${rotation.toStringAsFixed(1)}°'),
        const SizedBox(height: 18),
        const Text('✂️ ဖြတ်တောက်ရန် / Output အရွယ်အစား',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        DropdownButton<PrintUnit>(
            value: unit,
            onChanged: (v) {
              if (v != null) onUnit(v);
            },
            items: PrintUnit.values
                .map((v) =>
                    DropdownMenuItem(value: v, child: Text(_unitName(v))))
                .toList()),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _input('အကျယ်', width, onWidth),
          _input('အမြင့်', height, onHeight),
          if (unit != PrintUnit.px) _input('DPI', dpi, onDpi)
        ]),
        const SizedBox(height: 6),
        const Text(
            'Preview ပေါ်ရှိ crop frame အတွင်း ပုံကို drag လုပ်၍ crop နေရာရွှေ့ပါ။'),
        Slider(
            value: cropScale.clamp(1, 4).toDouble(),
            min: 1,
            max: 4,
            divisions: 60,
            label: '${cropScale.toStringAsFixed(2)}×',
            onChanged: onCropScale),
        const Text(
            'Crop zoom / resize — ရွေးထားသော အချိုးအစားနှင့် preview/export ကို တကယ်ဖြတ်တောက်ပါမည်။')
      ]);
  Widget _input(String label, TextEditingController controller,
          VoidCallback changed) =>
      SizedBox(
          width: 120,
          child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                  isDense: true),
              onSubmitted: (_) => changed(),
              onChanged: (_) => changed()));
  String _unitName(PrintUnit unit) => switch (unit) {
        PrintUnit.px => 'px',
        PrintUnit.inch => 'inch',
        PrintUnit.mm => 'mm',
        PrintUnit.cm => 'cm'
      };
}
