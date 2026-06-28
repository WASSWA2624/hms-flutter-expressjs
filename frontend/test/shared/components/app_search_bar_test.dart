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

    expect(find.text('Clinical filters'), findsOneWidget);
    expect(clearAction, findsOneWidget);
    expect(applyAction, findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(
      tester.getTopLeft(clearAction).dy,
      tester.getTopLeft(applyAction).dy,
    );
  });
}
