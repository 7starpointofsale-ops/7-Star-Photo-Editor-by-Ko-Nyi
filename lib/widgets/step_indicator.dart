import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.current});
  final int current;
  static const labels = ['ပုံတင်ရန်', 'နောက်ခံ', 'အရောင်', 'အလင်းအမှောင်', 'ပြင်ဆင်ရန်', 'အဝတ်အစား', 'ဒေါင်းလုဒ်'];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: labels.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) => Chip(
        avatar: CircleAvatar(backgroundColor: i == current ? Theme.of(context).colorScheme.primary : null, child: Text('${i + 1}', style: TextStyle(color: i == current ? Colors.white : null))),
        label: Text(labels[i]),
        backgroundColor: i == current ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
    ),
  );
}
