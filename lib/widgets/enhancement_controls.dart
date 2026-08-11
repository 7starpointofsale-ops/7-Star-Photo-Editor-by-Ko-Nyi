import 'package:flutter/material.dart';

class EnhancementControls extends StatelessWidget {
  const EnhancementControls({super.key, required this.brightness, required this.contrast, required this.saturation, required this.onBrightness, required this.onContrast, required this.onSaturation, required this.onAuto});
  final double brightness, contrast, saturation; final ValueChanged<double> onBrightness, onContrast, onSaturation; final VoidCallback onAuto;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FilledButton.icon(onPressed: onAuto, icon: const Icon(Icons.auto_fix_high), label: const Text('အလိုအလျောက်ပြင်ရန်')), _slider('အလင်း', brightness, onBrightness), _slider('Contrast', contrast, onContrast), _slider('အရောင်', saturation, onSaturation)]);
  Widget _slider(String label, double value, ValueChanged<double> update) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Slider(value: value, min: .5, max: 1.5, divisions: 20, label: value.toStringAsFixed(2), onChanged: update)]);
}
