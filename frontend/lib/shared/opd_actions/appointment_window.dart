import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_time_value.dart';

/// Start/end/duration arithmetic shared by the appointment scheduling forms.
///
/// Front desk staff think in either "ends at" or "runs for" terms, so the forms
/// accept whichever is entered and derive the other from it. Windows that cross
/// midnight wrap to the next day; the duration bounds below reject the absurd
/// spans that wrapping can otherwise hide (an end time equal to the start
/// resolves to a full day, not a zero-length meeting).
abstract final class AppointmentWindow {
  static const int minutesPerDay = 24 * 60;

  /// Longest schedulable appointment, matching the duration field's bounds.
  static const int maxDurationMinutes = 720;

  /// Minutes from [start] to [end], wrapping past midnight when [end] is not
  /// after [start]. Returns null when either end of the window is missing.
  static int? durationBetween(AppTimeValue? start, AppTimeValue? end) {
    if (start == null || end == null) {
      return null;
    }
    final int difference = end.totalMinutes - start.totalMinutes;
    return difference > 0 ? difference : difference + minutesPerDay;
  }

  /// Clock time [minutes] after [start], wrapping past midnight.
  ///
  /// Returns null for a missing start or a non-positive duration.
  static AppTimeValue? endAfter(AppTimeValue? start, int? minutes) {
    if (start == null || minutes == null || minutes <= 0) {
      return null;
    }
    final int total = (start.totalMinutes + minutes) % minutesPerDay;
    return AppTimeValue(hour: total ~/ 60, minute: total % 60);
  }

  /// Parses the duration field, returning null when it is empty or not a number.
  static int? parseDuration(String? raw) {
    return int.tryParse((raw ?? '').trim());
  }

  static bool isValidDuration(int? minutes) {
    return minutes != null && minutes > 0 && minutes <= maxDurationMinutes;
  }

  /// Minutes the appointment should be booked for, preferring the typed
  /// duration and falling back to the window the end time describes.
  static int? resolveMinutes({
    required String? duration,
    required AppTimeValue? start,
    required AppTimeValue? end,
  }) {
    final int? typed = parseDuration(duration);
    if (isValidDuration(typed)) {
      return typed;
    }
    final int? derived = durationBetween(start, end);
    return isValidDuration(derived) ? derived : null;
  }
}

/// Validates the duration field, accepting a blank value when the paired end
/// time already describes the window.
FormFieldValidator<String> appointmentDurationValidator({
  required AppLocalizations l10n,
  required ValueGetter<AppTimeValue?> startTime,
  required ValueGetter<AppTimeValue?> endTime,
}) {
  return (String? value) {
    final int? minutes = AppointmentWindow.parseDuration(value);
    if (minutes == null) {
      final int? derived = AppointmentWindow.durationBetween(
        startTime(),
        endTime(),
      );
      return derived == null
          ? l10n.patientsAppointmentWindowRequiredMessage
          : null;
    }
    return AppointmentWindow.isValidDuration(minutes)
        ? null
        : l10n.patientsDurationInvalidMessage;
  };
}

/// Validates the optional end time, accepting a blank value when the paired
/// duration already describes the window.
FormFieldValidator<AppTimeValue> appointmentEndTimeValidator({
  required AppLocalizations l10n,
  required ValueGetter<AppTimeValue?> startTime,
  required ValueGetter<String> duration,
}) {
  return (AppTimeValue? value) {
    if (value == null) {
      return AppointmentWindow.isValidDuration(
            AppointmentWindow.parseDuration(duration()),
          )
          ? null
          : l10n.patientsAppointmentWindowRequiredMessage;
    }
    final int? minutes = AppointmentWindow.durationBetween(startTime(), value);
    return AppointmentWindow.isValidDuration(minutes)
        ? null
        : l10n.patientsDurationInvalidMessage;
  };
}
