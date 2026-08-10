import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_calendar_preview.dart';
import 'package:hosspi_hms/features/settings/domain/settings_staff_self_models.dart';

void main() {
  group('settingsRosterPeriodRange', () {
    final DateTime now = DateTime(2026, 8, 10, 15, 30);

    test('today and tomorrow are single-day ranges', () {
      expect(
        settingsRosterPeriodRange(
          SettingsRosterPeriodPreset.today,
          now: now,
        ),
        (DateTime(2026, 8, 10), DateTime(2026, 8, 10)),
      );
      expect(
        settingsRosterPeriodRange(
          SettingsRosterPeriodPreset.tomorrow,
          now: now,
        ),
        (DateTime(2026, 8, 11), DateTime(2026, 8, 11)),
      );
    });

    test('this month covers the full calendar month', () {
      expect(
        settingsRosterPeriodRange(
          SettingsRosterPeriodPreset.thisMonth,
          now: now,
        ),
        (DateTime(2026, 8), DateTime(2026, 8, 31)),
      );
    });

    test('next three months starts this month and ends two months ahead', () {
      expect(
        settingsRosterPeriodRange(
          SettingsRosterPeriodPreset.nextThreeMonths,
          now: now,
        ),
        (DateTime(2026, 8), DateTime(2026, 10, 31)),
      );
    });

    test('custom range swaps inverted dates', () {
      expect(
        settingsRosterPeriodRange(
          SettingsRosterPeriodPreset.custom,
          customStart: DateTime(2026, 9, 5),
          customEnd: DateTime(2026, 9, 1),
          now: now,
        ),
        (DateTime(2026, 9, 1), DateTime(2026, 9, 5)),
      );
    });
  });

  group('settingsStaffShiftsToDayPreviews', () {
    test('groups shifts onto calendar days in the selected range', () {
      final List<HrRosterDayPreview> days = settingsStaffShiftsToDayPreviews(
        <SettingsStaffShift>[
          SettingsStaffShift(
            id: 'a1',
            start: DateTime(2026, 8, 10, 8),
            end: DateTime(2026, 8, 10, 16),
            shiftType: 'DAY',
          ),
        ],
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 11),
      );

      expect(days, hasLength(2));
      expect(days.first.shifts, hasLength(1));
      expect(days.last.shifts, isEmpty);
    });
  });
}
