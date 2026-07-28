import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/unit_similarity.dart';

void main() {
  group('checkUnitDuplicates', () {
    const UnitProfile existing = UnitProfile(
      id: 'u1',
      tenantId: 't1',
      name: 'Cardiology Unit',
      facilityId: 'f1',
      departmentId: 'd1',
    );

    test('flags exact name conflict in the same department', () {
      final UnitDuplicateCheckResult result = checkUnitDuplicates(
        name: 'Cardiology Unit',
        isActive: true,
        departmentId: 'd1',
        departmentName: 'Cardiology',
        existing: const <UnitProfile>[existing],
      );

      expect(result.exactNameConflict, isTrue);
      expect(result.similarMatches, isNotEmpty);
      expect(result.similarMatches.first.exactNameConflict, isTrue);
    });

    test('excludes the unit being edited', () {
      final UnitDuplicateCheckResult result = checkUnitDuplicates(
        name: 'Cardiology Unit',
        isActive: true,
        departmentId: 'd1',
        existing: const <UnitProfile>[existing],
        excludeUnitId: 'u1',
      );

      expect(result.exactNameConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });

    test('surfaces near matches without exact conflict', () {
      final UnitDuplicateCheckResult result = checkUnitDuplicates(
        name: 'Cardiology Unti',
        isActive: true,
        departmentId: 'd1',
        existing: const <UnitProfile>[existing],
      );

      expect(result.exactNameConflict, isFalse);
      expect(result.similarMatches, isNotEmpty);
      expect(result.similarMatches.first.score, greaterThan(0));
    });
  });
}
