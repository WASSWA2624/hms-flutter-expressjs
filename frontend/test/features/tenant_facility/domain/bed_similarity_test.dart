import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/bed_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

void main() {
  group('checkBedDuplicates', () {
    const BedProfile existing = BedProfile(
      id: 'b1',
      tenantId: 't1',
      facilityId: 'f1',
      wardId: 'w1',
      label: 'Bed A1',
      status: BedSetupStatus.available,
      roomId: 'r1',
    );

    test('flags exact label conflict in the same ward', () {
      final BedDuplicateCheckResult result = checkBedDuplicates(
        label: 'Bed A1',
        status: BedSetupStatus.available,
        wardId: 'w1',
        roomId: 'r1',
        wardName: 'General',
        roomName: '101',
        existing: const <BedProfile>[existing],
      );

      expect(result.exactLabelConflict, isTrue);
      expect(result.similarMatches, isNotEmpty);
      expect(result.similarMatches.first.exactLabelConflict, isTrue);
    });

    test('excludes the bed being edited', () {
      final BedDuplicateCheckResult result = checkBedDuplicates(
        label: 'Bed A1',
        status: BedSetupStatus.available,
        wardId: 'w1',
        existing: const <BedProfile>[existing],
        excludeBedId: 'b1',
      );

      expect(result.exactLabelConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });

    test('surfaces near matches without exact conflict', () {
      final BedDuplicateCheckResult result = checkBedDuplicates(
        label: 'Bed A1x',
        status: BedSetupStatus.available,
        wardId: 'w1',
        existing: const <BedProfile>[existing],
      );

      expect(result.exactLabelConflict, isFalse);
      expect(result.similarMatches, isNotEmpty);
      expect(result.similarMatches.first.score, greaterThan(0));
    });

    test('same label in a different ward is not an exact conflict', () {
      final BedDuplicateCheckResult result = checkBedDuplicates(
        label: 'Bed A1',
        status: BedSetupStatus.available,
        wardId: 'w2',
        existing: const <BedProfile>[existing],
      );

      expect(result.exactLabelConflict, isFalse);
      expect(result.similarMatches, isNotEmpty);
    });
  });
}
