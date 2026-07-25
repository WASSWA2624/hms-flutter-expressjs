import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/radiology/data/dtos/radiology_dtos.dart';
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

    test('DTO maps deleted_at, tenant scope, and soft-delete status', () {
      final RadiologyCatalogProcedure procedure =
          RadiologyCatalogProcedureDto(const <String, Object?>{
            'id': 'proc-4',
            'name': 'CT Chest',
            'tenant_id': 'tenant-4',
            'tenant_name': 'North Clinic',
            'deleted_at': '2026-07-25T12:00:00.000Z',
          }).toEntity();

      expect(procedure.isDeleted, isTrue);
      expect(procedure.tenantId, 'tenant-4');
      expect(procedure.tenantName, 'North Clinic');
      expect(procedure.catalogScopeLabel, 'North Clinic');
      expect(procedure.deletedAt, isNotNull);
    });

    test('DTO nested tenant name maps when tenant_name absent', () {
      final RadiologyCatalogProcedure procedure =
          RadiologyCatalogProcedureDto(const <String, Object?>{
            'id': 'proc-5',
            'name': 'Ultrasound Abdomen',
            'tenant': <String, Object?>{
              'id': 'tenant-5',
              'name': 'South Clinic',
            },
          }).toEntity();

      expect(procedure.isDeleted, isFalse);
      expect(procedure.tenantId, 'tenant-5');
      expect(procedure.tenantName, 'South Clinic');
    });
  });
}
