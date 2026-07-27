import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/department_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

void main() {
  group('department similarity', () {
    const DepartmentProfile existing = DepartmentProfile(
      id: 'dept-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      name: 'Emergency Department',
      shortName: 'ER',
      type: DepartmentSetupType.clinical,
    );

    test('detects exact name conflict within facility peers', () {
      final DepartmentDuplicateCheckResult result = checkDepartmentDuplicates(
        name: 'Emergency Department',
        shortName: 'ER',
        type: DepartmentSetupType.clinical,
        isActive: true,
        existing: const <DepartmentProfile>[existing],
      );

      expect(result.exactNameConflict, isTrue);
      expect(result.similarMatches.first.isExact, isTrue);
    });

    test('returns overridable similar matches for near names', () {
      final DepartmentDuplicateCheckResult result = checkDepartmentDuplicates(
        name: 'Emergancy Departmnt',
        shortName: 'ER',
        type: DepartmentSetupType.clinical,
        isActive: true,
        existing: const <DepartmentProfile>[existing],
      );

      expect(result.exactNameConflict, isFalse);
      expect(result.overridableMatches, isNotEmpty);
      expect(
        result.overridableMatches.first.score,
        greaterThanOrEqualTo(departmentSimilarityThreshold),
      );
    });

    test('flags stem or containment near-matches such as test vs Testing', () {
      const DepartmentProfile testing = DepartmentProfile(
        id: 'dept-2',
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        name: 'Testing',
        shortName: 'Testing',
        type: DepartmentSetupType.clinical,
      );

      final DepartmentDuplicateCheckResult result = checkDepartmentDuplicates(
        name: 'test',
        shortName: 'test',
        type: DepartmentSetupType.clinical,
        isActive: true,
        existing: const <DepartmentProfile>[testing],
      );

      expect(result.exactNameConflict, isFalse);
      expect(result.overridableMatches, isNotEmpty);
      expect(
        result.overridableMatches.first.nameScore,
        greaterThanOrEqualTo(departmentSimilarityThreshold),
      );
      expect(
        result.overridableMatches.first.score,
        greaterThanOrEqualTo(departmentSimilarityThreshold),
      );
    });

    test('defaults empty short name to department name', () {
      expect(resolveDepartmentShortName('Cardiology', null), 'Cardiology');
      expect(resolveDepartmentShortName('Cardiology', '  '), 'Cardiology');
      expect(resolveDepartmentShortName('Cardiology', 'Cardio'), 'Cardio');
    });

    test('excludes the edited department id', () {
      final DepartmentDuplicateCheckResult result = checkDepartmentDuplicates(
        name: 'Emergency Department',
        shortName: 'ER',
        type: DepartmentSetupType.clinical,
        isActive: true,
        existing: const <DepartmentProfile>[existing],
        excludeDepartmentId: 'dept-1',
      );

      expect(result.exactNameConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });
  });
}
