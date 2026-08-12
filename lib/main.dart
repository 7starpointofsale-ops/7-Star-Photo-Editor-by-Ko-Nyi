import 'package:flutter/material.dart';
import 'screens/service_home_screen.dart';

void main() => runApp(const PhotoEditorApp());

class PhotoEditorApp extends StatelessWidget {
  const PhotoEditorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '7 Star Photo Editor by Ko Nyi',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0a5c9e)),
          useMaterial3: true,
        ),
        home: const ServiceHomeScreen(),
      );
}
