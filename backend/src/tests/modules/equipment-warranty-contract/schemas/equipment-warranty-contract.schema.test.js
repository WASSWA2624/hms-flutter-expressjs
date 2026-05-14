const { createEquipmentWarrantyContractSchema } = require('@validations/equipment-warranty-contract/equipment-warranty-contract.schema');
describe('EquipmentWarrantyContract schema', () => {
  it('validates create payload with tenant_id', () => {
    const result = createEquipmentWarrantyContractSchema.safeParse({ tenant_id: '550e8400-e29b-41d4-a716-446655440000', any_field: 'ok' });
    expect(result.success).toBe(true);
  });
});
