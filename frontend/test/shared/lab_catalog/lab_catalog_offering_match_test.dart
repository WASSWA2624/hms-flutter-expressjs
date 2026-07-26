import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_offering_match.dart';

void main() {
  group('markLabCatalogItemsOfferedAtFacility', () {
    test('marks by apiId', () {
      const LabCatalogItem platform = LabCatalogItem(
        id: 'LBP0000001',
        type: LabCatalogItemType.panel,
        name: 'Abdominal Pain Panel',
        code: 'ABDP',
      );
      const LabCatalogItem offered = LabCatalogItem(
        id: 'LBP0000001',
        type: LabCatalogItemType.panel,
        name: 'Abdominal Pain Panel',
        code: 'ABDP',
        unitPrice: 102000,
        isOfferedAtFacility: true,
      );

      final List<LabCatalogItem> marked = markLabCatalogItemsOfferedAtFacility(
        platformItems: const <LabCatalogItem>[platform],
        offeredItems: const <LabCatalogItem>[offered],
      );

      expect(marked.single.isOfferedAtFacility, isTrue);
    });

    test('marks by code when ids differ', () {
      const LabCatalogItem platform = LabCatalogItem(
        id: 'STD_LAB_PANEL:abdp',
        type: LabCatalogItemType.panel,
        name: 'Abdominal Pain Panel',
        code: 'ABDP',
      );
      const LabCatalogItem offered = LabCatalogItem(
        id: 'LBP0000001',
        type: LabCatalogItemType.panel,
        name: 'Abdominal Pain Panel',
        code: 'abdp',
        unitPrice: 102000,
        isOfferedAtFacility: true,
      );

      final List<LabCatalogItem> marked = markLabCatalogItemsOfferedAtFacility(
        platformItems: const <LabCatalogItem>[platform],
        offeredItems: const <LabCatalogItem>[offered],
      );

      expect(marked.single.isOfferedAtFacility, isTrue);
    });

    test('marks by name when ids and codes differ', () {
      const LabCatalogItem platform = LabCatalogItem(
        id: 'STD_LAB_PANEL:other',
        type: LabCatalogItemType.panel,
        name: 'Abdominal Pain Panel',
        code: 'OTHER',
      );
      const LabCatalogItem offered = LabCatalogItem(
        id: 'LBP0000001',
        type: LabCatalogItemType.panel,
        name: 'abdominal pain panel',
        code: 'ABDP',
        unitPrice: 102000,
        isOfferedAtFacility: true,
      );

      final List<LabCatalogItem> marked = markLabCatalogItemsOfferedAtFacility(
        platformItems: const <LabCatalogItem>[platform],
        offeredItems: const <LabCatalogItem>[offered],
      );

      expect(marked.single.isOfferedAtFacility, isTrue);
    });

    test('leaves unmatched catalog rows available', () {
      const LabCatalogItem platform = LabCatalogItem(
        id: 'LBT0000001',
        type: LabCatalogItemType.test,
        name: 'Complete blood count',
        code: 'CBC',
      );

      final List<LabCatalogItem> marked = markLabCatalogItemsOfferedAtFacility(
        platformItems: const <LabCatalogItem>[platform],
        offeredItems: const <LabCatalogItem>[
          LabCatalogItem(
            id: 'LBP0000001',
            type: LabCatalogItemType.panel,
            name: 'Abdominal Pain Panel',
            code: 'ABDP',
            isOfferedAtFacility: true,
          ),
        ],
      );

      expect(marked, hasLength(2));
      expect(
        marked.firstWhere((LabCatalogItem item) => item.id == 'LBT0000001')
            .isOfferedAtFacility,
        isFalse,
      );
      expect(
        marked.firstWhere((LabCatalogItem item) => item.id == 'LBP0000001')
            .isOfferedAtFacility,
        isTrue,
      );
    });

    test('appends offered items missing from the platform page', () {
      const LabCatalogItem platform = LabCatalogItem(
        id: 'LBT0000001',
        type: LabCatalogItemType.test,
        name: 'Complete blood count',
        code: 'CBC',
      );
      const LabCatalogItem offeredOnly = LabCatalogItem(
        id: 'LBP0000099',
        type: LabCatalogItemType.panel,
        name: 'Facility only panel',
        code: 'FOP',
        unitPrice: 5000,
        isOfferedAtFacility: true,
      );

      final List<LabCatalogItem> marked = markLabCatalogItemsOfferedAtFacility(
        platformItems: const <LabCatalogItem>[platform],
        offeredItems: const <LabCatalogItem>[offeredOnly],
      );

      expect(marked, hasLength(2));
      expect(marked.last.id, 'LBP0000099');
      expect(marked.last.isOfferedAtFacility, isTrue);
    });

    test('returns offered items when platform page is empty', () {
      const LabCatalogItem offered = LabCatalogItem(
        id: 'LBT0000002',
        type: LabCatalogItemType.test,
        name: 'Lipid panel',
        code: 'LIP',
        isOfferedAtFacility: true,
      );

      final List<LabCatalogItem> marked = markLabCatalogItemsOfferedAtFacility(
        platformItems: const <LabCatalogItem>[],
        offeredItems: const <LabCatalogItem>[offered],
      );

      expect(marked, hasLength(1));
      expect(marked.single.isOfferedAtFacility, isTrue);
      expect(marked.single.code, 'LIP');
    });
  });
}
