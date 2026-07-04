import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';

void main() {
  group('LabCatalogScope', () {
    test('isReady requires non-empty tenant and facility', () {
      expect(
        const LabCatalogScope(
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
        ).isReady,
        isTrue,
      );
      expect(
        const LabCatalogScope(tenantId: 'TEN0000001').isReady,
        isFalse,
      );
      expect(
        const LabCatalogScope(facilityId: 'FAC0000001').isReady,
        isFalse,
      );
    });

    test('apiParams includes trimmed scope identifiers', () {
      expect(
        const LabCatalogScope(
          tenantId: ' TEN0000001 ',
          facilityId: ' FAC0000001 ',
        ).apiParams,
        <String, Object?>{
          'tenant_id': 'TEN0000001',
          'facility_id': 'FAC0000001',
        },
      );
    });
  });

  test('labFacilityCatalogPageLimit respects backend pagination cap', () {
    expect(labFacilityCatalogPageLimit, lessThanOrEqualTo(100));
  });
}
