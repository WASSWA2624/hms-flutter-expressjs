import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/pages/emergency_workspace_page.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  const AccessRequirement writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.emergencyWrite],
  );

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (BuildContext context) => child),
    );
  }

  group('emergencyDefaultColumnsForTab', () {
    testWidgets('returns at most five columns for every tab', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      for (final EmergencyBoardTab tab in EmergencyBoardTab.values) {
        final List<AppListTableColumn<EmergencyCaseSummary>> columns =
            emergencyDefaultColumnsForTab(
              context,
              tab,
              writeRequirement: writeRequirement,
            );
        expect(
          columns.length,
          lessThanOrEqualTo(5),
          reason: '${tab.name} default column count',
        );
      }
    });

    testWidgets('workflow tabs include status and next_action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      const List<EmergencyBoardTab> workflowTabs = <EmergencyBoardTab>[
        EmergencyBoardTab.active,
        EmergencyBoardTab.critical,
        EmergencyBoardTab.ambulance,
        EmergencyBoardTab.handoff,
        EmergencyBoardTab.all,
      ];

      for (final EmergencyBoardTab tab in workflowTabs) {
        final List<String> ids =
            emergencyDefaultColumnsForTab(
                  context,
                  tab,
                  writeRequirement: writeRequirement,
                )
                .map(
                  (AppListTableColumn<EmergencyCaseSummary> column) =>
                      column.id,
                )
                .whereType<String>()
                .toList();
        expect(ids, contains('status'), reason: '${tab.name} status column');
        expect(ids, contains('next_action'), reason: '${tab.name} next action');
      }
    });

    testWidgets('closed tab has no next_action column', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      final List<String> ids =
          emergencyDefaultColumnsForTab(
                context,
                EmergencyBoardTab.closed,
                writeRequirement: writeRequirement,
              )
              .map(
                (AppListTableColumn<EmergencyCaseSummary> column) => column.id,
              )
              .whereType<String>()
              .toList();

      expect(ids, isNot(contains('next_action')));
      expect(ids, contains('status'));
    });
  });

  group('emergencyNextActionColumn', () {
    testWidgets('column label is not the generic Next label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      final AppListTableColumn<EmergencyCaseSummary> column =
          emergencyNextActionColumn(context);

      expect(column.label, isNot(EmergencyText.next));
      expect(column.label, 'Next action');
    });
  });

  group('emergencyTableSearchMatcher', () {
    test('matches hidden facility and location fields', () {
      const EmergencyCaseSummary item = EmergencyCaseSummary(
        id: 'case-1',
        facilityLabel: 'North Wing ED',
        patientDisplayName: 'Jane Doe',
      );

      expect(emergencyTableSearchMatcher(item, 'north wing'), isTrue);
      expect(
        emergencyTableSearchMatcher(
          const EmergencyCaseSummary(
            id: 'case-2',
            latestDispatch: EmergencyAmbulanceDispatch(
              id: 'dispatch-1',
              status: 'EN_ROUTE',
            ),
          ),
          'en route',
        ),
        isTrue,
      );
    });
  });

  group('emergencyFilterGroupsForTab', () {
    test('ambulance tab exposes dispatch status filter choices', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
      final List<EmergencyCaseSummary> rows = <EmergencyCaseSummary>[
        const EmergencyCaseSummary(
          id: 'case-amb-1',
          latestDispatch: EmergencyAmbulanceDispatch(
            id: 'dispatch-1',
            status: 'DISPATCHED',
          ),
        ),
      ];

      final List<AppSearchBarFilterGroup> groups = emergencyFilterGroupsForTab(
        l10n,
        EmergencyBoardTab.ambulance,
        rows,
      );

      expect(groups, isNotEmpty);
      final AppSearchBarFilterGroup dispatchGroup = groups.firstWhere(
        (AppSearchBarFilterGroup group) =>
            group.key == emergencyDispatchStatusFilterKey,
      );
      expect(dispatchGroup.choices, isNotEmpty);
    });
  });
}
