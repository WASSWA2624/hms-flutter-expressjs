import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  testWidgets(
    'ClinicalFreeTextActionDialog supports optional context and empty submit',
    (WidgetTester tester) async {
      String? submittedValue;

      await _pumpDialog(
        tester,
        ClinicalFreeTextActionDialog(
          title: 'Progress note',
          sectionTitle: 'Clinical entry',
          description: 'Review encounter context before saving.',
          label: 'Note',
          submitLabel: 'Save note',
          initialValue: 'Existing note',
          isRequired: false,
          leadingContent: const <Widget>[Text('Encounter ENC-001')],
          onSubmit: (String value) async {
            submittedValue = value;
            return null;
          },
        ),
      );

      expect(find.text('Clinical entry'), findsOneWidget);
      expect(
        find.text('Review encounter context before saving.'),
        findsOneWidget,
      );
      expect(find.text('Encounter ENC-001'), findsOneWidget);
      expect(find.text('Existing note'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), '');
      await tester.tap(find.text('Save note').last);
      await tester.pumpAndSettle();

      expect(submittedValue, isEmpty);
      expect(find.byType(ClinicalFreeTextActionDialog), findsNothing);
    },
  );

  testWidgets(
    'ClinicalFreeTextActionDialog keeps save failures in the shared shell',
    (WidgetTester tester) async {
      await _pumpDialog(
        tester,
        ClinicalFreeTextActionDialog(
          title: 'Nursing note',
          label: 'Note',
          submitLabel: 'Save note',
          onSubmit: (String value) async {
            return AppFailure.validation();
          },
        ),
      );

      await tester.enterText(find.byType(EditableText), 'Needs review');
      await tester.tap(find.text('Save note').last);
      await tester.pumpAndSettle();

      expect(find.byType(AppFailureStateView), findsOneWidget);
      expect(find.byType(ClinicalFreeTextActionDialog), findsOneWidget);
    },
  );
}

Future<void> _pumpDialog(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: dialog),
    ),
  );
  await tester.pumpAndSettle();
}
