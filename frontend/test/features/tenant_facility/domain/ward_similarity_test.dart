import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/ward_similarity.dart';

void main() {
  group('checkWardDuplicates', () {
    const WardProfile existing = WardProfile(
      id: 'w1',
      tenantId: 't1',
      facilityId: 'f1',
      name: 'General Ward A',
      type: WardSetupType.general,
      departmentId: 'd1',
    );

    test('flags exact name conflict in the facility', () {
      final WardDuplicateCheckResult result = checkWardDuplicates(
        name: 'General Ward A',
        type: WardSetupType.general,
        isActive: true,
        departmentId: 'd1',
        departmentName: 'Medicine',
        existing: const <WardProfile>[existing],
      );

      expect(result.exactNameConflict, isTrue);
      expect(result.similarMatches, isNotEmpty);
      expect(result.similarMatches.first.exactNameConflict, isTrue);
    });

    test('excludes the ward being edited', () {
      final WardDuplicateCheckResult result = checkWardDuplicates(
        name: 'General Ward A',
        type: WardSetupType.general,
        isActive: true,
        departmentId: 'd1',
        existing: const <WardProfile>[existing],
        excludeWardId: 'w1',
      );

      expect(result.exactNameConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });

    test('surfaces near matches without exact conflict', () {
      final WardDuplicateCheckResult result = checkWardDuplicates(
        name: 'General Ward Aa',
        type: WardSetupType.general,
        isActive: true,
        departmentId: 'd1',
        existing: const <WardProfile>[existing],
      );

      expect(result.exactNameConflict, isFalse);
      expect(result.similarMatches, isNotEmpty);
      expect(result.similarMatches.first.score, greaterThan(0));
    });
  });
}
