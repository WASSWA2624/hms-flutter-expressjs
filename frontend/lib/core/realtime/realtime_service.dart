import 'dart:async';
import 'dart:convert';

import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef RealtimeSocketConnector = WebSocketChannel Function(Uri uri);

final class RealtimeService {
  RealtimeService({
    required AppConfig config,
    RealtimeSocketConnector connectSocket = WebSocketChannel.connect,
  }) : _config = config,
       _connectSocket = connectSocket;

  static const Duration _baseReconnectDelay = Duration(milliseconds: 500);
  static const Duration _maxReconnectDelay = Duration(seconds: 10);

  final AppConfig _config;
  final RealtimeSocketConnector _connectSocket;
  final StreamController<RealtimeMessage> _messages =
      StreamController<RealtimeMessage>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _reconnectTimer;
  String? _accessToken;
  bool _disposed = false;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;

  Stream<RealtimeMessage> get messages => _messages.stream;

  Future<void> connect(String accessToken) async {
    if (_disposed) {
      return;
    }

    final String token = accessToken.trim();
    if (token.isEmpty) {
      await disconnect();
      return;
    }

    if (_channel != null && _accessToken == token) {
      return;
    }

    _accessToken = token;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    await _openSocket();
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _accessToken = null;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    await _closeSocket();
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _messages.close();
  }

  static Uri buildWebSocketUri({
    required Uri apiBaseUrl,
    required String accessToken,
  }) {
    final String scheme = switch (apiBaseUrl.scheme.toLowerCase()) {
      'https' => 'wss',
      _ => 'ws',
    };

    return Uri(
      scheme: scheme,
      host: apiBaseUrl.host,
      port: apiBaseUrl.hasPort ? apiBaseUrl.port : null,
      path: '/ws',
      queryParameters: <String, String>{'token': accessToken},
    );
  }

  Future<void> _openSocket() async {
    await _closeSocket();

    final String? token = _accessToken;
    if (_disposed || !_shouldReconnect || token == null || token.isEmpty) {
      return;
    }

    try {
      final WebSocketChannel channel = _connectSocket(
        buildWebSocketUri(apiBaseUrl: _config.apiBaseUrl, accessToken: token),
      );
      _channel = channel;
      _subscription = channel.stream.cast<Object?>().listen(
        _handleSocketMessage,
        onError: (Object error, StackTrace stackTrace) {
          _handleSocketClosed();
        },
        onDone: _handleSocketClosed,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Future<void> _closeSocket() async {
    final StreamSubscription<Object?>? subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      await subscription.cancel();
    }

    final WebSocketChannel? channel = _channel;
    _channel = null;
    if (channel != null) {
      await channel.sink.close();
    }
  }

  void _handleSocketMessage(Object? value) {
    final RealtimeMessage? message = RealtimeMessage.tryDecode(value);
    if (message == null) {
      return;
    }

    if (message.event == RealtimeEvents.authenticated) {
      _reconnectAttempts = 0;
    }

    if (message.event == RealtimeEvents.ping) {
      _sendPong(message.payload);
      return;
    }

    if (!_messages.isClosed) {
      _messages.add(message);
    }
  }

  void _sendPong(Map<String, Object?> pingPayload) {
    final Map<String, Object?> payload = <String, Object?>{
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (pingPayload['pingId'] case final String pingId) 'pingId': pingId,
    };
    final RealtimeMessage message = RealtimeMessage(
      event: RealtimeEvents.pong,
      payload: payload,
    );
    _channel?.sink.add(jsonEncode(message.toJson()));
  }

  void _handleSocketClosed() {
    _subscription = null;
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || !_shouldReconnect || _accessToken == null) {
      return;
    }

    _reconnectTimer?.cancel();
    final Duration delay = _reconnectDelay();
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () {
      unawaited(_openSocket());
    });
  }

  Duration _reconnectDelay() {
    final int multiplier = 1 << _reconnectAttempts.clamp(0, 5);
    final int milliseconds = _baseReconnectDelay.inMilliseconds * multiplier;
    if (milliseconds >= _maxReconnectDelay.inMilliseconds) {
      return _maxReconnectDelay;
    }
    return Duration(milliseconds: milliseconds);
  }
}
