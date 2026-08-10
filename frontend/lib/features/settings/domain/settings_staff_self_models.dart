import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_calendar_preview.dart';

@immutable
final class SettingsStaffShift {
  const SettingsStaffShift({
    required this.id,
    required this.start,
    required this.end,
    this.shiftType,
    this.status,
    this.displayId,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String? shiftType;
  final String? status;
  final String? displayId;
}

enum SettingsRosterPeriodPreset {
  today,
  tomorrow,
  thisWeek,
  thisMonth,
  lastMonth,
  nextMonth,
  nextThreeMonths,
  custom,
}

(DateTime, DateTime) settingsRosterPeriodRange(
  SettingsRosterPeriodPreset preset, {
  DateTime? customStart,
  DateTime? customEnd,
  DateTime? now,
}) {
  final DateTime anchor = now ?? DateTime.now();
  final DateTime today = DateTime(anchor.year, anchor.month, anchor.day);
  switch (preset) {
    case SettingsRosterPeriodPreset.today:
      return (today, today);
    case SettingsRosterPeriodPreset.tomorrow:
      final DateTime tomorrow = today.add(const Duration(days: 1));
      return (tomorrow, tomorrow);
    case SettingsRosterPeriodPreset.thisWeek:
      final DateTime weekStart = today.subtract(
        Duration(days: today.weekday - DateTime.monday),
      );
      final DateTime weekEnd = weekStart.add(const Duration(days: 6));
      return (weekStart, weekEnd);
    case SettingsRosterPeriodPreset.thisMonth:
      final DateTime start = DateTime(today.year, today.month);
      final DateTime end = DateTime(today.year, today.month + 1, 0);
      return (start, end);
    case SettingsRosterPeriodPreset.lastMonth:
      final DateTime start = DateTime(today.year, today.month - 1);
      final DateTime end = DateTime(today.year, today.month, 0);
      return (start, end);
    case SettingsRosterPeriodPreset.nextMonth:
      final DateTime start = DateTime(today.year, today.month + 1);
      final DateTime end = DateTime(today.year, today.month + 2, 0);
      return (start, end);
    case SettingsRosterPeriodPreset.nextThreeMonths:
      final DateTime start = DateTime(today.year, today.month);
      final DateTime end = DateTime(today.year, today.month + 3, 0);
      return (start, end);
    case SettingsRosterPeriodPreset.custom:
      final DateTime start = customStart == null
          ? today
          : DateTime(customStart.year, customStart.month, customStart.day);
      final DateTime end = customEnd == null
          ? start
          : DateTime(customEnd.year, customEnd.month, customEnd.day);
      return start.isAfter(end) ? (end, start) : (start, end);
  }
}

List<HrRosterDayPreview> settingsStaffShiftsToDayPreviews(
  List<SettingsStaffShift> shifts, {
  required DateTime from,
  required DateTime to,
}) {
  final DateTime start = DateTime(from.year, from.month, from.day);
  final DateTime end = DateTime(to.year, to.month, to.day);
  final Map<String, List<HrRosterShiftWindow>> byDay =
      <String, List<HrRosterShiftWindow>>{};

  for (final SettingsStaffShift shift in shifts) {
    final DateTime localStart = shift.start.toLocal();
    final DateTime localEnd = shift.end.toLocal();
    final String key = hrRosterDateKey(localStart);
    byDay
        .putIfAbsent(key, () => <HrRosterShiftWindow>[])
        .add(
          HrRosterShiftWindow(
            start: localStart,
            end: localEnd,
            staffNames: const <String>[],
            shiftType: shift.shiftType,
          ),
        );
  }

  final List<HrRosterDayPreview> days = <HrRosterDayPreview>[];
  DateTime cursor = start;
  while (!cursor.isAfter(end)) {
    final String key = hrRosterDateKey(cursor);
    final List<HrRosterShiftWindow> dayShifts =
        List<HrRosterShiftWindow>.from(
          byDay[key] ?? const <HrRosterShiftWindow>[],
        )..sort(
          (HrRosterShiftWindow a, HrRosterShiftWindow b) =>
              a.start.compareTo(b.start),
        );
    final bool weekend =
        cursor.weekday == DateTime.saturday ||
        cursor.weekday == DateTime.sunday;
    days.add(
      HrRosterDayPreview(
        date: cursor,
        label: key,
        isHoliday: false,
        isWorkingDay: dayShifts.isNotEmpty || !weekend,
        dayStartMinutes: 8 * 60,
        dayEndMinutes: 17 * 60,
        shifts: dayShifts,
      ),
    );
    cursor = cursor.add(const Duration(days: 1));
  }
  return days;
}
