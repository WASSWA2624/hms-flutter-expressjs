import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_radiology_catalog_helpers.dart';

void main() {
  group('clinicalRadiologyOptionBodyRegion', () {
    test('returns metadata body region', () {
      const ClinicalActionCatalogOption option = ClinicalActionCatalogOption(
        id: 'rad-1',
        name: 'CT chest',
        metadata: <String, Object?>{'body_region': 'Chest'},
      );

      expect(clinicalRadiologyOptionBodyRegion(option), 'Chest');
    });

    test('ignores catalog source secondary text', () {
      const ClinicalActionCatalogOption option = ClinicalActionCatalogOption(
        id: 'rad-2',
        name: 'Transvaginal Pelvic Ultrasound',
        category: 'ULTRASOUND',
        secondaryText: 'FACILITY',
        metadata: <String, Object?>{'modality': 'ULTRASOUND'},
      );

      expect(clinicalRadiologyOptionBodyRegion(option), isNull);
    });
  });

  group('orderClinicalRadiologyRequestCatalogItems', () {
    const ClinicalActionCatalogOption first = ClinicalActionCatalogOption(
      id: 'first',
      name: 'First',
    );
    const ClinicalActionCatalogOption second = ClinicalActionCatalogOption(
      id: 'second',
      name: 'Second',
    );
    const ClinicalActionCatalogOption third = ClinicalActionCatalogOption(
      id: 'third',
      name: 'Third',
    );

    test('places most recently selected item first', () {
      final List<ClinicalActionCatalogOption> ordered =
          orderClinicalRadiologyRequestCatalogItems(
            <ClinicalActionCatalogOption>[first, second, third],
            includeOption: (_) => true,
            isSelected: (ClinicalActionCatalogOption option) =>
                option.id == 'second' || option.id == 'third',
            selectionOrder: <String>['third', 'second'],
          );

      expect(
        ordered.map((ClinicalActionCatalogOption item) => item.id).toList(),
        <String>['third', 'second', 'first'],
      );
    });
  });
}
