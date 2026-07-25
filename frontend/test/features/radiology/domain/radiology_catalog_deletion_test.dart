import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';

void main() {
  group('RadiologyCatalogProcedure deletion lifecycle', () {
    test('isDeleted follows deletedAt and clearDeletedAt resets it', () {
      final RadiologyCatalogProcedure active = RadiologyCatalogProcedure(
        id: 'proc-1',
        name: 'Chest X-Ray',
        tenantId: 'tenant-1',
        tenantName: 'Acme Health',
      );
      expect(active.isDeleted, isFalse);
      expect(active.catalogScopeLabel, 'Acme Health');

      final RadiologyCatalogProcedure softDeleted = active.copyWith(
        deletedAt: DateTime.utc(2026, 1, 1),
      );
      expect(softDeleted.isDeleted, isTrue);

      final RadiologyCatalogProcedure restored = softDeleted.copyWith(
        clearDeletedAt: true,
      );
      expect(restored.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);
    });

    test('catalogScopeLabel falls back to tenantId then empty', () {
      expect(
        const RadiologyCatalogProcedure(
          id: 'proc-2',
          name: 'MRI Brain',
          tenantId: 'tenant-2',
        ).catalogScopeLabel,
        'tenant-2',
      );
      expect(
        const RadiologyCatalogProcedure(
          id: 'proc-3',
          name: 'CT Abdomen',
        ).catalogScopeLabel,
        isEmpty,
      );
    });
  });
}
