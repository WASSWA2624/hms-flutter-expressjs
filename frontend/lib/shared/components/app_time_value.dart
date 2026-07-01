import 'package:flutter/material.dart';

/// Canonical time value for [AppTimeField]; hours are always stored in 24-hour form.
class AppTimeValue {
  const AppTimeValue({
    required this.hour,
    required this.minute,
    this.second = 0,
  }) : assert(hour >= 0 && hour <= 23),
       assert(minute >= 0 && minute <= 59),
       assert(second >= 0 && second <= 59);

  final int hour;
  final int minute;
  final int second;

  factory AppTimeValue.fromTimeOfDay(TimeOfDay time, {int second = 0}) {
    return AppTimeValue(hour: time.hour, minute: time.minute, second: second);
  }

  factory AppTimeValue.now() {
    final DateTime now = DateTime.now();
    return AppTimeValue(hour: now.hour, minute: now.minute, second: now.second);
  }

  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);

  int get totalMinutes => hour * 60 + minute;

  int get totalSeconds => hour * 3600 + minute * 60 + second;

  bool isAfter(AppTimeValue other) => totalSeconds > other.totalSeconds;

  bool isBefore(AppTimeValue other) => totalSeconds < other.totalSeconds;

  String format24({bool includeSeconds = false}) {
    final String hh = hour.toString().padLeft(2, '0');
    final String mm = minute.toString().padLeft(2, '0');
    if (!includeSeconds) {
      return '$hh:$mm';
    }
    final String ss = second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String format12({bool includeSeconds = false}) {
    final int displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final String hh = displayHour.toString().padLeft(2, '0');
    final String mm = minute.toString().padLeft(2, '0');
    final String period = hour >= 12 ? 'PM' : 'AM';
    if (!includeSeconds) {
      return '$hh:$mm $period';
    }
    final String ss = second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss $period';
  }

  static AppTimeValue? parse(
    String raw, {
    bool includeSeconds = false,
    bool allow12Hour = true,
  }) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final RegExp twelveHourPattern = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM|am|pm)$',
    );
    final RegExp twentyFourHourPattern = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
    );

    RegExpMatch? match = twelveHourPattern.firstMatch(trimmed);
    if (match != null && allow12Hour) {
      final int? parsedHour = int.tryParse(match.group(1)!);
      final int? parsedMinute = int.tryParse(match.group(2)!);
      final int? parsedSecond = match.group(3) == null
          ? 0
          : int.tryParse(match.group(3)!);
      if (parsedHour == null ||
          parsedMinute == null ||
          parsedSecond == null ||
          parsedHour < 1 ||
          parsedHour > 12 ||
          parsedMinute > 59 ||
          parsedSecond > 59) {
        return null;
      }

      final String period = match.group(4)!.toUpperCase();
      final int hour = period == 'AM'
          ? (parsedHour == 12 ? 0 : parsedHour)
          : (parsedHour == 12 ? 12 : parsedHour + 12);
      return AppTimeValue(
        hour: hour,
        minute: parsedMinute,
        second: parsedSecond,
      );
    }

    match = twentyFourHourPattern.firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    final int? hour = int.tryParse(match.group(1)!);
    final int? parsedMinute = int.tryParse(match.group(2)!);
    final int? parsedSecond = match.group(3) == null
        ? 0
        : int.tryParse(match.group(3)!);
    if (hour == null ||
        parsedMinute == null ||
        parsedSecond == null ||
        hour > 23 ||
        parsedMinute > 59 ||
        parsedSecond > 59) {
      return null;
    }

    return AppTimeValue(hour: hour, minute: parsedMinute, second: parsedSecond);
  }

  @override
  bool operator ==(Object other) {
    return other is AppTimeValue &&
        other.hour == hour &&
        other.minute == minute &&
        other.second == second;
  }

  @override
  int get hashCode => Object.hash(hour, minute, second);
}
