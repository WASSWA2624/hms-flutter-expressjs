import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_scope_navigation.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_actions.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_columns.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('nursingScopeToQueryValue / nursingScopeFromQueryValue', () {
    test('round-trips every queue scope', () {
      for (final NursingQueueScope scope in NursingQueueScope.values) {
        final String query = nursingScopeToQueryValue(scope);
        expect(nursingScopeFromQueryValue(query), scope);
      }
    });

    test('accepts alias query values', () {
      expect(
        nursingScopeFromQueryValue('assigned_ward'),
        NursingQueueScope.assignedWard,
      );
      expect(
        nursingScopeFromQueryValue('medication'),
        NursingQueueScope.medicationDue,
      );
      expect(nursingScopeFromQueryValue('critical'), NursingQueueScope.urgent);
      expect(
        nursingScopeFromQueryValue('discharge'),
        NursingQueueScope.dischargePending,
      );
      expect(nursingScopeFromQueryValue(null), NursingQueueScope.all);
      expect(nursingScopeFromQueryValue(''), NursingQueueScope.all);
      expect(nursingScopeFromQueryValue('unknown'), isNull);
    });

    test('omits all as the default URL scope value', () {
      expect(nursingScopeToQueryValue(NursingQueueScope.all), 'all');
      expect(nursingScopeToQueryValue(NursingQueueScope.urgent), 'urgent');
    });
  });

  group('nursingResolveNextActionKind / label', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    const NursingPatientSummary routine = NursingPatientSummary(
      id: 'adm-1',
      admissionId: 'adm-1',
      displayId: 'ADM-1',
      patientDisplayName: 'Routine',
      stage: 'ADMITTED_IN_BED',
      admissionStatus: 'ADMITTED_IN_BED',
    );

    const NursingPatientSummary medDue = NursingPatientSummary(
      id: 'adm-2',
      admissionId: 'adm-2',
      displayId: 'ADM-2',
      patientDisplayName: 'Med Due',
      stage: 'ADMITTED_IN_BED',
      admissionStatus: 'ADMITTED_IN_BED',
      medicationDueCount: 1,
    );

    const NursingPatientSummary urgent = NursingPatientSummary(
      id: 'adm-3',
      admissionId: 'adm-3',
      displayId: 'ADM-3',
      patientDisplayName: 'Urgent',
      stage: 'ADMITTED_IN_BED',
      admissionStatus: 'ADMITTED_IN_BED',
      hasCriticalAlert: true,
    );

    test('resolves one primary next-action per scope and row', () {
      expect(
        nursingResolveNextActionKind(routine, NursingQueueScope.all),
        NursingNextActionKind.vitals,
      );
      expect(
        nursingResolveNextActionLabel(l10n, routine, NursingQueueScope.all),
        l10n.nursingActionRecordVitals,
      );
      expect(
        nursingResolveNextActionKind(medDue, NursingQueueScope.medicationDue),
        NursingNextActionKind.medication,
      );
      expect(
        nursingResolveNextActionLabel(
          l10n,
          medDue,
          NursingQueueScope.medicationDue,
        ),
        l10n.nursingActionAdministerMedication,
      );
      expect(
        nursingResolveNextActionKind(urgent, NursingQueueScope.urgent),
        NursingNextActionKind.escalate,
      );
      expect(
        nursingResolveNextActionLabel(l10n, urgent, NursingQueueScope.urgent),
        l10n.nursingActionEscalate,
      );
      expect(
        nursingResolveNextActionKind(
          routine,
          NursingQueueScope.handoverPending,
        ),
        NursingNextActionKind.handover,
      );
      expect(
        nursingResolveNextActionKind(
          routine,
          NursingQueueScope.transferPending,
        ),
        NursingNextActionKind.transfer,
      );
      expect(
        nursingResolveNextActionKind(
          routine,
          NursingQueueScope.dischargePending,
        ),
        NursingNextActionKind.discharge,
      );
    });
  });

  group('nursingColumnsForScope', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    Set<String> labels(NursingQueueScope scope) {
      return nursingColumnsForScope(
        l10n,
        scope,
      ).map((AppListTableColumn<NursingWorkItem> c) => c.label).toSet();
    }

    test('returns different column sets per scope', () {
      expect(
        labels(NursingQueueScope.all),
        contains(l10n.nursingTaskTypeColumnLabel),
      );
      expect(
        labels(NursingQueueScope.all),
        isNot(contains(l10n.nursingPriorityColumnLabel)),
      );
      expect(
        labels(NursingQueueScope.urgent),
        contains(l10n.nursingPriorityColumnLabel),
      );
      expect(
        labels(NursingQueueScope.medicationDue),
        contains(l10n.nursingMedicationDueSummaryLabel),
      );
      expect(
        labels(NursingQueueScope.handoverPending),
        contains(l10n.nursingResponsibleNurseColumnLabel),
      );
      expect(
        labels(NursingQueueScope.transferPending),
        contains(l10n.nursingTransferPendingSummaryLabel),
      );
      expect(
        labels(NursingQueueScope.dischargePending),
        contains(l10n.dischargeStatusFilterLabel),
      );

      for (final NursingQueueScope scope in NursingQueueScope.values) {
        expect(labels(scope), contains(l10n.nursingNextActionColumnLabel));
      }

      expect(
        labels(NursingQueueScope.all),
        isNot(equals(labels(NursingQueueScope.medicationDue))),
      );
      expect(
        labels(NursingQueueScope.urgent),
        isNot(equals(labels(NursingQueueScope.handoverPending))),
      );
    });

    test('column choices include extras beyond defaults', () {
      final List<AppListTableColumn<NursingWorkItem>> defaults =
          nursingColumnsForScope(l10n, NursingQueueScope.urgent);
      final List<AppListTableColumn<NursingWorkItem>> choices =
          nursingColumnChoicesForScope(l10n, NursingQueueScope.urgent);
      expect(choices.length, greaterThan(defaults.length));
    });
  });

  group('nursingResolveNextActionKind', () {
    test('escalates urgent critical patients', () {
      const NursingPatientSummary urgentPatient = NursingPatientSummary(
        id: 'adm-urgent',
        admissionId: 'adm-urgent',
        hasCriticalAlert: true,
      );
      expect(
        nursingResolveNextActionKind(
          urgentPatient,
          NursingQueueScope.urgent,
        ),
        NursingNextActionKind.escalate,
      );
    });

    test('resolves medication due from task type on all scope', () {
      const NursingPatientSummary medicationPatient = NursingPatientSummary(
        id: 'adm-med',
        admissionId: 'adm-med',
        medicationDueCount: 2,
      );
      expect(
        nursingResolveNextActionKind(
          medicationPatient,
          NursingQueueScope.all,
        ),
        NursingNextActionKind.medication,
      );
    });
  });

  group('nursingResolveNextActionLabel', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('resolves task-type actions on the all scope', () {
      const NursingPatientSummary medicationPatient = NursingPatientSummary(
        id: 'adm-med',
        admissionId: 'adm-med',
        medicationDueCount: 2,
      );
      expect(
        nursingResolveNextActionLabel(
          l10n,
          medicationPatient,
          NursingQueueScope.all,
        ),
        l10n.nursingActionAdministerMedication,
      );
    });

    test('escalates urgent critical patients', () {
      const NursingPatientSummary urgentPatient = NursingPatientSummary(
        id: 'adm-urgent',
        admissionId: 'adm-urgent',
        hasCriticalAlert: true,
      );
      expect(
        nursingResolveNextActionLabel(
          l10n,
          urgentPatient,
          NursingQueueScope.urgent,
        ),
        l10n.nursingActionEscalate,
      );
    });
  });

  group('nursingTabItems', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    NursingWorkspaceState emptyState() {
      return const NursingWorkspaceState(
        query: NursingWorklistQuery(),
        worklist: AppPage<NursingPatientSummary>(
          items: <NursingPatientSummary>[],
          request: AppPageRequest(),
          totalItemCount: 0,
        ),
      );
    }

    test('exposes seven scope tabs', () {
      final List<AppTabItem> tabs = nursingTabItems(l10n, emptyState());
      expect(tabs, hasLength(7));
      expect(tabs.map((AppTabItem t) => t.id).toList(), <String>[
        'all',
        'assigned-ward',
        'urgent',
        'medication-due',
        'handover-pending',
        'transfer-pending',
        'discharge-pending',
      ]);
    });

    test('omits zero counts and maps tones from workspace state', () {
      final List<AppTabItem> emptyTabs = nursingTabItems(l10n, emptyState());
      for (final AppTabItem tab in emptyTabs) {
        expect(tab.count, isNull);
      }

      const NursingPatientSummary urgentPatient = NursingPatientSummary(
        id: 'adm-urgent',
        admissionId: 'adm-urgent',
        displayId: 'ADM-URGENT',
        patientDisplayId: 'PT-URGENT',
        patientDisplayName: 'Urgent Patient',
        stage: 'ADMITTED_IN_BED',
        admissionStatus: 'ADMITTED_IN_BED',
        wardDisplayName: 'Ward C',
        bedDisplayLabel: 'Bed 3',
        hasActiveBed: true,
        hasCriticalAlert: true,
        criticalSeverity: 'CRITICAL',
      );
      const NursingWorkspaceState state = NursingWorkspaceState(
        query: NursingWorklistQuery(),
        worklist: AppPage<NursingPatientSummary>(
          items: <NursingPatientSummary>[urgentPatient],
          request: AppPageRequest(),
          totalItemCount: 1,
        ),
      );
      final List<AppTabItem> tabs = nursingTabItems(l10n, state);
      expect(tabs[0].count, 1);
      expect(tabs[0].countTone, AppTabCountTone.info);
      expect(tabs[2].count, 1);
      expect(tabs[2].countTone, AppTabCountTone.danger);
    });
  });
}
