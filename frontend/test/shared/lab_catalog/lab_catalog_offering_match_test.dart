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

      expect(marked.single.isOfferedAtFacility, isFalse);
    });
  });
}
