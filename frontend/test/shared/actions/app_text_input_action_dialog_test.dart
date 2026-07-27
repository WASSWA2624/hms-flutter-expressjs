import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

void main() {
  testWidgets(
    'Permanent delete stays disabled until confirm text matches exactly',
    (WidgetTester tester) async {
      String? submitted;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    submitted = await showDialog<String>(
                      context: context,
                      builder: (_) => const AppTextInputActionDialog(
                        title: 'PERMANENT DELETE — IRREVERSIBLE',
                        description: 'WARNING: Permanently deleting Joking.',
                        fieldLabel: "Type 'Joking' to confirm permanent delete",
                        submitLabel: 'Permanent delete',
                        cancelLabel: 'Cancel',
                        requiredMessage: 'Required',
                        confirmExactValue: 'Joking',
                        confirmMismatchMessage:
                            "Type 'Joking' to confirm permanent delete",
                        destructive: true,
                        minLines: 1,
                        maxLines: 1,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      Finder submitButton() =>
          find.widgetWithText(AppButton, 'Permanent delete');

      AppButton readSubmit() => tester.widget<AppButton>(submitButton());

      expect(readSubmit().enabled, isFalse);
      expect(readSubmit().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Wrong');
      await tester.pump();
      expect(readSubmit().enabled, isFalse);

      await tester.tap(submitButton());
      await tester.pump();
      expect(submitted, isNull);
      expect(find.byType(AppTextInputActionDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Joking');
      await tester.pump();
      expect(readSubmit().enabled, isTrue);
      expect(readSubmit().onPressed, isNotNull);

      await tester.tap(submitButton());
      await tester.pumpAndSettle();
      expect(submitted, 'Joking');
      expect(find.byType(AppTextInputActionDialog), findsNothing);
    },
  );
}
