import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_list_field.dart';

void main() {
  testWidgets(
    'All genders disables specific gender checkboxes',
    (WidgetTester tester) async {
      final EditableLabReferenceRange range = EditableLabReferenceRange();
      addTearDown(range.dispose);

      await _pumpRangeEditor(tester, range);

      expect(find.text('All genders'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('All ages'), findsOneWidget);

      final AppCheckboxField allGenders = _checkboxWithTitle(
        tester,
        'All genders',
      );
      final AppCheckboxField male = _checkboxWithTitle(tester, 'Male');
      expect(allGenders.value, isTrue);
      expect(male.enabled, isFalse);

      // Uncheck All genders → Male becomes active.
      await tester.tap(find.text('All genders'));
      await tester.pumpAndSettle();
      expect(range.gender, 'MALE');
      expect(_checkboxWithTitle(tester, 'Male').enabled, isTrue);
      expect(_checkboxWithTitle(tester, 'Male').value, isTrue);

      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      expect(range.gender, 'FEMALE');
      expect(_checkboxWithTitle(tester, 'All genders').value, isFalse);
    },
  );

  testWidgets(
    'All ages clears and disables age bounds; typing re-enables specific ages',
    (WidgetTester tester) async {
      final EditableLabReferenceRange range = EditableLabReferenceRange()
        ..allAges = false
        ..ageMinController.text = '18'
        ..ageMaxController.text = '65';
      addTearDown(range.dispose);

      await _pumpRangeEditor(tester, range);

      expect(range.allAges, isFalse);
      expect(find.text('Age min'), findsOneWidget);

      await tester.tap(find.text('All ages'));
      await tester.pumpAndSettle();

      expect(range.allAges, isTrue);
      expect(range.ageMinController.text, isEmpty);
      expect(range.ageMaxController.text, isEmpty);
      expect(_checkboxWithTitle(tester, 'All ages').value, isTrue);

      // Turn off All ages, then type a bound.
      await tester.tap(find.text('All ages'));
      await tester.pumpAndSettle();
      expect(range.allAges, isFalse);

      await tester.enterText(find.widgetWithText(TextFormField, 'Age min'), '0');
      await tester.pumpAndSettle();
      expect(range.allAges, isFalse);
      expect(range.ageMinController.text, '0');

      // Clearing both bounds restores All ages.
      await tester.enterText(find.widgetWithText(TextFormField, 'Age min'), '');
      await tester.pumpAndSettle();
      expect(range.allAges, isTrue);
    },
  );

  test('toPayload omits gender and ages when All options are selected', () {
    final EditableLabReferenceRange range = EditableLabReferenceRange()
      ..labelController.text = 'Adult'
      ..setAllGenders()
      ..setAllAges(value: true);
    addTearDown(range.dispose);

    final Map<String, Object?> payload = range.toPayload(
      sortOrder: 0,
      fallbackUnit: 'g/dL',
    );
    expect(payload.containsKey('gender'), isFalse);
    expect(payload['age_min_value'], isNull);
    expect(payload['age_max_value'], isNull);
  });
}

AppCheckboxField _checkboxWithTitle(WidgetTester tester, String title) {
  return tester.widget<AppCheckboxField>(
    find.byWidgetPredicate(
      (Widget widget) => widget is AppCheckboxField && widget.title == title,
    ),
  );
}

Future<void> _pumpRangeEditor(
  WidgetTester tester,
  EditableLabReferenceRange range,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return LabReferenceRangeListField(
                ranges: <EditableLabReferenceRange>[range],
                enabled: true,
                fallbackUnit: 'g/dL',
                showHeader: false,
                onChanged: () => setState(() {}),
                onAdd: () {},
                onRemove: (_) {},
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
