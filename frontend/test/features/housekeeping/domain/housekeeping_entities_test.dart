import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';

void main() {
  group('HousekeepingSection', () {
    test('maps each section to the matching resource', () {
      expect(HousekeepingSection.tasks.resource, HousekeepingResource.tasks);
      expect(
        HousekeepingSection.schedules.resource,
        HousekeepingResource.schedules,
      );
      expect(
        HousekeepingSection.maintenance.resource,
        HousekeepingResource.maintenanceRequests,
      );
    });

    test('fromQueryValue parses known values and defaults to tasks', () {
      expect(
        HousekeepingSection.fromQueryValue('tasks'),
        HousekeepingSection.tasks,
      );
      expect(
        HousekeepingSection.fromQueryValue('SCHEDULES'),
        HousekeepingSection.schedules,
      );
      expect(
        HousekeepingSection.fromQueryValue(' maintenance '),
        HousekeepingSection.maintenance,
      );
      expect(
        HousekeepingSection.fromQueryValue(null),
        HousekeepingSection.tasks,
      );
      expect(
        HousekeepingSection.fromQueryValue('unknown'),
        HousekeepingSection.tasks,
      );
    });

    test('queryValue returns stable route tokens', () {
      expect(HousekeepingSection.tasks.queryValue, 'tasks');
      expect(HousekeepingSection.schedules.queryValue, 'schedules');
      expect(HousekeepingSection.maintenance.queryValue, 'maintenance');
    });
  });
}
