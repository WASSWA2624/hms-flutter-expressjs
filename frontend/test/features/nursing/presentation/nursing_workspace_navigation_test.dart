import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_scope_navigation.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_columns.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

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

  group('nursingPrimaryActionLabel / nursingPrimaryActionIcon', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('returns contextual labels per scope', () {
      expect(
        nursingPrimaryActionLabel(l10n, NursingQueueScope.all),
        l10n.nursingActionRecordVitals,
      );
      expect(
        nursingPrimaryActionLabel(l10n, NursingQueueScope.medicationDue),
        l10n.nursingActionAdministerMedication,
      );
      expect(
        nursingPrimaryActionLabel(l10n, NursingQueueScope.handoverPending),
        l10n.nursingActionCreateHandover,
      );
      expect(
        nursingPrimaryActionLabel(l10n, NursingQueueScope.transferPending),
        l10n.nursingActionAcknowledgeTransfer,
      );
      expect(
        nursingPrimaryActionLabel(l10n, NursingQueueScope.dischargePending),
        l10n.nursingActionDischargeClearance,
      );
    });

    test('returns contextual icons per scope', () {
      expect(
        nursingPrimaryActionIcon(NursingQueueScope.all),
        Icons.monitor_heart_outlined,
      );
      expect(
        nursingPrimaryActionIcon(NursingQueueScope.medicationDue),
        Icons.medication_outlined,
      );
      expect(
        nursingPrimaryActionIcon(NursingQueueScope.handoverPending),
        Icons.swap_horiz_outlined,
      );
      expect(
        nursingPrimaryActionIcon(NursingQueueScope.transferPending),
        Icons.transfer_within_a_station_outlined,
      );
      expect(
        nursingPrimaryActionIcon(NursingQueueScope.dischargePending),
        Icons.fact_check_outlined,
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

  group('nursingTabItems', () {
    test('exposes seven scope tabs', () async {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      final List<AppTabItem> tabs = nursingTabItems(l10n);
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
  });
}
