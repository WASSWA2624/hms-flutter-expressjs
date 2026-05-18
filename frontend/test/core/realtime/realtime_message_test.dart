import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';

void main() {
  group('RealtimeMessage', () {
    test('decodes valid websocket message payloads', () {
      final RealtimeMessage? message = RealtimeMessage.tryDecode(
        '{"event":"diagnostic.lab_workflow_updated",'
        '"payload":{"patient_id":"PAT0001","status":"ORDERED"}}',
      );

      expect(message?.event, 'diagnostic.lab_workflow_updated');
      expect(message?.payload['patient_id'], 'PAT0001');
      expect(message?.payload['status'], 'ORDERED');
    });

    test('ignores malformed websocket messages', () {
      expect(RealtimeMessage.tryDecode('not-json'), isNull);
      expect(RealtimeMessage.tryDecode('{"payload":{}}'), isNull);
      expect(RealtimeMessage.tryDecode(null), isNull);
    });
  });
}
