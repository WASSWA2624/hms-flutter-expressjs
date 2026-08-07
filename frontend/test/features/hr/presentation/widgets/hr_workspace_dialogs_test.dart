import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_queue_switcher.dart';

void main() {
  group('hr workspace dialogs support', () {
    test('dialog queue facet exposes overdue when deep-linked', () {
      final List<HrQueue> queues = hrQueuesForSection(
        null,
        HrQueue.overdueShifts,
      );

      expect(queues, contains(HrQueue.overdueShifts));
    });

    test('HrWorkspaceController day bounds cover a local calendar day', () {
      final DateTime reference = DateTime(2026, 6, 30, 15, 30);
      final DateTime start = HrWorkspaceController.startOfLocalDay(reference);
      final DateTime end = HrWorkspaceController.endOfLocalDay(reference);

      expect(start, DateTime(2026, 6, 30));
      expect(end.isAfter(start), isTrue);
      expect(end.day, 30);
    });
  });
}
