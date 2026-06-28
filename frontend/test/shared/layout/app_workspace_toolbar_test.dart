import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

import '../components/component_test_app.dart';

void main() {
  testWidgets('AppWorkspaceToolbar renders primary, secondary, and refresh', (
    WidgetTester tester,
  ) async {
    var refreshCount = 0;

    await pumpComponent(
      tester,
      ProviderScope(
        child: AppWorkspaceToolbar(
          config: AppWorkspaceToolbarConfig(
            primary: AppButton.primary(
              label: 'Create',
              onPressed: () {},
            ),
            secondary: <Widget>[
              AppButton.secondary(
                label: 'Configure',
                onPressed: () {},
              ),
            ],
            onRefresh: () async {
              refreshCount += 1;
            },
            showFaultReport: false,
            showHousekeepingRequest: false,
            refreshLabel: 'Refresh',
          ),
        ),
      ),
      size: const Size(1200, 600),
    );

    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Configure'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    expect(refreshCount, 1);
  });

  testWidgets('AppWorkspaceToolbar collapses left actions on narrow widths', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      ProviderScope(
        child: AppWorkspaceToolbar(
          config: AppWorkspaceToolbarConfig(
            secondary: <Widget>[
              AppButton.secondary(label: 'One', onPressed: () {}),
              AppButton.secondary(label: 'Two', onPressed: () {}),
            ],
            onRefresh: () async {},
            showFaultReport: false,
            showHousekeepingRequest: false,
            overflowLabel: 'More actions',
            refreshLabel: 'Refresh',
          ),
        ),
      ),
      size: const Size(360, 600),
    );

    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('AppActionLabelScope hides labels on small breakpoints', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      ProviderScope(
        child: AppActionLabelScope(
          showLabels: false,
          forceIconOnly: true,
          child: AppButton.secondary(
            label: 'Hidden label',
            leadingIcon: Icons.settings_outlined,
            onPressed: () {},
          ),
        ),
      ),
      size: const Size(360, 600),
    );

    expect(find.text('Hidden label'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
