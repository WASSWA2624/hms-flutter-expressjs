import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  testWidgets('HrWeeklyScheduleEditor adds slot and opens duplicate dialog', (
    WidgetTester tester,
  ) async {
    final HrWeeklyScheduleDraft schedule = HrWeeklyScheduleDraft(
      weekdayDefaults: true,
    );

    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return HrWeeklyScheduleEditor(
                  schedule: schedule,
                  onChanged: () => setState(() {}),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly schedule'), findsOneWidget);
    expect(find.textContaining('08:00-17:00'), findsNWidgets(5));

    await tester.tap(find.text('Add slot').first);
    await tester.pumpAndSettle();
    expect(find.text('08'), findsWidgets);

    await tester.tap(find.text('Duplicate to…').first);
    await tester.pumpAndSettle();
    expect(find.text('Duplicate schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);

    schedule.dispose();
  });

  test('HrWeeklyScheduleDraft rejects overlapping slots', () {
    final HrWeeklyScheduleDraft schedule = HrWeeklyScheduleDraft();
    final HrDayScheduleDraft monday = schedule.days[1]!;
    monday.slots.clear();
    final HrScheduleSlotDraft first = HrScheduleSlotDraft()
      ..start = const AppTimeValue(hour: 8, minute: 0)
      ..end = const AppTimeValue(hour: 12, minute: 0);
    final HrScheduleSlotDraft second = HrScheduleSlotDraft()
      ..start = const AppTimeValue(hour: 11, minute: 0)
      ..end = const AppTimeValue(hour: 15, minute: 0);
    monday.slots
      ..clear()
      ..addAll(<HrScheduleSlotDraft>[first, second]);

    final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
    expect(schedule.validate(l10n), isNotNull);
    schedule.dispose();
  });
}
