import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_list_field.dart';

void main() {
  testWidgets(
    'All genders disables specific gender chips',
    (WidgetTester tester) async {
      final EditableLabReferenceRange range = EditableLabReferenceRange();
      addTearDown(range.dispose);

      await _pumpRangeEditor(tester, range);

      expect(find.text('All genders'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('All ages'), findsOneWidget);
      expect(
        find.text(
          'Specific genders are cleared while All genders is selected.',
        ),
        findsOneWidget,
      );

      expect(_chipWithLabel(tester, 'All genders').selected, isTrue);
      expect(_chipWithLabel(tester, 'Male').onSelected, isNull);

      // Uncheck All genders → Male becomes active.
      await tester.tap(find.text('All genders'));
      await tester.pumpAndSettle();
      expect(range.gender, 'MALE');
      expect(_chipWithLabel(tester, 'Male').onSelected, isNotNull);
      expect(_chipWithLabel(tester, 'Male').selected, isTrue);

      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      expect(range.gender, 'FEMALE');
      expect(_chipWithLabel(tester, 'All genders').selected, isFalse);

      // Re-select All genders → specifics inactivated again.
      await tester.tap(find.text('All genders'));
      await tester.pumpAndSettle();
      expect(range.appliesToAllGenders, isTrue);
      expect(_chipWithLabel(tester, 'Male').onSelected, isNull);
      expect(_chipWithLabel(tester, 'Female').onSelected, isNull);
    },
  );

  testWidgets(
    'Age presets fill bounds; All ages hides and clears them',
    (WidgetTester tester) async {
      final EditableLabReferenceRange range = EditableLabReferenceRange()
        ..allAges = false
        ..ageMinController.text = '18'
        ..ageMaxController.text = '65';
      addTearDown(range.dispose);

      await _pumpRangeEditor(tester, range);

      expect(range.allAges, isFalse);
      expect(find.text('Age min'), findsOneWidget);
      expect(find.text('Adult'), findsWidgets);

      await tester.tap(find.text('All ages'));
      await tester.pumpAndSettle();

      expect(range.allAges, isTrue);
      expect(range.ageMinController.text, isEmpty);
      expect(range.ageMaxController.text, isEmpty);
      expect(_chipWithLabel(tester, 'All ages').selected, isTrue);
      expect(find.text('Age min'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Adult'));
      await tester.pumpAndSettle();
      expect(range.allAges, isFalse);
      expect(range.ageUnit, 'YEAR');
      expect(range.ageMinController.text, '18');
      expect(range.ageMaxController.text, '64');
      expect(range.labelController.text, 'Adult');
      expect(find.text('Age min'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Neonate'));
      await tester.pumpAndSettle();
      expect(range.ageUnit, 'DAY');
      expect(range.ageMinController.text, '0');
      expect(range.ageMaxController.text, '28');
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

  test('applyAgePreset replaces All ages default label', () {
    final EditableLabReferenceRange range = EditableLabReferenceRange(
      defaultLabel: 'All ages',
    );
    addTearDown(range.dispose);

    range.applyAgePreset(
      kLabAgeBandPresets.firstWhere(
        (LabAgeBandPreset p) => p.id == 'geriatric',
      ),
      labelIfEmpty: 'Geriatric',
      allAgesLabel: 'All ages',
    );
    expect(range.allAges, isFalse);
    expect(range.ageMinController.text, '65');
    expect(range.ageMaxController.text, isEmpty);
    expect(range.labelController.text, 'Geriatric');
    expect(range.matchingAgePresetId(), 'geriatric');
  });
}

FilterChip _chipWithLabel(WidgetTester tester, String label) {
  return tester.widget<FilterChip>(
    find.widgetWithText(FilterChip, label),
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
