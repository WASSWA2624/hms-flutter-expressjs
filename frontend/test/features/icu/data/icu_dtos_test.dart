import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/icu/data/dtos/icu_dtos.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('IcuPatientSummaryDto', () {
    test('maps board queue card fields including source and ICU start', () {
      final IcuPatientSummary summary = IcuPatientSummaryDto.fromBoardEntry(
        <String, Object?>{
          'id': 'ADM-1',
          'display_id': 'ADM0001',
          'patient_display_name': 'Jane Doe',
          'icu_status': 'ACTIVE',
          'has_critical_alert': true,
          'critical_severity': 'HIGH',
          'source_kind': 'EMERGENCY',
          'encounter_type': 'EMERGENCY_IPD',
          'icu_stay_started_at': '2026-06-25T08:00:00.000Z',
          'admitted_at': '2026-06-24T12:00:00.000Z',
          'flow': <String, Object?>{
            'stage': 'ADMITTED_IN_BED',
            'transfer_status': 'REQUESTED',
          },
        },
      ).toEntity();

      expect(summary.admissionId, 'ADM-1');
      expect(summary.displayId, 'ADM0001');
      expect(summary.sourceKind, 'EMERGENCY');
      expect(summary.encounterType, 'EMERGENCY_IPD');
      expect(
        summary.icuStayStartedAt,
        DateTime.parse('2026-06-25T08:00:00.000Z'),
      );
      expect(summary.showsBillingDeferredBadge, isTrue);
      expect(summary.boardIcuStartAt, summary.icuStayStartedAt);
      expect(summary.hasOpenTransfer, isTrue);
    });
  });

  group('IcuBoardPageDto', () {
    test('parses paginated ICU board response', () {
      const AppPageRequest request = AppPageRequest();
      final IcuBoardPageDto dto = IcuBoardPageDto.fromResponse(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'ADM-2',
              'display_id': 'ADM0002',
              'icu_status': 'ACTIVE',
            },
          ],
          'pagination': <String, Object?>{'total': 1},
        },
        request,
      );

      expect(dto.page.items.single.displayId, 'ADM0002');
      expect(dto.page.totalItemCount, 1);
    });
  });

  group('IcuPatientDetailDto', () {
    test('maps source context and ICU overlay on detail', () {
      final IcuPatientDetail detail = IcuPatientDetailDto.fromResponse(
        <String, Object?>{
          'data': <String, Object?>{
            'id': 'ADM-3',
            'display_id': 'ADM0003',
            'encounter': <String, Object?>{
              'id': 'ENC-1',
              'encounter_type': 'OPD_IPD',
            },
            'source_context': <String, Object?>{
              'kind': 'OPD',
              'encounter_type': 'OPD_IPD',
              'encounter_status': 'ADMITTED',
            },
            'icu': <String, Object?>{
              'status': 'ACTIVE',
              'active_stay': <String, Object?>{
                'id': 'ICU-1',
                'started_at': '2026-06-25T09:00:00.000Z',
              },
              'critical_alert_summary': <String, Object?>{'total': 0},
            },
          },
        },
      ).toEntity();

      expect(detail.summary.displayId, 'ADM0003');
      expect(detail.sourceContext?.kind, 'OPD');
      expect(detail.sourceContextLabel, 'OPD');
      expect(detail.activeStay?.id, 'ICU-1');
      expect(
        detail.icuStayStartedAt,
        DateTime.parse('2026-06-25T09:00:00.000Z'),
      );
    });
  });
}
