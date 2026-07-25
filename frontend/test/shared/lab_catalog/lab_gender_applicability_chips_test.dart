import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_list_field.dart';

void main() {
  testWidgets(
    'All genders keeps specific gender chips enabled and exclusive',
    (WidgetTester tester) async {
      final EditableLabReferenceRange range = EditableLabReferenceRange();
      addTearDown(range.dispose);

      await _pumpRangeEditor(tester, range);

      expect(find.text('All genders'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('All ages'), findsOneWidget);

      expect(_chipWithLabel(tester, 'All genders').selected, isTrue);
      expect(_chipWithLabel(tester, 'Male').onSelected, isNotNull);
      expect(_chipWithLabel(tester, 'Female').onSelected, isNotNull);

      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      expect(range.gender, 'FEMALE');
      expect(_chipWithLabel(tester, 'All genders').selected, isFalse);
      expect(_chipWithLabel(tester, 'Female').selected, isTrue);

      await tester.tap(find.text('All genders'));
      await tester.pumpAndSettle();
      expect(range.appliesToAllGenders, isTrue);
      expect(_chipWithLabel(tester, 'Male').onSelected, isNotNull);
      expect(_chipWithLabel(tester, 'Female').selected, isFalse);
    },
  );

  testWidgets(
    'Age presets support multi-select and expand on save',
    (WidgetTester tester) async {
      final EditableLabReferenceRange range = EditableLabReferenceRange(
        defaultLabel: 'All ages',
      );
      addTearDown(range.dispose);

      await _pumpRangeEditor(tester, range);

      expect(range.allAges, isTrue);
      expect(_chipWithLabel(tester, 'All ages').selected, isTrue);

      await tester.tap(find.widgetWithText(FilterChip, 'Adult'));
      await tester.pumpAndSettle();
      expect(range.allAges, isFalse);
      expect(range.selectedAgePresetIds, <String>{'adult'});
      expect(range.ageMinController.text, '18');
      expect(range.ageMaxController.text, '64');
      expect(find.text('Age min'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Neonate'));
      await tester.pumpAndSettle();
      expect(range.selectedAgePresetIds, <String>{'adult', 'neonate'});
      expect(range.hasMultipleAgePresets, isTrue);
      expect(find.text('Age min'), findsNothing);
      expect(
        find.text(
          'Each selected age band is saved as its own reference range with these result limits.',
        ),
        findsOneWidget,
      );

      final List<Map<String, Object?>> payloads = range.toPayloads(
        startSortOrder: 0,
        fallbackUnit: 'g/dL',
      );
      expect(payloads, hasLength(2));
      expect(payloads.map((Map<String, Object?> p) => p['label']),
          containsAll(<String>['Neonate', 'Adult']));
      expect(
        payloads.firstWhere(
          (Map<String, Object?> p) => p['label'] == 'Neonate',
        )['age_min_unit'],
        'DAY',
      );
      expect(
        payloads.firstWhere(
          (Map<String, Object?> p) => p['label'] == 'Adult',
        )['age_min_value'],
        '18',
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Adult'));
      await tester.pumpAndSettle();
      expect(range.selectedAgePresetIds, <String>{'neonate'});
      expect(find.text('Age min'), findsOneWidget);

      await tester.tap(find.text('All ages'));
      await tester.pumpAndSettle();
      expect(range.allAges, isTrue);
      expect(range.selectedAgePresetIds, isEmpty);
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
    expect(range.selectedAgePresetIds, <String>{'geriatric'});
    expect(range.ageMinController.text, '65');
    expect(range.ageMaxController.text, isEmpty);
    expect(range.labelController.text, 'Geriatric');
    expect(range.matchingAgePresetId(), 'geriatric');
  });

  test('labAgeBandPresetIcon covers all catalog age bands', () {
    expect(labAgeBandPresetIcon('neonate'), Icons.baby_changing_station_outlined);
    expect(labAgeBandPresetIcon('infant'), Icons.child_care_outlined);
    expect(labAgeBandPresetIcon('child'), Icons.face_outlined);
    expect(labAgeBandPresetIcon('adolescent'), Icons.school_outlined);
    expect(labAgeBandPresetIcon('adult'), Icons.person_outline);
    expect(labAgeBandPresetIcon('geriatric'), Icons.elderly);
    expect(labAgeBandPresetIcon('pediatric'), Icons.family_restroom);
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
