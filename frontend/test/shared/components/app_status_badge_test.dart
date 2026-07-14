import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_status_badge.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('renders label with non-color icon cue', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppStatusBadge(
        label: 'Active',
        tone: AppWorkspaceStatusTone.success,
      ),
    );

    expect(find.text('Active'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
