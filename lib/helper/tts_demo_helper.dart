String formatDuration(Duration duration) {
  final seconds = duration.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(2)} seconds';
}

String formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final second = dateTime.second.toString().padLeft(2, '0');
  final millisecond = dateTime.millisecond.toString().padLeft(3, '0');

  return '$hour:$minute:$second.$millisecond';
}

String contentTypeForFormat(String responseFormat) {
  return switch (responseFormat) {
    'aac' => 'audio/aac',
    'flac' => 'audio/flac',
    'opus' => 'audio/ogg',
    'pcm' => 'audio/pcm',
    'wav' => 'audio/wav',
    _ => 'audio/mpeg',
  };
}

class AiSpeakingStartedEvent {
  const AiSpeakingStartedEvent({required this.startedAt, required this.elapsedFromGenerate});

  final DateTime startedAt;
  final Duration elapsedFromGenerate;
}

class AiSpeakingEndedEvent {
  const AiSpeakingEndedEvent({required this.endedAt, required this.elapsedFromGenerate});

  final DateTime endedAt;
  final Duration elapsedFromGenerate;
}
