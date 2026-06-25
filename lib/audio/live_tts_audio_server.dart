import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class LiveTtsAudioServer {
  LiveTtsAudioServer({required this.contentType});

  final String contentType;
  final List<Uint8List> _pendingChunks = <Uint8List>[];
  final Completer<void> _clientConnected = Completer<void>();

  HttpServer? _server;
  HttpResponse? _response;
  bool _isClosed = false;

  Future<Uri> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handleRequest, onError: (_) => close());

    return Uri.parse('http://127.0.0.1:${server.port}/tts.mp3');
  }

  void addChunk(List<int> chunk) {
    if (_isClosed || chunk.isEmpty) {
      return;
    }

    final bytes = Uint8List.fromList(chunk);
    final response = _response;
    if (response == null) {
      _pendingChunks.add(bytes);
      return;
    }

    response.add(bytes);
  }

  Future<void> close() async {
    if (_isClosed) {
      return;
    }

    _isClosed = true;
    final response = _response;
    if (response != null) {
      await response.flush();
      await response.close();
    }

    _pendingChunks.clear();
    await _server?.close(force: true);
  }

  Future<void> waitForClient({Duration timeout = const Duration(seconds: 5)}) {
    return _clientConnected.future.timeout(timeout);
  }

  void _handleRequest(HttpRequest request) {
    final response = request.response;
    _response = response;

    response.headers.contentType = ContentType.parse(contentType);
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set(HttpHeaders.acceptRangesHeader, 'none');
    response.bufferOutput = false;

    if (!_clientConnected.isCompleted) {
      _clientConnected.complete();
    }

    for (final chunk in _pendingChunks) {
      response.add(chunk);
    }
    _pendingChunks.clear();

    if (_isClosed) {
      unawaited(response.close());
    }
  }
}
