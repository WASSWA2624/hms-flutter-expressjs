import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/workspace/realtime_delta_decoder.dart';
import 'package:hosspi_hms/core/workspace/realtime_sync_action.dart';

void main() {
  test('decodes visit queue entity from nested domain payload', () {
    final RealtimeDelta? delta = RealtimeDeltaDecoder.tryDecode(
      const RealtimeMessage(
        event: RealtimeEvents.visitQueueUpdated,
        payload: <String, Object?>{
          'resource_type': 'visit_queue',
          'payload': <String, Object?>{
            'queue_id': 'queue-1',
            'status': 'WAITING',
            'entity': <String, Object?>{
              'id': 'queue-1',
              'status': 'WAITING',
              'human_friendly_id': 'VIS-001',
            },
          },
        },
      ),
    );

    expect(delta, isNotNull);
    expect(delta!.action, RealtimeSyncAction.upsert);
    expect(delta.entity?['id'], 'queue-1');
  });

  test('decodes OPD flow list entry for local patch', () {
    final RealtimeDelta? delta = RealtimeDeltaDecoder.tryDecode(
      const RealtimeMessage(
        event: RealtimeEvents.opdFlowUpdated,
        payload: <String, Object?>{
          'encounter_id': 'enc-1',
          'list_entry': <String, Object?>{
            'encounter': <String, Object?>{'id': 'enc-1'},
            'flow': <String, Object?>{'stage': 'WAITING_VITALS'},
          },
        },
      ),
    );

    expect(delta, isNotNull);
    expect(delta!.listEntry, isNotNull);
    expect(delta.encounterId, 'enc-1');
  });
}
