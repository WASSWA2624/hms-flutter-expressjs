import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_drug_catalog_mapper.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';

void main() {
  test('maps pharmacy drug fields into clinical catalog options', () {
    const PharmacyDrug drug = PharmacyDrug(
      id: 'DRG0001',
      displayId: 'DRG0001',
      name: 'Amoxicillin',
      code: 'AMOX',
      form: 'Capsule',
      strength: '500 mg',
      pharmacyUnitPrice: 12.5,
      pharmacyCurrency: 'UGX',
      genericName: 'Amoxicillin',
    );

    final ClinicalActionCatalogOption option =
        pharmacyDrugToClinicalCatalogOption(drug);

    expect(option.apiId, 'DRG0001');
    expect(option.name, 'Amoxicillin');
    expect(option.code, 'AMOX');
    expect(option.unitPrice, 12.5);
    expect(option.currency, 'UGX');
    expect(option.secondaryText, contains('Capsule'));
    expect(option.searchText, contains('AMOX'));
  });
}
