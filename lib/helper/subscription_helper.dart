import 'dart:async';

import 'package:flutter/foundation.dart';

abstract base class BaseProvider {
  void dispose() {}
}

base mixin SubscriptionHelper on BaseProvider {
  @visibleForTesting
  @protected
  final List<StreamSubscription<dynamic>> subscriptions =
      <StreamSubscription<dynamic>>[];

  @override
  void dispose() {
    cancelAllSubscriptions();
    super.dispose();
  }

  @protected
  void cancelAllSubscriptions() {
    if (subscriptions.isNotEmpty) {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
      subscriptions.clear();
    }
  }
}
