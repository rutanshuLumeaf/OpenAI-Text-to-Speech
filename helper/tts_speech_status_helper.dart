import 'package:flutter/foundation.dart';

import 'event_bus.dart';
import 'events.dart';
import 'subscription_helper.dart';

base class TtsSpeechStatusHelper extends BaseProvider with SubscriptionHelper {
  TtsSpeechStatusHelper() {
    subscriptions
      ..add(
        eventBus.on<AiSpeakingStartedEvent>().listen((event) {
          speakingStarted.value = event;
        }),
      )
      ..add(
        eventBus.on<AiSpeakingEndedEvent>().listen((event) {
          speakingEnded.value = event;
        }),
      );
  }

  final ValueNotifier<AiSpeakingStartedEvent?> speakingStarted =
      ValueNotifier<AiSpeakingStartedEvent?>(null);
  final ValueNotifier<AiSpeakingEndedEvent?> speakingEnded =
      ValueNotifier<AiSpeakingEndedEvent?>(null);

  void reset() {
    speakingStarted.value = null;
    speakingEnded.value = null;
  }

  @override
  void dispose() {
    speakingStarted.dispose();
    speakingEnded.dispose();
    super.dispose();
  }
}
