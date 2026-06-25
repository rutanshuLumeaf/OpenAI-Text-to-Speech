class AiSpeakingStartedEvent {
  const AiSpeakingStartedEvent({
    required this.startedAt,
    required this.elapsedFromGenerate,
  });

  final DateTime startedAt;
  final Duration elapsedFromGenerate;
}

class AiSpeakingEndedEvent {
  const AiSpeakingEndedEvent({
    required this.endedAt,
    required this.elapsedFromGenerate,
  });

  final DateTime endedAt;
  final Duration elapsedFromGenerate;
}
