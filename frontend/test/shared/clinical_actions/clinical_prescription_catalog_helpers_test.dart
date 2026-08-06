import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';

void main() {
  test('catalog helpers read stock and entity prices from metadata', () {
    const ClinicalActionCatalogOption option = ClinicalActionCatalogOption(
      id: 'd1',
      name: 'Drug',
      unitPrice: 5,
      metadata: <String, Object?>{
        'pharmacy_unit_price': 12,
        'facility_unit_price': 9,
        'available_quantity': 15,
        'stock_status': 'LOW_STOCK',
      },
    );

    expect(
      clinicalCatalogOptionUnitPrice(option, billingEntity: 'PHARMACY'),
      12,
    );
    expect(
      clinicalCatalogOptionUnitPrice(option, billingEntity: 'FACILITY'),
      9,
    );
    expect(clinicalCatalogOptionAvailableQuantity(option), 15);
    expect(clinicalCatalogOptionStockStatus(option), 'LOW_STOCK');
    expect(
      clinicalCatalogOptionStockStatusLabel('LOW_STOCK'),
      'Low Stock',
    );
  });
}
