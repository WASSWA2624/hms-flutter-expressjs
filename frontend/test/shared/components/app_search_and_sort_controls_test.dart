import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('AppSearchBar clears through the shared clear action', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'Amina');
    var clearCount = 0;
    addTearDown(controller.dispose);

    await pumpComponent(
      tester,
      AppSearchBar(
        controller: controller,
        semanticLabel: 'Search patients',
        hintText: 'Search',
        clearLabel: 'Clear search',
        onClear: () {
          clearCount += 1;
        },
      ),
    );

    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(clearCount, 1);
    expect(find.byTooltip('Clear search'), findsNothing);
  });

  testWidgets('AppSearchBar opens configurable advanced filters', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'Amina');
    AppSearchBarFilterValue filterValue = const AppSearchBarFilterValue(
      field: 'name',
      options: <String, String>{'status': 'active'},
    );
    AppSearchBarFilterValue? applied;
    addTearDown(controller.dispose);

    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AppSearchBar(
            controller: controller,
            semanticLabel: 'Search patients',
            hintText: 'Search',
            advancedFilterButtonLabel: 'Advanced filters',
            searchFields: const <AppSearchBarFieldChoice>[
              AppSearchBarFieldChoice(field: 'name', label: 'Name'),
              AppSearchBarFieldChoice(field: 'patient_id', label: 'Patient ID'),
            ],
            filterGroups: const <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: 'status',
                label: 'Status',
                allLabel: 'Any status',
                choices: <AppSearchBarFilterChoice>[
                  AppSearchBarFilterChoice(value: 'active', label: 'Active'),
                  AppSearchBarFilterChoice(
                    value: 'inactive',
                    label: 'Inactive',
                  ),
                ],
              ),
            ],
            filterValue: filterValue,
            onFilterChanged: (AppSearchBarFilterValue value) {
              setState(() {
                filterValue = value;
                applied = value;
              });
            },
          );
        },
      ),
    );

    await tester.tap(find.byTooltip('Advanced filters'));
    await tester.pumpAndSettle();

    expect(find.text('Advanced filters'), findsOneWidget);
    expect(find.text('Search in'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    expect(applied, filterValue);
    expect(applied?.field, 'name');
    expect(applied?.option('status'), 'active');
  });

  testWidgets('AppSearchBar advanced filters support text criteria', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    AppSearchBarFilterValue? applied;
    addTearDown(controller.dispose);

    await pumpComponent(
      tester,
      AppSearchBar(
        controller: controller,
        semanticLabel: 'Search clinical records',
        hintText: 'Search',
        advancedFilterButtonLabel: 'Advanced filters',
        searchFieldLabel: 'Search criteria',
        textFilters: const <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: 'patient',
            label: 'Patient',
            hintText: 'Name or ID',
          ),
          AppSearchBarTextFilter(key: 'encounter', label: 'Encounter'),
        ],
        filterValue: const AppSearchBarFilterValue(
          texts: <String, String>{'patient': 'Amina'},
        ),
        onFilterChanged: (AppSearchBarFilterValue value) {
          applied = value;
        },
      ),
    );

    await tester.tap(find.byTooltip('Advanced filters'));
    await tester.pumpAndSettle();

    expect(find.text('Search criteria'), findsOneWidget);
    expect(find.text('Search in'), findsNothing);
    expect(find.text('Patient'), findsOneWidget);
    expect(find.text('Encounter'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Encounter'),
      'E-1',
    );
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    expect(applied?.text('patient'), 'Amina');
    expect(applied?.text('encounter'), 'E-1');
  });

  testWidgets('AppSortMenuButton emits selected descriptors', (
    WidgetTester tester,
  ) async {
    AppSortDescriptor? selected;

    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AppSortMenuButton(
            label: 'Sort',
            ascendingLabel: 'ascending',
            descendingLabel: 'descending',
            clearLabel: 'Clear sort',
            value: selected,
            onChanged: (AppSortDescriptor? value) {
              setState(() {
                selected = value;
              });
            },
            options: const <AppSortOption>[
              AppSortOption(field: 'name', label: 'Name'),
              AppSortOption(field: 'created_at', label: 'Created'),
            ],
          );
        },
      ),
    );

    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name ascending'));
    await tester.pumpAndSettle();

    expect(selected, const AppSortDescriptor(field: 'name'));
    expect(find.text('Name, ascending'), findsOneWidget);

    await tester.tap(find.text('Name, ascending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Created descending'));
    await tester.pumpAndSettle();

    expect(
      selected,
      const AppSortDescriptor(
        field: 'created_at',
        direction: AppSortDirection.descending,
      ),
    );

    await tester.tap(find.text('Created, descending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear sort'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(find.text('Sort'), findsOneWidget);
  });
}
