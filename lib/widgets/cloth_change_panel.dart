import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'image_uploader.dart';

class ClothChangePanel extends StatelessWidget {
  const ClothChangePanel({super.key, this.garment, required this.onGarment, required this.onGenerate});
  final Uint8List? garment; final ValueChanged<Uint8List> onGarment; final VoidCallback onGenerate;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ImageHub အတွက် အတည်ပြုထားသော public API မရှိသေးသောကြောင့် ပုံအတု မဖန်တီးပါ။'), const SizedBox(height: 12), const Text('အဝတ်အစားပုံ'), ImageUploader(onImage: (bytes, _) => onGarment(bytes)), if (garment != null) Padding(padding: const EdgeInsets.only(top: 8), child: Image.memory(garment!, height: 100)), const SizedBox(height: 12), FilledButton(onPressed: garment == null ? null : onGenerate, child: const Text('အဝတ်အစားပြောင်းရန်'))]);
}
