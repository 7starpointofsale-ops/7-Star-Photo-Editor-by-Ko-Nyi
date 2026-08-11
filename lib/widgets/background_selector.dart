import 'package:flutter/material.dart';

class BackgroundSelector extends StatelessWidget {
  const BackgroundSelector(
      {super.key, required this.color, required this.onChanged});
  final Color color;
  final ValueChanged<Color> onChanged;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 10, runSpacing: 10, children: [
        _quick('အနီ', Colors.red.shade700),
        _quick('အစိမ်း', Colors.green.shade700),
        _quick('အပြာ', Colors.blue.shade800),
        OutlinedButton.icon(
            onPressed: () async {
              final result = await showDialog<Color>(
                  context: context,
                  builder: (_) => _ColorDialog(initial: color));
              if (result != null) onChanged(result);
            },
            icon: const Icon(Icons.palette_outlined),
            label: const Text('စိတ်ကြိုက်အရောင်')),
      ]);
  Widget _quick(String label, Color value) => ChoiceChip(
      label: Text(label),
      selected: color.toARGB32() == value.toARGB32(),
      selectedColor: value.withValues(alpha: .22),
      onSelected: (_) => onChanged(value));
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial});
  final Color initial;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late Color value;
  late final TextEditingController hex;
  late final TextEditingController r;
  late final TextEditingController g;
  late final TextEditingController b;
  late final TextEditingController c;
  late final TextEditingController m;
  late final TextEditingController y;
  late final TextEditingController k;
  @override
  void initState() {
    super.initState();
    value = widget.initial;
    hex = TextEditingController();
    r = TextEditingController();
    g = TextEditingController();
    b = TextEditingController();
    c = TextEditingController();
    m = TextEditingController();
    y = TextEditingController();
    k = TextEditingController();
    _sync();
  }

  @override
  void dispose() {
    for (final x in [hex, r, g, b, c, m, y, k]) {
      x.dispose();
    }
    super.dispose();
  }

  void _sync() {
    hex.text =
        '#${value.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    r.text = (value.r * 255).round().toString();
    g.text = (value.g * 255).round().toString();
    b.text = (value.b * 255).round().toString();
    final max = [value.r, value.g, value.b].reduce((a, z) => a > z ? a : z);
    final key = 1 - max;
    c.text =
        ((max == 0 ? 0 : (max - value.r) / (1 - key)) * 100).round().toString();
    m.text =
        ((max == 0 ? 0 : (max - value.g) / (1 - key)) * 100).round().toString();
    y.text =
        ((max == 0 ? 0 : (max - value.b) / (1 - key)) * 100).round().toString();
    k.text = (key * 100).round().toString();
  }

  double _n(TextEditingController x, double max) =>
      double.tryParse(x.text)?.clamp(0, max).toDouble() ?? 0;
  void _rgb() {
    setState(() {
      value = Color.fromARGB(
          255, _n(r, 255).round(), _n(g, 255).round(), _n(b, 255).round());
      _sync();
    });
  }

  void _hex() {
    final text = hex.text.replaceAll('#', '');
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(text)) {
      setState(() {
        value = Color(int.parse('FF$text', radix: 16));
        _sync();
      });
    }
  }

  void _cmyk() {
    final cc = _n(c, 100) / 100,
        mm = _n(m, 100) / 100,
        yy = _n(y, 100) / 100,
        kk = _n(k, 100) / 100;
    setState(() {
      value = Color.fromARGB(
          255,
          (255 * (1 - cc) * (1 - kk)).round(),
          (255 * (1 - mm) * (1 - kk)).round(),
          (255 * (1 - yy) * (1 - kk)).round());
      _sync();
    });
  }

  Widget _field(
          String label, TextEditingController controller, VoidCallback change,
          {String suffix = ''}) =>
      SizedBox(
          width: 78,
          child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: label,
                  suffixText: suffix,
                  isDense: true,
                  border: const OutlineInputBorder()),
              onSubmitted: (_) => change()));
  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(value);
    return AlertDialog(
        title: const Text('စိတ်ကြိုက်အရောင်'),
        content: SingleChildScrollView(
            child: SizedBox(
                width: 430,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 48,
                          decoration: BoxDecoration(
                              color: value,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black26))),
                      const SizedBox(height: 14),
                      Text('Hue',
                          style: Theme.of(context).textTheme.labelLarge),
                      Slider(
                          value: hsv.hue,
                          max: 360,
                          onChanged: (h) => setState(() {
                                value = HSVColor.fromAHSV(
                                        1, h, hsv.saturation, hsv.value)
                                    .toColor();
                                _sync();
                              })),
                      const Text('RGB'),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _field('R', r, _rgb),
                        _field('G', g, _rgb),
                        _field('B', b, _rgb)
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                          controller: hex,
                          decoration: const InputDecoration(
                              labelText: 'HEX',
                              prefixText: '#',
                              border: OutlineInputBorder()),
                          onSubmitted: (_) => _hex()),
                      const SizedBox(height: 12),
                      const Text('CMYK'),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _field('C', c, _cmyk, suffix: '%'),
                        _field('M', m, _cmyk, suffix: '%'),
                        _field('Y', y, _cmyk, suffix: '%'),
                        _field('K', k, _cmyk, suffix: '%')
                      ])
                    ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ပယ်ဖျက်ရန်')),
          FilledButton(
              onPressed: () => Navigator.pop(context, value),
              child: const Text('ရွေးရန်'))
        ]);
  }
}
