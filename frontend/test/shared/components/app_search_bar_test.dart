import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('advanced filter dialog uses a two-action footer on mobile', (
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

    expect(find.text('CLINICAL FILTERS'), findsOneWidget);
    expect(clearAction, findsOneWidget);
    expect(applyAction, findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(
      tester.getTopLeft(clearAction).dy,
      tester.getTopLeft(applyAction).dy,
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
            label: 'Table settings',
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(960, 498),
    );

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Table settings'), findsOneWidget);
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
            label: 'Table settings',
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(720, 498),
    );

    expect(find.text('Filters'), findsNothing);
    expect(find.text('Table settings'), findsNothing);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.byTooltip('Table settings'), findsOneWidget);
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
              AppSearchBarFilterChoice(value: 'processing', label: 'Processing'),
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
