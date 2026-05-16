import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/search/search.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('AppSearchField clears through the shared clear action', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'Amina');
    var clearCount = 0;
    addTearDown(controller.dispose);

    await pumpComponent(
      tester,
      AppSearchField(
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
