import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/tts_demo_provider.dart';
import 'screens/tts_demo_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  runApp(const TtsDemoApp());
}

class TtsDemoApp extends StatelessWidget {
  const TtsDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenAI TTS Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B5F)), useMaterial3: true),
      home: ChangeNotifierProvider(create: (_) => TtsDemoProvider(), child: const TtsDemoScreen()),
    );
  }
}
