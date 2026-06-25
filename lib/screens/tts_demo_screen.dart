import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/live_tts_audio_server.dart';
import '../helper/event_bus.dart';
import '../helper/events.dart';
import '../helper/tts_speech_status_helper.dart';
import '../services/openai_tts_service.dart';

class TtsDemoScreen extends StatefulWidget {
  const TtsDemoScreen({super.key});

  @override
  State<TtsDemoScreen> createState() => _TtsDemoScreenState();
}

class _TtsDemoScreenState extends State<TtsDemoScreen> {
  final TextEditingController _textController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OpenAiTtsService _ttsService = OpenAiTtsService();
  final TtsSpeechStatusHelper _speechStatusHelper = TtsSpeechStatusHelper();

  final ValueNotifier<bool> _hasText = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _errorMessage = ValueNotifier<String?>(null);
  final ValueNotifier<Duration?> _generationTime = ValueNotifier<Duration?>(
    null,
  );
  final ValueNotifier<Duration?> _firstVoiceTime = ValueNotifier<Duration?>(
    null,
  );

  static const String _demoModel = OpenAiTtsService.defaultModel;
  static const String _demoVoice = OpenAiTtsService.defaultVoice;
  static const String _demoResponseFormat =
      OpenAiTtsService.defaultResponseFormat;
  static const double _demoSpeed = OpenAiTtsService.defaultSpeed;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  DateTime? _generationStartedAt;
  bool _speakingStartedEventSent = false;
  bool _speakingEndedEventSent = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      _handlePlayerStateChanged,
    );
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChanged);
    _playerStateSubscription?.cancel();
    _textController.dispose();
    _audioPlayer.dispose();
    _ttsService.dispose();
    _speechStatusHelper.dispose();
    _hasText.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    _generationTime.dispose();
    _firstVoiceTime.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    _hasText.value = _textController.text.trim().isNotEmpty;
  }

  void _handlePlayerStateChanged(PlayerState state) {
    final generationStartedAt = _generationStartedAt;
    if (generationStartedAt == null) {
      return;
    }

    final isReadyAndPlaying =
        state.playing && state.processingState == ProcessingState.ready;
    if (isReadyAndPlaying && !_speakingStartedEventSent) {
      _speakingStartedEventSent = true;
      final startedAt = DateTime.now();
      eventBus.fire(
        AiSpeakingStartedEvent(
          startedAt: startedAt,
          elapsedFromGenerate: startedAt.difference(generationStartedAt),
        ),
      );
    }

    if (_speakingStartedEventSent &&
        !_speakingEndedEventSent &&
        state.processingState == ProcessingState.completed) {
      _fireSpeakingEndedEvent();
    }
  }

  Future<void> _generateSpeech() async {
    final stopwatch = Stopwatch()..start();
    _generationStartedAt = DateTime.now();
    _speakingStartedEventSent = false;
    _speakingEndedEventSent = false;
    _speechStatusHelper.reset();

    final audioServer = LiveTtsAudioServer(
      contentType: _contentTypeForFormat(_demoResponseFormat),
    );

    _isLoading.value = true;
    _errorMessage.value = null;
    _generationTime.value = null;
    _firstVoiceTime.value = null;

    var hasReceivedFirstChunk = false;
    var completed = false;

    try {
      await _audioPlayer.stop();
      final streamUri = await audioServer.start();
      await _audioPlayer.setUrl(streamUri.toString(), preload: false);
      unawaited(_startAutoPlayback());

      final events = _ttsService.streamSpeech(
        text: _textController.text,
        model: _demoModel,
        voice: _demoVoice,
        responseFormat: _demoResponseFormat,
        speed: _demoSpeed,
      );

      await for (final event in events) {
        switch (event) {
          case OpenAiTtsAudioChunk(:final bytes):
            audioServer.addChunk(bytes);

            if (!hasReceivedFirstChunk) {
              hasReceivedFirstChunk = true;
              _firstVoiceTime.value = stopwatch.elapsed;
            }
          case OpenAiTtsStreamComplete():
            completed = true;
            _generationTime.value = stopwatch.elapsed;
            await audioServer.close();
        }
      }
    } catch (error) {
      _errorMessage.value = error.toString();
    } finally {
      stopwatch.stop();
      if (!completed) {
        await audioServer.close();
        _generationTime.value = stopwatch.elapsed;
      }
      _isLoading.value = false;
    }
  }

  Future<void> _startAutoPlayback() async {
    try {
      _errorMessage.value = null;
      await _audioPlayer.play();
    } catch (error) {
      _errorMessage.value = 'Could not start streaming playback: $error';
    }
  }

  Future<void> _play() async {
    if (_audioPlayer.audioSource == null) {
      _errorMessage.value = 'Generate speech before playing audio.';
      return;
    }

    _errorMessage.value = null;
    await _audioPlayer.play();
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
  }

  Future<void> _stopAndReset() async {
    _fireSpeakingEndedEvent();
    await _audioPlayer.stop();
    await _audioPlayer.seek(Duration.zero);
  }

  void _fireSpeakingEndedEvent() {
    final generationStartedAt = _generationStartedAt;
    if (generationStartedAt == null ||
        !_speakingStartedEventSent ||
        _speakingEndedEventSent) {
      return;
    }

    _speakingEndedEventSent = true;
    final endedAt = DateTime.now();
    eventBus.fire(
      AiSpeakingEndedEvent(
        endedAt: endedAt,
        elapsedFromGenerate: endedAt.difference(generationStartedAt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenAI Text-to-Speech')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  'Text to speech demo',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Model: $_demoModel   Voice: $_demoVoice   Format: $_demoResponseFormat   Speed: $_demoSpeed',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _textController,
                  minLines: 5,
                  maxLines: 10,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Text',
                    hintText: 'Type something for OpenAI to speak...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: _isLoading,
                  builder: (context, isLoading, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _hasText,
                      builder: (context, hasText, _) {
                        return FilledButton.icon(
                          onPressed: hasText && !isLoading
                              ? _generateSpeech
                              : null,
                          icon: isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.record_voice_over),
                          label: Text(
                            isLoading ? 'Generating...' : 'Generate Speech',
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String?>(
                  valueListenable: _errorMessage,
                  builder: (context, message, _) {
                    if (message == null) {
                      return const SizedBox.shrink();
                    }

                    return _StatusPanel(
                      icon: Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      text: message,
                    );
                  },
                ),
                const SizedBox(height: 16),
                _AudioControls(
                  player: _audioPlayer,
                  onPlay: _play,
                  onPause: _pause,
                  onStop: _stopAndReset,
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: _isLoading,
                  builder: (context, isLoading, _) {
                    return ValueListenableBuilder<Duration?>(
                      valueListenable: _firstVoiceTime,
                      builder: (context, elapsed, _) {
                        if (!isLoading && elapsed == null) {
                          return const SizedBox.shrink();
                        }

                        return _StatusPanel(
                          icon: Icons.graphic_eq,
                          color: Theme.of(context).colorScheme.tertiary,
                          text: elapsed == null
                              ? 'Waiting for first audio data...'
                              : 'First audio data: ${_formatDuration(elapsed)}',
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<Duration?>(
                  valueListenable: _generationTime,
                  builder: (context, elapsed, _) {
                    if (elapsed == null) {
                      return const SizedBox.shrink();
                    }

                    return _StatusPanel(
                      icon: Icons.timer_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                      text:
                          'Total stream finished: ${_formatDuration(elapsed)}',
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<AiSpeakingStartedEvent?>(
                  valueListenable: _speechStatusHelper.speakingStarted,
                  builder: (context, event, _) {
                    return _StatusPanel(
                      icon: Icons.volume_up_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      text: event == null
                          ? 'AI speaking started: waiting...'
                          : 'AI speaking started: ${_formatDateTime(event.startedAt)} (${_formatDuration(event.elapsedFromGenerate)} after Generate)',
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<AiSpeakingEndedEvent?>(
                  valueListenable: _speechStatusHelper.speakingEnded,
                  builder: (context, event, _) {
                    return _StatusPanel(
                      icon: Icons.volume_off_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      text: event == null
                          ? 'AI speaking ended: waiting...'
                          : 'AI speaking ended: ${_formatDateTime(event.endedAt)} (${_formatDuration(event.elapsedFromGenerate)} after Generate)',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(2)} seconds';
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    final millisecond = dateTime.millisecond.toString().padLeft(3, '0');

    return '$hour:$minute:$second.$millisecond';
  }

  String _contentTypeForFormat(String responseFormat) {
    return switch (responseFormat) {
      'aac' => 'audio/aac',
      'flac' => 'audio/flac',
      'opus' => 'audio/ogg',
      'pcm' => 'audio/pcm',
      'wav' => 'audio/wav',
      _ => 'audio/mpeg',
    };
  }
}

class _AudioControls extends StatelessWidget {
  const _AudioControls({
    required this.player,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
  });

  final AudioPlayer player;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final processingState = snapshot.data?.processingState;
        final hasAudio = player.audioSource != null;
        final isPlaying = snapshot.data?.playing ?? false;
        final isBusy =
            processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: hasAudio && !isPlaying && !isBusy ? onPlay : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
            FilledButton.tonalIcon(
              onPressed: hasAudio && isPlaying ? onPause : null,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
            ),
            OutlinedButton.icon(
              onPressed: hasAudio ? onStop : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop / Reset'),
            ),
          ],
        );
      },
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: SelectableText(text)),
        ],
      ),
    );
  }
}
