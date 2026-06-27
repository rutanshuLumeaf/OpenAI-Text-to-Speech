import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/live_tts_audio_server.dart';
import '../helper/tts_demo_helper.dart';
import '../services/openai_tts_service.dart';

class TtsDemoProvider extends ChangeNotifier {
  TtsDemoProvider() {
    textController.addListener(_handleTextChanged);
    _playerStateSubscription = audioPlayer.playerStateStream.listen(_handlePlayerStateChanged);
  }

  final TextEditingController textController = TextEditingController();
  final AudioPlayer audioPlayer = AudioPlayer();
  final OpenAiTtsService ttsService = OpenAiTtsService();

  bool hasText = false;
  bool isLoading = false;
  String? errorMessage;
  Duration? generationTime;
  Duration? firstVoiceTime;
  AiSpeakingStartedEvent? speakingStarted;
  AiSpeakingEndedEvent? speakingEnded;

  static const String demoModel = OpenAiTtsService.defaultModel;
  static const String demoVoice = OpenAiTtsService.defaultVoice;
  static const String demoResponseFormat = OpenAiTtsService.defaultResponseFormat;
  static const double demoSpeed = OpenAiTtsService.defaultSpeed;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  DateTime? _generationStartedAt;
  bool _speakingStartedEventSent = false;
  bool _speakingEndedEventSent = false;

  Future<void> generateSpeech() async {
    final stopwatch = Stopwatch()..start();
    _generationStartedAt = DateTime.now();
    _speakingStartedEventSent = false;
    _speakingEndedEventSent = false;
    speakingStarted = null;
    speakingEnded = null;

    final audioServer = LiveTtsAudioServer(contentType: contentTypeForFormat(demoResponseFormat));

    isLoading = true;
    errorMessage = null;
    generationTime = null;
    firstVoiceTime = null;
    notifyListeners();

    var hasReceivedFirstChunk = false;
    var completed = false;

    try {
      await audioPlayer.stop();
      final streamUri = await audioServer.start();
      await audioPlayer.setUrl(streamUri.toString(), preload: false);
      unawaited(startAutoPlayback());

      final events = ttsService.streamSpeech(
        text: textController.text,
        model: demoModel,
        voice: demoVoice,
        responseFormat: demoResponseFormat,
        speed: demoSpeed,
      );

      await for (final event in events) {
        switch (event) {
          case OpenAiTtsAudioChunk(:final bytes):
            audioServer.addChunk(bytes);

            if (!hasReceivedFirstChunk) {
              hasReceivedFirstChunk = true;
              firstVoiceTime = stopwatch.elapsed;
              notifyListeners();
            }
          case OpenAiTtsStreamComplete():
            completed = true;
            generationTime = stopwatch.elapsed;
            await audioServer.close();
            notifyListeners();
        }
      }
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      stopwatch.stop();
      if (!completed) {
        await audioServer.close();
        generationTime = stopwatch.elapsed;
      }
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startAutoPlayback() async {
    try {
      errorMessage = null;
      await audioPlayer.play();
      notifyListeners();
    } catch (error) {
      errorMessage = 'Could not start streaming playback: $error';
      notifyListeners();
    }
  }

  Future<void> play() async {
    if (audioPlayer.audioSource == null) {
      errorMessage = 'Generate speech before playing audio.';
      notifyListeners();
      return;
    }

    errorMessage = null;
    await audioPlayer.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await audioPlayer.pause();
    notifyListeners();
  }

  Future<void> stopAndReset() async {
    _fireSpeakingEndedEvent();
    await audioPlayer.stop();
    await audioPlayer.seek(Duration.zero);
    notifyListeners();
  }

  void _handleTextChanged() {
    hasText = textController.text.trim().isNotEmpty;
    notifyListeners();
  }

  void _handlePlayerStateChanged(PlayerState state) {
    final generationStartedAt = _generationStartedAt;
    if (generationStartedAt == null) {
      return;
    }

    final isReadyAndPlaying = state.playing && state.processingState == ProcessingState.ready;
    if (isReadyAndPlaying && !_speakingStartedEventSent) {
      _speakingStartedEventSent = true;
      final startedAt = DateTime.now();
      speakingStarted = AiSpeakingStartedEvent(
        startedAt: startedAt,
        elapsedFromGenerate: startedAt.difference(generationStartedAt),
      );
      notifyListeners();
    }

    if (_speakingStartedEventSent && !_speakingEndedEventSent && state.processingState == ProcessingState.completed) {
      _fireSpeakingEndedEvent();
    }
  }

  void _fireSpeakingEndedEvent() {
    final generationStartedAt = _generationStartedAt;
    if (generationStartedAt == null || !_speakingStartedEventSent || _speakingEndedEventSent) {
      return;
    }

    _speakingEndedEventSent = true;
    final endedAt = DateTime.now();
    speakingEnded = AiSpeakingEndedEvent(
      endedAt: endedAt,
      elapsedFromGenerate: endedAt.difference(generationStartedAt),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    textController.removeListener(_handleTextChanged);
    _playerStateSubscription?.cancel();
    textController.dispose();
    audioPlayer.dispose();
    ttsService.dispose();
    super.dispose();
  }
}
