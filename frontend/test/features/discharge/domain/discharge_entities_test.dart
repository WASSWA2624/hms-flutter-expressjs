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

    test('parses section from query parameters', () {
      final DischargeWorklistQuery query = DischargeWorklistQuery.fromUri(
        Uri.parse('/discharge?section=planned'),
      );

      expect(query.section, 'planned');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses section and admission id together', () {
      final DischargeWorklistQuery query = DischargeWorklistQuery.fromUri(
        Uri.parse('/discharge?section=completed&id=ADM-001'),
      );

      expect(query.section, 'completed');
      expect(query.focusAdmissionId, 'ADM-001');
      expect(query.hasRouteTargeting, isTrue);
    });
  });

  group('DischargeDeskSection filtering', () {
    const IpdAdmissionSummary planned = IpdAdmissionSummary(
      id: 'ADM-PLANNED',
      displayId: 'ADM-P1',
      patientDisplayName: 'Planned Patient',
      stage: 'DISCHARGE_PLANNED',
      dischargeStatus: 'PLANNED',
      wardDisplayName: 'Ward A',
    );
    const IpdAdmissionSummary pending = IpdAdmissionSummary(
      id: 'ADM-PENDING',
      displayId: 'ADM-S1',
      patientDisplayName: 'Summary Pending',
      stage: 'ADMITTED',
      dischargeStatus: 'SUMMARY_PENDING',
      wardDisplayName: 'Ward B',
    );
    const IpdAdmissionSummary completed = IpdAdmissionSummary(
      id: 'ADM-DONE',
      displayId: 'ADM-C1',
      patientDisplayName: 'Completed Patient',
      stage: 'DISCHARGED',
      dischargeStatus: 'COMPLETED',
      wardDisplayName: 'Ward C',
    );

    final List<IpdAdmissionSummary> queue = <IpdAdmissionSummary>[
      planned,
      pending,
      completed,
    ];

    test('classifies planned, pending clearance, and completed rows', () {
      expect(isPlannedDischarge(planned), isTrue);
      expect(isPlannedDischarge(pending), isFalse);
      expect(isCompletedDischarge(completed), isTrue);
      expect(
        queue
            .where(
              (IpdAdmissionSummary item) =>
                  !isCompletedDischarge(item) && !isPlannedDischarge(item),
            )
            .toList(),
        <IpdAdmissionSummary>[pending],
      );
      expect(queue.where(isPlannedDischarge).toList(), <IpdAdmissionSummary>[
        planned,
      ]);
      expect(queue.where(isCompletedDischarge).toList(), <IpdAdmissionSummary>[
        completed,
      ]);
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
      expect(detail.hasBillingClearance, isTrue);
    });

    test('live open invoices override stale billing_cleared flag', () {
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
        invoices: <DischargeRelatedRecord>[
          DischargeRelatedRecord(
            id: 'inv-1',
            kind: 'invoice',
            status: 'ISSUED',
            billingStatus: 'ISSUED',
          ),
        ],
      );

      expect(detail.hasBillingClearance, isFalse);
      expect(detail.effectiveClearance.billingCleared, isFalse);
      expect(
        detail.blockingItems.map((DischargeClearanceItem i) => i.code),
        contains(DischargeClearanceCode.billing),
      );
    });

    test('billing data unavailable blocks finalize gate', () {
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
        billingDataUnavailable: true,
      );

      expect(detail.hasBillingClearance, isFalse);
      expect(
        detail.blockingItems.map((DischargeClearanceItem i) => i.code),
        contains(DischargeClearanceCode.billing),
      );
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
      expect(
        detail.buildSyncClearancePayload(),
        containsPair('billing_cleared', true),
      );
    });
  });
}
