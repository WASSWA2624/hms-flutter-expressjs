import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  test('filter value counts scalar and multi-value criteria', () {
    const AppSearchBarFilterValue value = AppSearchBarFilterValue(
      field: 'patient',
      texts: <String, String>{'reason': 'review'},
      options: <String, String>{'legacy': 'open'},
      selections: <String, Set<String>>{
        'status': <String>{'new', 'confirmed'},
      },
    );

    expect(value.activeCount, 5);
    expect(value.optionsFor('legacy'), <String>{'open'});
    expect(value.optionsFor('status'), <String>{'new', 'confirmed'});
  });

  test('date ranges are inclusive and reject an inverted range', () {
    final DateTime day = DateTime(2026, 7, 19);

    expect(appSearchBarDateRangeIsValid(day, day), isTrue);
    expect(appSearchBarDateRangeIsValid(null, day), isTrue);
    expect(appSearchBarDateRangeIsValid(DateTime(2026, 7, 20), day), isFalse);
  });

  testWidgets('multi-select filter returns every checked value on Apply', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    AppSearchBarFilterValue? applied;

    await pumpComponent(
      tester,
      AppSearchBar(
        controller: controller,
        semanticLabel: 'Search records',
        showAdvancedFilterButton: true,
        enableDateFilter: false,
        filterGroups: const <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: 'status',
            label: 'Status',
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(value: 'NEW', label: 'New'),
              AppSearchBarFilterChoice(value: 'CONFIRMED', label: 'Confirmed'),
            ],
            allowMultiple: true,
          ),
        ],
        onFilterChanged: (AppSearchBarFilterValue value) => applied = value,
      ),
      size: const Size(720, 640),
    );

    await tester.tap(find.byTooltip('Advanced filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'New'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Confirmed'));
    await tester.pump();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    expect(applied?.optionsFor('status'), <String>{'NEW', 'CONFIRMED'});
  });

  testWidgets('footer Close discards pending filter changes', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    AppSearchBarFilterValue? applied;

    await pumpComponent(
      tester,
      AppSearchBar(
        controller: controller,
        semanticLabel: 'Search records',
        showAdvancedFilterButton: true,
        enableDateFilter: false,
        advancedFilterCloseLabel: 'Close',
        textFilters: const <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(key: 'patient', label: 'Patient'),
        ],
        onFilterChanged: (AppSearchBarFilterValue value) => applied = value,
      ),
      size: const Size(720, 640),
    );

    await tester.tap(find.byTooltip('Advanced filters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Ada');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(applied, isNull);
  });

  testWidgets('advanced filter dialog includes rightmost Close on mobile', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpComponent(
      tester,
      AppSearchBar(
        controller: controller,
        semanticLabel: 'Search records',
        showAdvancedFilterButton: true,
        advancedFilterTitle: 'Clinical filters',
        advancedFilterApplyLabel: 'Apply filters',
        advancedFilterResetLabel: 'Clear filters',
        enableDateFilter: false,
        textFilters: const <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(key: 'name', label: 'Patient name'),
        ],
      ),
      size: const Size(400, 498),
    );

    await tester.tap(find.byTooltip('Advanced filters'));
    await tester.pumpAndSettle();

    final Finder clearAction = find.text('Clear filters');
    final Finder applyAction = find.text('Apply filters');
    final Finder closeAction = find.text('Close');

    expect(find.text('CLINICAL FILTERS'), findsOneWidget);
    expect(clearAction, findsOneWidget);
    expect(applyAction, findsOneWidget);
    expect(closeAction, findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    final Offset applyPosition = tester.getTopLeft(applyAction);
    final Offset closePosition = tester.getTopLeft(closeAction);
    expect(
      closePosition.dy > applyPosition.dy ||
          (closePosition.dy == applyPosition.dy &&
              closePosition.dx > applyPosition.dx),
      isTrue,
    );
  });

  testWidgets('attached toolbar actions show labels on large screens', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpComponent(
      tester,
      AppSearchBar(
        controller: controller,
        semanticLabel: 'Search records',
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: 'Filters',
        trailingActions: <AppSearchBarAction>[
          AppSearchBarAction(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(960, 498),
    );

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('attached toolbar actions stay icon-only on compact screens', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpComponent(
      tester,
      AppSearchBar(
        controller: controller,
        semanticLabel: 'Search records',
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: 'Filters',
        trailingActions: <AppSearchBarAction>[
          AppSearchBarAction(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(720, 498),
    );

    expect(find.text('Filters'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('filter dialog clear leaves placeholder instead of All option', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpComponent(
      tester,
      AppSearchBar(
        controller: controller,
        semanticLabel: 'Search records',
        showAdvancedFilterButton: true,
        advancedFilterTitle: 'Workspace filters',
        advancedFilterApplyLabel: 'Apply filters',
        advancedFilterResetLabel: 'Clear filters',
        enableDateFilter: false,
        allFieldsLabel: 'All',
        filterGroups: const <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: 'queue',
            label: 'Queue',
            allLabel: 'All',
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'processing',
                label: 'Processing',
              ),
              AppSearchBarFilterChoice(
                value: 'awaiting',
                label: 'Awaiting results',
              ),
            ],
          ),
        ],
      ),
      size: const Size(720, 640),
    );

    await tester.tap(find.byTooltip('Advanced filters'));
    await tester.pumpAndSettle();

    final Finder dialog = find.byType(AppDialog);
    final Finder queueField = find.descendant(
      of: dialog,
      matching: find.byType(EditableText),
    );

    await tester.tap(queueField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Processing').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Processing'), findsOneWidget);

    final Finder selectClear = find.descendant(
      of: find.descendant(
        of: dialog,
        matching: find.byType(DropdownMenuFormField<String>),
      ),
      matching: find.byIcon(Icons.close),
    );
    await tester.tap(selectClear);
    await tester.pumpAndSettle();

    expect(find.text('Processing'), findsNothing);
    expect(
      find.descendant(of: dialog, matching: find.text('All')),
      findsOneWidget,
    );
  });

  testWidgets(
    'filter dialog shows all options when reopening menu with a selection',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpComponent(
        tester,
        AppSearchBar(
          controller: controller,
          semanticLabel: 'Search records',
          showAdvancedFilterButton: true,
          advancedFilterTitle: 'Workspace filters',
          advancedFilterApplyLabel: 'Apply filters',
          advancedFilterResetLabel: 'Clear filters',
          enableDateFilter: false,
          allFieldsLabel: 'All',
          filterGroups: const <AppSearchBarFilterGroup>[
            AppSearchBarFilterGroup(
              key: 'queue',
              label: 'Queue',
              allLabel: 'All',
              choices: <AppSearchBarFilterChoice>[
                AppSearchBarFilterChoice(
                  value: 'processing',
                  label: 'Processing',
                ),
                AppSearchBarFilterChoice(
                  value: 'awaiting',
                  label: 'Awaiting results',
                ),
              ],
            ),
          ],
        ),
        size: const Size(720, 640),
      );

      await tester.tap(find.byTooltip('Advanced filters'));
      await tester.pumpAndSettle();

      final Finder dialog = find.byType(AppDialog);
      final Finder queueField = find.descendant(
        of: dialog,
        matching: find.byType(EditableText),
      );

      await tester.tap(queueField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Awaiting results').hitTestable());
      await tester.pumpAndSettle();

      await tester.tap(queueField);
      await tester.pumpAndSettle();

      expect(find.text('Processing').hitTestable(), findsOneWidget);
      expect(find.text('All').hitTestable(), findsOneWidget);
    },
  );
}
