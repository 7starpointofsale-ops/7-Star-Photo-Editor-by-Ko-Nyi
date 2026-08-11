import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const PhotoEditorApp());
class PhotoEditorApp extends StatelessWidget { const PhotoEditorApp({super.key}); @override Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, title: 'Passport Photo Editor', theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0a5c9e)), useMaterial3: true), home: const HomeScreen()); }
