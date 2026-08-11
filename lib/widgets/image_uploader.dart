import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ImageUploader extends StatelessWidget {
  const ImageUploader({super.key, required this.onImage});
  final void Function(Uint8List bytes, String name) onImage;

  Future<void> _pick(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png'], withData: true);
    if (picked == null) return;
    final file = picked.files.single;
    if (file.bytes == null || file.size == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('မမှန်ကန်သော ပုံဖိုင်ဖြစ်ပါသည်။')));
      return;
    }
    if (file.size > 15 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ပုံဖိုင်အရွယ်အစား 15 MB ထက် မကျော်ရပါ။')));
      return;
    }
    onImage(file.bytes!, file.name);
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.add_a_photo_outlined), label: const Text('ပုံရွေးရန်'),
    onPressed: () => _pick(context),
  );
}
