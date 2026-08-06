import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';

void main() {
  group('clinicalPrescriptionCardTitle', () {
    test('formats generic, optional brand, strength, and qty', () {
      const ClinicalActionCatalogOption withBrand = ClinicalActionCatalogOption(
        id: '1',
        name: 'Acyclovir',
        metadata: <String, Object?>{
          'generic_name': 'Acyclovir',
          'brand_name': 'Zovirax',
          'strength': '400 mg',
        },
      );
      expect(
        clinicalPrescriptionCardTitle(drug: withBrand, quantity: 14),
        'Acyclovir (Zovirax) - 400 mg - Qty: 14',
      );

      const ClinicalActionCatalogOption withoutBrand =
          ClinicalActionCatalogOption(
            id: '2',
            name: 'Amoxicillin',
            metadata: <String, Object?>{
              'generic_name': 'Amoxicillin',
              'strength': '500 mg',
            },
          );
      expect(
        clinicalPrescriptionCardTitle(drug: withoutBrand, quantity: 7),
        'Amoxicillin - 500 mg - Qty: 7',
      );
    });

    test('omits brand when it matches generic', () {
      const ClinicalActionCatalogOption option = ClinicalActionCatalogOption(
        id: '3',
        name: 'Ibuprofen',
        metadata: <String, Object?>{
          'generic_name': 'Ibuprofen',
          'brand_name': 'Ibuprofen',
          'strength': '200 mg',
        },
      );
      expect(
        clinicalPrescriptionCardTitle(drug: option, quantity: 10),
        'Ibuprofen - 200 mg - Qty: 10',
      );
    });
  });
}
