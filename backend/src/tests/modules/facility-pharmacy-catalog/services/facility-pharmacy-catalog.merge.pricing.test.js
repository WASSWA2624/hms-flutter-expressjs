const {
  mergeDrugWithOffering,
  mapMergedDrugRecord,
} = require('@modules/pharmacy-workspace/services/facility-pharmacy-catalog.merge');

describe('facility-pharmacy-catalog.merge pricing lanes', () => {
  it('preserves buy and transfer distinct from facility patient tariff', () => {
    const merged = mergeDrugWithOffering(
      {
        id: 'drug-1',
        name: 'Paracetamol',
        buy_unit_price: 30,
        unit_price: 100,
        transfer_unit_price: 70,
        currency: 'UGX',
      },
      {
        id: 'offering-1',
        is_active: true,
        unit_price: 120,
        currency: 'UGX',
      }
    );

    expect(merged.buy_unit_price).toBe(30);
    expect(merged.pharmacy_unit_price).toBe(100);
    expect(merged.transfer_unit_price).toBe(70);
    expect(merged.facility_unit_price).toBe(120);

    const mapped = mapMergedDrugRecord(
      {
        id: 'drug-1',
        human_friendly_id: 'DRG-1',
        name: 'Paracetamol',
        buy_unit_price: 30,
        unit_price: 100,
        transfer_unit_price: 70,
        currency: 'UGX',
      },
      {
        id: 'offering-1',
        is_active: true,
        unit_price: 120,
        currency: 'UGX',
      }
    );

    expect(mapped.buy_unit_price).toBe('30.00');
    expect(mapped.pharmacy_unit_price).toBe('100.00');
    expect(mapped.transfer_unit_price).toBe('70.00');
    expect(mapped.facility_unit_price).toBe('120.00');
  });
});
