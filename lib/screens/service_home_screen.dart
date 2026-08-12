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
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('7 Star Photo Editor by Ko Nyi',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('လိုအပ်သော service ကို ရွေးချယ်ပါ။'),
                  const SizedBox(height: 24),
                  _ServiceCard(
                    icon: Icons.badge_outlined,
                    title: 'လိုင်စင်ပုံပြင်မယ်',
                    subtitle:
                        'Passport / License ပုံ နောက်ခံ၊ အရောင်၊ အလင်းအမှောင်နှင့် အရွယ်အစား ပြင်ဆင်ရန်',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HomeScreen())),
                  ),
                  const SizedBox(height: 14),
                  _ServiceCard(
                    icon: Icons.document_scanner_outlined,
                    title: 'Scan Document သန့်မယ်',
                    subtitle:
                        'ဖုန်းဖြင့်ရိုက်ထားသော စာရွက်များကို local contrast enhancement ဖြင့် သန့်စင်ရန်',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const DocumentContrastScreen())),
                  ),
                  const SizedBox(height: 14),
                  _ServiceCard(
                    icon: Icons.text_fields,
                    title: 'Image to Text',
                    subtitle: 'OCR service ကို သီးခြားစီအသုံးပြုရန်',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ImageToTextScreen())),
                  ),
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
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Icon(icon,
                  size: 42, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 18),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(subtitle),
                  ])),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}
