import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_encounter_clinical_services.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OPD encounter context', () {
    late AppLocalizations l10n;

    setUp(() async {
      await initializeDateFormatting('en');
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('buildOpdEncounterSummaryPairs includes copyable identifiers', () {
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'flow-1',
        publicId: 'ENC0000001',
        patientDisplayName: 'Wilson Wasswa',
        patientIdentifier: 'PAT0000001',
        stage: 'IN_LAB',
        displayCode: 'IN_LAB',
        displayNextStep: 'PROCESS_LAB',
        nextStep: 'PROCESS_LAB',
        consultationPaid: true,
        consultationPaidAmount: 30000,
        consultationCurrency: 'UGX',
        consultationPaymentStatus: 'PAID',
        providerDisplayName: 'Jordan Demo',
      );

      final List<OpdEncounterSummaryPair> pairs = buildOpdEncounterSummaryPairs(
        l10n: l10n,
        flow: flow,
        billing: const OpdBillingDisplay(
          state: OpdBillingState.paid,
          statusLabel: 'Paid',
          label: 'Paid',
          tone: AppWorkspaceStatusTone.success,
          amountLabel: r'$30,000.00',
        ),
      );

      expect(
        pairs.any(
          (OpdEncounterSummaryPair pair) =>
              pair.label == l10n.opdPatientIdLabel &&
              pair.copyable &&
              pair.value == 'PAT0000001',
        ),
        isTrue,
      );
      expect(
        pairs.any(
          (OpdEncounterSummaryPair pair) =>
              pair.label == l10n.opdEncounterIdLabel &&
              pair.copyable &&
              pair.value == 'ENC0000001',
        ),
        isTrue,
      );
      expect(
        pairs.any(
          (OpdEncounterSummaryPair pair) =>
              pair.label == l10n.opdCurrentStageLabel &&
              pair.value == l10n.opdStatusInLabLabel,
        ),
        isTrue,
      );
    });

    test('buildOpdVisitJourneyLabel renders timeline steps', () {
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'flow-1',
        arrivalMode: 'WALK_IN',
        stage: 'IN_LAB',
        displayCode: 'IN_LAB',
      );
      final OpdFlowDetail detail = OpdFlowDetail(
        summary: flow,
        timeline: const <OpdTimelineItem>[
          OpdTimelineItem(action: 'RECORD_VITALS', stage: 'WAITING_VITALS'),
          OpdTimelineItem(
            action: 'DOCTOR_REVIEW',
            stage: 'WAITING_DOCTOR_REVIEW',
          ),
        ],
      );

      final String journey = buildOpdVisitJourneyLabel(
        l10n: l10n,
        flow: flow,
        detail: detail,
      );

      expect(journey, contains(l10n.opdArrivalModeWalkInLabel));
      expect(journey, contains('\u2192'));
      expect(journey, contains(l10n.opdStatusInLabLabel));
    });

    test('buildOpdClinicalServiceRows sorts lab orders chronologically', () {
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'flow-1',
        stage: 'IN_LAB',
        displayCode: 'IN_LAB',
      );
      final OpdFlowDetail detail = OpdFlowDetail(
        summary: flow,
        labOrders: <OpdRelatedRecord>[
          OpdRelatedRecord(
            id: 'LAB0000007',
            kind: 'LAB',
            status: 'IN_PROGRESS',
            occurredAt: DateTime(2026, 7, 7, 11, 30),
          ),
          OpdRelatedRecord(
            id: 'LAB0000004',
            kind: 'LAB',
            status: 'COMPLETED',
            occurredAt: DateTime(2026, 7, 7, 10, 30),
          ),
        ],
      );

      final List<OpdClinicalServiceRow> rows = buildOpdClinicalServiceRows(
        l10n: l10n,
        locale: const Locale('en'),
        detail: detail,
        flow: flow,
      );

      expect(rows, hasLength(2));
      expect(rows.first.serviceLabel, 'LAB0000004');
      expect(rows.last.serviceLabel, 'LAB0000007');
      expect(
        opdClinicalServiceLocationLabel(
          l10n: l10n,
          record: detail.labOrders.first,
          flow: flow,
          serviceKind: 'LAB',
        ),
        l10n.opdServiceLocationInLabLabel,
      );
    });
  });
}
