import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_list_field.dart';

void main() {
  testWidgets(
    'All genders selection disables specific gender chips',
    (WidgetTester tester) async {
      final EditableLabReferenceRange range = EditableLabReferenceRange();
      addTearDown(range.dispose);

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

      expect(find.text('All genders'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);

      final FilterChip male = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Male'),
      );
      final FilterChip all = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'All genders'),
      );
      expect(all.selected, isTrue);
      expect(male.onSelected, isNull);

      // Deselect All → specifics become active (defaults to Male).
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'All genders'));
      await tester.tap(find.widgetWithText(FilterChip, 'All genders'));
      await tester.pumpAndSettle();

      expect(range.gender, 'MALE');
      final FilterChip maleAfter = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Male'),
      );
      expect(maleAfter.onSelected, isNotNull);
      expect(maleAfter.selected, isTrue);

      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Female'));
      await tester.tap(find.widgetWithText(FilterChip, 'Female'));
      await tester.pumpAndSettle();

      expect(range.gender, 'FEMALE');
      final FilterChip female = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Female'),
      );
      final FilterChip allAfter = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'All genders'),
      );
      expect(female.selected, isTrue);
      expect(allAfter.selected, isFalse);
    },
  );
}
