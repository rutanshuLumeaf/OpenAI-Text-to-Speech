import 'dart:async';

final eventBus = _EventBus();

class _EventBus {
  final StreamController<dynamic> _streamController;

  StreamController<dynamic> get streamController => _streamController;

  _EventBus({bool sync = false})
    : _streamController = StreamController<dynamic>.broadcast(sync: sync);

  Stream<T> on<T>() {
    if (T == dynamic) {
      return streamController.stream as Stream<T>;
    } else {
      return streamController.stream.where((event) => event is T).cast<T>();
    }
  }

  void fire(Object event) {
    streamController.add(event);
  }

  void destroy() {
    _streamController.close();
  }
}
