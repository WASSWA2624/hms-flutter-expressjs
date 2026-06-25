import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';

void main() {
  group('DischargeWorklistQuery.fromUri', () {
    test('parses admission id from query parameters', () {
      final DischargeWorklistQuery query = DischargeWorklistQuery.fromUri(
        Uri.parse('/discharge?id=ADM-001'),
      );

      expect(query.focusAdmissionId, 'ADM-001');
      expect(query.search, 'ADM-001');
      expect(query.hasRouteTargeting, isTrue);
    });
  });

  group('matchesDischargeStatus', () {
    test('filters pharmacy pending by clearance phase', () {
      const IpdAdmissionSummary item = IpdAdmissionSummary(
        id: 'ADM-001',
        stage: 'DISCHARGE_PLANNED',
        dischargeStatus: 'PLANNED',
        clearancePhase: 'MEDICATION_PENDING',
      );

      expect(
        matchesDischargeStatus(item, DischargeStatusFilter.pharmacyPending),
        isTrue,
      );
      expect(
        matchesDischargeStatus(item, DischargeStatusFilter.billingPending),
        isFalse,
      );
    });
  });

  group('DischargeAdmissionDetail', () {
    test('excludes unsupported clearance domains from blockers', () {
      const DischargeAdmissionDetail detail = DischargeAdmissionDetail(
        ipd: IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'ADM-001',
            stage: 'DISCHARGE_PLANNED',
          ),
          latestDischargeSummary: IpdDischargeSummary(
            id: 'DS-001',
            status: 'PLANNED',
            summary: 'Ready for discharge',
            clearance: IpdDischargeClearance(
              summaryReady: true,
              pendingOrdersReviewed: true,
              pharmacyCleared: true,
              billingCleared: true,
              nursingCleared: true,
              documentsReady: true,
              patientExited: true,
            ),
          ),
        ),
      );

      expect(detail.blockingItems, isEmpty);
      expect(detail.isClearanceComplete, isTrue);
    });

    test('buildSyncClearancePayload marks patient exit', () {
      const DischargeAdmissionDetail detail = DischargeAdmissionDetail(
        ipd: IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'ADM-001',
            stage: 'DISCHARGE_PLANNED',
          ),
          latestDischargeSummary: IpdDischargeSummary(
            id: 'DS-001',
            status: 'PLANNED',
            summary: 'Ready for discharge',
            clearance: IpdDischargeClearance(
              summaryReady: true,
              pendingOrdersReviewed: true,
              pharmacyCleared: true,
              billingCleared: true,
              nursingCleared: true,
              documentsReady: true,
            ),
          ),
        ),
      );

      expect(
        detail.buildSyncClearancePayload(),
        containsPair('patient_exited', true),
      );
    });
  });
}
