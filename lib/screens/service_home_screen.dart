import 'package:flutter/material.dart';

import 'document_contrast_screen.dart';
import 'home_screen.dart';
import 'image_to_text_screen.dart';

/// The public entry point keeps the independent services separate.  The
/// existing passport editor itself remains in [HomeScreen].
class ServiceHomeScreen extends StatelessWidget {
  const ServiceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('7 Star Photo Editor by Ko Nyi')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                children: [
                  const _Hero(),
                  const SizedBox(height: 28),
                  Text('Services',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xff13213A))),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final cards = [
                      _ServiceCard(
                          icon: Icons.badge_outlined,
                          accent: const Color(0xff2563EB),
                          title: 'လိုင်စင်ပုံပြင်မယ်',
                          subtitle:
                              'Passport / License ပုံ နောက်ခံ၊ အရောင်၊ အလင်းအမှောင်နှင့် အရွယ်အစား ပြင်ဆင်ရန်',
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const HomeScreen()))),
                      _ServiceCard(
                          icon: Icons.document_scanner_outlined,
                          accent: const Color(0xff059669),
                          title: 'Scan Document သန့်မယ်',
                          subtitle:
                              'ဖုန်းဖြင့်ရိုက်ထားသော စာရွက်များကို local contrast enhancement ဖြင့် သန့်စင်ရန်',
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const DocumentContrastScreen()))),
                      _ServiceCard(
                          icon: Icons.text_fields,
                          accent: const Color(0xff7C3AED),
                          title: 'Image to Text',
                          subtitle: 'OCR service ကို သီးခြားစီအသုံးပြုရန်',
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const ImageToTextScreen()))),
                    ];
                    return wide
                        ? Row(children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              Expanded(child: cards[i]),
                              if (i < cards.length - 1)
                                const SizedBox(width: 16)
                            ]
                          ])
                        : Column(children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              cards[i],
                              if (i < cards.length - 1)
                                const SizedBox(height: 14)
                            ]
                          ]);
                  }),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.accent,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: accent)),
              const SizedBox(height: 22),
              Text(title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff13213A))),
              const SizedBox(height: 8),
              Text(subtitle,
                  style:
                      const TextStyle(height: 1.45, color: Color(0xff5B6880))),
              const SizedBox(height: 20),
              Row(children: [
                Text('Open service',
                    style:
                        TextStyle(color: accent, fontWeight: FontWeight.w700)),
                const Spacer(),
                Icon(Icons.arrow_forward, color: accent)
              ]),
            ]),
          ),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
              colors: [Color(0xff102A56), Color(0xff1D4ED8)]),
        ),
        child: Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('7 Star Photo Editor\nby Ko Nyi',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 12),
                Text(
                    'Photo, document နှင့် text tools များကို လွယ်ကူစွာ အသုံးပြုနိုင်သော workspace',
                    style: TextStyle(color: Color(0xffDCE8FF), height: 1.45)),
              ])),
          const SizedBox(width: 18),
          Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 32)),
        ]),
      );
}
