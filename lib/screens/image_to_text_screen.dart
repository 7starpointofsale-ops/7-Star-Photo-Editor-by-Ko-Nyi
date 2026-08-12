import 'package:flutter/material.dart';

/// OCR requires a deliberately chosen local OCR engine or a user-configured
/// provider.  No third-party key or unverified endpoint is embedded here.
class ImageToTextScreen extends StatelessWidget {
  const ImageToTextScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Image to Text')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'OCR engine ကို မသတ်မှတ်ရသေးပါ။ Privacy-safe local OCR implementation ကို သီးခြားထည့်သွင်းမည်ဖြစ်ပြီး API key သို့မဟုတ် fake result မသုံးပါ။',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
