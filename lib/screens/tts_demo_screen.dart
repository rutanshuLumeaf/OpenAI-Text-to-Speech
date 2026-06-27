import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../helper/tts_demo_helper.dart';
import '../providers/tts_demo_provider.dart';

class TtsDemoScreen extends StatelessWidget {
  const TtsDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TtsDemoProvider>();
    final hasText = context.select<TtsDemoProvider, bool>((value) => value.hasText);
    final isLoading = context.select<TtsDemoProvider, bool>((value) => value.isLoading);
    final errorMessage = context.select<TtsDemoProvider, String?>((value) => value.errorMessage);
    final generationTime = context.select<TtsDemoProvider, Duration?>((value) => value.generationTime);
    final firstVoiceTime = context.select<TtsDemoProvider, Duration?>((value) => value.firstVoiceTime);
    final speakingStarted = context.select<TtsDemoProvider, AiSpeakingStartedEvent?>((value) => value.speakingStarted);
    final speakingEnded = context.select<TtsDemoProvider, AiSpeakingEndedEvent?>((value) => value.speakingEnded);

    return Scaffold(
      appBar: AppBar(title: const Text('OpenAI Text-to-Speech')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text('Text to speech demo', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Model: ${TtsDemoProvider.demoModel}   Voice: ${TtsDemoProvider.demoVoice}   Format: ${TtsDemoProvider.demoResponseFormat}   Speed: ${TtsDemoProvider.demoSpeed}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: provider.textController,
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
                FilledButton.icon(
                  onPressed: hasText && !isLoading ? provider.generateSpeech : null,
                  icon: isLoading
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.record_voice_over),
                  label: Text(isLoading ? 'Generating...' : 'Generate Speech'),
                ),
                const SizedBox(height: 16),
                if (errorMessage != null)
                  _StatusPanel(
                    icon: Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    text: errorMessage,
                  )
                else
                  const SizedBox.shrink(),
                const SizedBox(height: 16),
                _AudioControls(
                  player: provider.audioPlayer,
                  onPlay: provider.play,
                  onPause: provider.pause,
                  onStop: provider.stopAndReset,
                ),
                const SizedBox(height: 16),
                if (!isLoading && firstVoiceTime == null)
                  const SizedBox.shrink()
                else
                  _StatusPanel(
                    icon: Icons.graphic_eq,
                    color: Theme.of(context).colorScheme.tertiary,
                    text: firstVoiceTime == null
                        ? 'Waiting for first audio data...'
                        : 'First audio data: ${formatDuration(firstVoiceTime)}',
                  ),
                const SizedBox(height: 16),
                if (generationTime == null)
                  const SizedBox.shrink()
                else
                  _StatusPanel(
                    icon: Icons.timer_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                    text: 'Total stream finished: ${formatDuration(generationTime)}',
                  ),
                const SizedBox(height: 16),
                _StatusPanel(
                  icon: Icons.volume_up_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  text: speakingStarted == null
                      ? 'AI speaking started: waiting...'
                      : 'AI speaking started: ${formatDateTime(speakingStarted.startedAt)} (${formatDuration(speakingStarted.elapsedFromGenerate)} after Generate)',
                ),
                const SizedBox(height: 16),
                _StatusPanel(
                  icon: Icons.volume_off_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  text: speakingEnded == null
                      ? 'AI speaking ended: waiting...'
                      : 'AI speaking ended: ${formatDateTime(speakingEnded.endedAt)} (${formatDuration(speakingEnded.elapsedFromGenerate)} after Generate)',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioControls extends StatelessWidget {
  const _AudioControls({required this.player, required this.onPlay, required this.onPause, required this.onStop});

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
        final isBusy = processingState == ProcessingState.loading || processingState == ProcessingState.buffering;

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
  const _StatusPanel({required this.icon, required this.color, required this.text});

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
