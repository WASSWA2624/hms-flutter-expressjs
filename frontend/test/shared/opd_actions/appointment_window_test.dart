import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_time_value.dart';
import 'package:hosspi_hms/shared/opd_actions/appointment_window.dart';

void main() {
  group('AppointmentWindow.durationBetween', () {
    test('measures a same-day window', () {
      expect(
        AppointmentWindow.durationBetween(
          const AppTimeValue(hour: 9, minute: 0),
          const AppTimeValue(hour: 10, minute: 15),
        ),
        75,
      );
    });

    test('wraps a window that crosses midnight', () {
      expect(
        AppointmentWindow.durationBetween(
          const AppTimeValue(hour: 23, minute: 30),
          const AppTimeValue(hour: 0, minute: 30),
        ),
        60,
      );
    });

    test('treats an end equal to the start as a full day, not zero', () {
      final int? minutes = AppointmentWindow.durationBetween(
        const AppTimeValue(hour: 9, minute: 0),
        const AppTimeValue(hour: 9, minute: 0),
      );
      expect(minutes, AppointmentWindow.minutesPerDay);
      expect(AppointmentWindow.isValidDuration(minutes), isFalse);
    });

    test('needs both ends of the window', () {
      expect(
        AppointmentWindow.durationBetween(
          const AppTimeValue(hour: 9, minute: 0),
          null,
        ),
        isNull,
      );
      expect(
        AppointmentWindow.durationBetween(
          null,
          const AppTimeValue(hour: 9, minute: 0),
        ),
        isNull,
      );
    });
  });

  group('AppointmentWindow.endAfter', () {
    test('adds the duration to the start', () {
      expect(
        AppointmentWindow.endAfter(const AppTimeValue(hour: 9, minute: 0), 45),
        const AppTimeValue(hour: 9, minute: 45),
      );
    });

    test('wraps past midnight', () {
      expect(
        AppointmentWindow.endAfter(
          const AppTimeValue(hour: 23, minute: 30),
          60,
        ),
        const AppTimeValue(hour: 0, minute: 30),
      );
    });

    test('rejects a missing start or a non-positive duration', () {
      expect(AppointmentWindow.endAfter(null, 30), isNull);
      expect(
        AppointmentWindow.endAfter(const AppTimeValue(hour: 9, minute: 0), 0),
        isNull,
      );
      expect(
        AppointmentWindow.endAfter(
          const AppTimeValue(hour: 9, minute: 0),
          null,
        ),
        isNull,
      );
    });
  });

  group('AppointmentWindow.resolveMinutes', () {
    test('prefers the typed duration', () {
      expect(
        AppointmentWindow.resolveMinutes(
          duration: '20',
          start: const AppTimeValue(hour: 9, minute: 0),
          end: const AppTimeValue(hour: 11, minute: 0),
        ),
        20,
      );
    });

    test('falls back to the end time when the duration is blank', () {
      expect(
        AppointmentWindow.resolveMinutes(
          duration: '',
          start: const AppTimeValue(hour: 9, minute: 0),
          end: const AppTimeValue(hour: 11, minute: 0),
        ),
        120,
      );
    });

    test('returns null when neither side describes a usable window', () {
      expect(
        AppointmentWindow.resolveMinutes(
          duration: '',
          start: const AppTimeValue(hour: 9, minute: 0),
          end: null,
        ),
        isNull,
      );
      expect(
        AppointmentWindow.resolveMinutes(
          duration: '900',
          start: const AppTimeValue(hour: 9, minute: 0),
          end: null,
        ),
        isNull,
      );
    });
  });
}
