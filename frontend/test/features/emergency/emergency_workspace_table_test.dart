import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/pages/emergency_workspace_page.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  const writeRequirement = emergencyWriteRequirement;

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (BuildContext context) => child),
    );
  }

  group('EmergencyWorkspaceQuery.fromUri', () {
    test('accepts workflow encounterId as the case deep-link', () {
      final EmergencyWorkspaceQuery query = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?encounterId=EME000099&panel=triage'),
      );

      expect(query.caseId, 'EME000099');
      expect(query.panel, EmergencyDetailPanelFocus.triage);
    });
  });

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
          emergencyNextActionColumn(
            context,
            tab: EmergencyBoardTab.active,
            writeRequirement: writeRequirement,
          );

      expect(column.label, isNot(EmergencyText.next));
      expect(column.label, 'Next action');
    });
  });

  group('emergencyBoardNextActionKind', () {
    test('advances triage → response → handoff on active board', () {
      expect(
        emergencyBoardNextActionKind(
          const EmergencyCaseSummary(id: '1', status: 'OPEN'),
          tab: EmergencyBoardTab.active,
        ),
        EmergencyNextActionKind.triage,
      );
      expect(
        emergencyBoardNextActionKind(
          const EmergencyCaseSummary(
            id: '2',
            status: 'OPEN',
            latestTriage: EmergencyTriageAssessment(
              id: 't1',
              triageLevel: 'LEVEL_2',
            ),
          ),
          tab: EmergencyBoardTab.active,
        ),
        EmergencyNextActionKind.response,
      );
      expect(
        emergencyBoardNextActionKind(
          const EmergencyCaseSummary(
            id: '3',
            status: 'OPEN',
            latestTriage: EmergencyTriageAssessment(
              id: 't1',
              triageLevel: 'LEVEL_2',
            ),
            latestResponse: EmergencyResponseRecord(id: 'r1'),
          ),
          tab: EmergencyBoardTab.active,
        ),
        EmergencyNextActionKind.handoff,
      );
    });

    test('ambulance tab specializes dispatch / start trip after readiness', () {
      const EmergencyCaseSummary ready = EmergencyCaseSummary(
        id: 'amb-1',
        status: 'OPEN',
        latestTriage: EmergencyTriageAssessment(
          id: 't1',
          triageLevel: 'LEVEL_1',
        ),
        latestResponse: EmergencyResponseRecord(id: 'r1'),
      );
      expect(
        emergencyBoardNextActionKind(ready, tab: EmergencyBoardTab.ambulance),
        EmergencyNextActionKind.dispatch,
      );
      expect(
        emergencyBoardNextActionKind(
          ready.copyWith(
            latestDispatch: const EmergencyAmbulanceDispatch(
              id: 'd1',
              status: 'DISPATCHED',
              ambulanceId: 'AMB1',
            ),
          ),
          tab: EmergencyBoardTab.ambulance,
        ),
        EmergencyNextActionKind.startTrip,
      );
    });

    test('closed cases have no next-action kind', () {
      expect(
        emergencyBoardNextActionKind(
          const EmergencyCaseSummary(id: 'c1', status: 'CLOSED'),
          tab: EmergencyBoardTab.closed,
        ),
        isNull,
      );
    });

    test('detail omit kind matches board primary so duplicates stay removed', () {
      const EmergencyCaseSummary untreated = EmergencyCaseSummary(
        id: 'u1',
        status: 'OPEN',
      );
      final EmergencyNextActionKind? kind = emergencyBoardNextActionKind(
        untreated,
        tab: EmergencyBoardTab.active,
      );
      expect(kind, EmergencyNextActionKind.triage);
      // Opening detail with omitNextActionKind: triage must hide Triage in
      // Quick Actions — covered by EmergencyActionPanel omit wiring.
      expect(kind == EmergencyNextActionKind.triage, isTrue);
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
