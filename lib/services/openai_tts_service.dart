import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OpenAiTtsException implements Exception {
  const OpenAiTtsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenAiTtsService {
  OpenAiTtsService({http.Client? client}) : _client = client ?? http.Client();

  static const String defaultModel = 'tts-1';
  static const String defaultVoice = 'coral';
  static const String defaultResponseFormat = 'mp3';
  static const double defaultSpeed = 1.0;

  static final Uri _speechUri = Uri.parse(
    'https://api.openai.com/v1/audio/speech',
  );

  final http.Client _client;

  Stream<OpenAiTtsStreamEvent> streamSpeech({
    required String text,
    String model = defaultModel,
    String voice = defaultVoice,
    String responseFormat = defaultResponseFormat,
    double speed = defaultSpeed,
  }) async* {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw const OpenAiTtsException('Enter text before generating speech.');
    }

    final apiKey = dotenv.env['OPENAI_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw const OpenAiTtsException(
        'Missing OPENAI_API_KEY in the .env file.',
      );
    }

    try {
      final request = http.Request('POST', _speechUri)
        ..headers.addAll(<String, String>{
          HttpHeaders.authorizationHeader: 'Bearer $apiKey',
          HttpHeaders.contentTypeHeader: 'application/json',
        })
        ..body = jsonEncode(<String, Object>{
          'model': model,
          'voice': voice,
          'input': trimmedText,
          'response_format': responseFormat,
          'stream_format': 'audio',
          'speed': speed,
        });

      final response = await _client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorBytes = await response.stream.toBytes();
        throw OpenAiTtsException(
          _readStreamedApiError(response.statusCode, errorBytes),
        );
      }

      var totalBytes = 0;

      await for (final chunk in response.stream) {
        if (chunk.isEmpty) {
          continue;
        }

        final bytes = Uint8List.fromList(chunk);
        totalBytes += bytes.length;
        yield OpenAiTtsAudioChunk(bytes);
      }

      yield OpenAiTtsStreamComplete(totalBytes: totalBytes);
    } on OpenAiTtsException {
      rethrow;
    } on SocketException catch (error) {
      throw OpenAiTtsException('Network error: ${error.message}');
    } on http.ClientException catch (error) {
      throw OpenAiTtsException('HTTP error: ${error.message}');
    } catch (error) {
      throw OpenAiTtsException('Could not stream speech: $error');
    }
  }

  String _readStreamedApiError(int statusCode, List<int> bodyBytes) {
    final fallback = 'OpenAI API error ($statusCode).';

    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map<String, Object?>) {
        final error = decoded['error'];
        if (error is Map<String, Object?>) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return 'OpenAI API error ($statusCode): $message';
          }
        }
      }
    } catch (_) {
      return fallback;
    }

    return fallback;
  }

  void dispose() {
    _client.close();
  }
}

sealed class OpenAiTtsStreamEvent {
  const OpenAiTtsStreamEvent();
}

class OpenAiTtsAudioChunk extends OpenAiTtsStreamEvent {
  const OpenAiTtsAudioChunk(this.bytes);

  final Uint8List bytes;
}

class OpenAiTtsStreamComplete extends OpenAiTtsStreamEvent {
  const OpenAiTtsStreamComplete({required this.totalBytes});

  final int totalBytes;
}
