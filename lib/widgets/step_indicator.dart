import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.current});
  final int current;
  static const labels = [
    'ပုံတင်ရန်',
    'နောက်ခံ',
    'အရောင်',
    'အလင်းအမှောင်',
    'ပြင်ဆင်ရန်',
    'အဝတ်အစား',
    'ဒေါင်းလုဒ်'
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final active = i == current;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? const Color(0xffE8F0FF) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: active
                        ? const Color(0xff8FB4FF)
                        : const Color(0xffE0E6F0)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: active
                      ? const Color(0xff2563EB)
                      : const Color(0xffE9EEF7),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              active ? Colors.white : const Color(0xff60708C))),
                ),
                const SizedBox(width: 8),
                Text(labels[i],
                    style: TextStyle(
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: const Color(0xff31415D))),
              ]),
            );
          },
        ),
      );
}
