import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/theater/data/dtos/theater_dtos.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('TheaterCasePageDto', () {
    test('decodes paginated theatre-flow snapshots', () {
      const AppPageRequest request = AppPageRequest(pageIndex: 1);
      final TheaterCasePageDto dto = TheaterCasePageDto.fromResponse(
        <String, Object?>{
          'status': 200,
          'data': <Object?>[
            <String, Object?>{
              'id': 'TC-001',
              'scheduled_at': '2026-05-17T08:00:00.000Z',
              'status': 'SCHEDULED',
              'workflow_stage': 'PRE_OP',
              'patient_display_name': 'Jane Doe',
              'patient_display_id': 'PAT-001',
              'encounter_display_id': 'ENC-001',
              'room_display_label': 'Theater 1',
              'checklist_summary': <String, Object?>{
                'completed': 2,
                'total': 4,
              },
              'latest_anesthesia_record': <String, Object?>{
                'id': 'AN-001',
                'record_status': 'DRAFT',
              },
            },
          ],
          'pagination': <String, Object?>{'page': 2, 'limit': 20, 'total': 41},
        },
        request,
      );

      expect(dto.page.request, request);
      expect(dto.page.totalItemCount, 41);
      expect(dto.page.items, hasLength(1));
      expect(dto.page.items.single.id, 'TC-001');
      expect(dto.page.items.single.patientDisplayName, 'Jane Doe');
      expect(dto.page.items.single.checklistCompleted, 2);
      expect(dto.page.items.single.checklistTotal, 4);
      expect(dto.page.items.single.scheduledAt, isA<DateTime>());
    });
  });

  group('TheaterCaseDto', () {
    test('decodes detail collections', () {
      final TheaterCase detail = TheaterCaseDto.fromResponse(<String, Object?>{
        'status': 200,
        'data': <String, Object?>{
          'id': 'TC-002',
          'status': 'IN_PROGRESS',
          'workflow_stage': 'INTRA_OP',
          'checklist_items': <Object?>[
            <String, Object?>{
              'id': 'CHK-001',
              'phase': 'SIGN_IN',
              'item_code': 'CONSENT',
              'item_label': 'Consent confirmed',
              'is_checked': true,
            },
          ],
          'resource_allocations': <Object?>[
            <String, Object?>{
              'id': 'RES-001',
              'resource_type': 'ROOM',
              'resource_label': 'Theater 2',
            },
          ],
          'anesthesia_observations': <Object?>[
            <String, Object?>{
              'id': 'OBS-001',
              'metric_key': 'BP',
              'metric_value': '120/80',
              'unit': 'mmHg',
            },
          ],
          'anesthesia_records': <Object?>[
            <String, Object?>{
              'id': 'AN-002',
              'record_status': 'FINAL',
              'notes': 'Stable',
            },
          ],
          'post_op_notes': <Object?>[
            <String, Object?>{
              'id': 'PO-002',
              'record_status': 'DRAFT',
              'note': 'Recovering',
            },
          ],
          'timeline': <Object?>[
            <String, Object?>{
              'type': 'CASE_STARTED',
              'label': 'Case started',
              'at': '2026-05-17T08:30:00.000Z',
            },
          ],
        },
      }).toEntity();

      expect(detail.id, 'TC-002');
      expect(detail.checklistItems.single.isChecked, isTrue);
      expect(detail.resourceAllocations.single.resourceLabel, 'Theater 2');
      expect(detail.anesthesiaObservations.single.metricValue, '120/80');
      expect(detail.latestAnesthesiaRecord?.recordStatus, 'FINAL');
      expect(detail.latestPostOpNote?.notes, 'Recovering');
      expect(detail.timeline.single.type, 'CASE_STARTED');
    });
  });
}
