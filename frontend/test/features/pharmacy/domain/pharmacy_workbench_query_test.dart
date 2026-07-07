import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';

void main() {
  group('PharmacyWorkbenchQuery', () {
    test('defaults to all statuses with no active filters', () {
      const PharmacyWorkbenchQuery query = PharmacyWorkbenchQuery();

      expect(query.status, isNull);
      expect(query.isDefaultFilters, isTrue);
    });

    test('ready chip applies ORDERED status filter', () {
      final PharmacyWorkbenchQuery query = PharmacyWorkbenchQuery.fromChip(
        PharmacyOrderFilter.ready,
      );

      expect(query.status, 'ORDERED');
      expect(query.isDefaultFilters, isFalse);
    });

    test('all chip clears status filter', () {
      final PharmacyWorkbenchQuery query = PharmacyWorkbenchQuery.fromChip(
        PharmacyOrderFilter.all,
      );

      expect(query.status, isNull);
      expect(query.isDefaultFilters, isTrue);
    });
  });
}
