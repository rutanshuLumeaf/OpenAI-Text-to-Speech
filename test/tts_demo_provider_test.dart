import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tts_demo/providers/tts_demo_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provider starts with empty text and no loading state', () {
    final provider = TtsDemoProvider();

    expect(provider.textController.text, isEmpty);
    expect(provider.hasText, isFalse);
    expect(provider.isLoading, isFalse);

    provider.dispose();
  });
}
