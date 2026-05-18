import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_service.dart';

void main() {
  group('RealtimeService', () {
    test('builds websocket URLs from HTTP API URLs', () {
      final Uri uri = RealtimeService.buildWebSocketUri(
        apiBaseUrl: Uri.parse('http://127.0.0.1:3000'),
        accessToken: 'token-123',
      );

      expect(uri.toString(), 'ws://127.0.0.1:3000/ws?token=token-123');
    });

    test('builds secure websocket URLs from HTTPS API URLs', () {
      final Uri uri = RealtimeService.buildWebSocketUri(
        apiBaseUrl: Uri.parse('https://api.example.com/api/v1'),
        accessToken: 'token-123',
      );

      expect(uri.toString(), 'wss://api.example.com/ws?token=token-123');
    });
  });
}
