import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_option_toggle.dart';

void main() {
  testWidgets('AppWorkspaceOptionToggle marks selected option as primary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppWorkspaceOptionToggle<String>(
            value: 'b',
            options: const <AppWorkspaceOptionToggleOption<String>>[
              AppWorkspaceOptionToggleOption<String>(
                value: 'a',
                label: 'All',
              ),
              AppWorkspaceOptionToggleOption<String>(
                value: 'b',
                label: 'Unread',
              ),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final Finder buttons = find.byType(AppButton);
    expect(buttons, findsNWidgets(2));

    final AppButton selected = tester.widget<AppButton>(buttons.at(1));
    final AppButton unselected = tester.widget<AppButton>(buttons.at(0));
    expect(selected.variant, AppButtonVariant.primary);
    expect(unselected.variant, AppButtonVariant.secondary);
  });
}
