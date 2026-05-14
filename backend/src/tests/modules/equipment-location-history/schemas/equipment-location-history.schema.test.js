const { createEquipmentLocationHistorySchema } = require('@validations/equipment-location-history/equipment-location-history.schema');
describe('EquipmentLocationHistory schema', () => {
  it('validates create payload with tenant_id', () => {
    const result = createEquipmentLocationHistorySchema.safeParse({ tenant_id: '550e8400-e29b-41d4-a716-446655440000', any_field: 'ok' });
    expect(result.success).toBe(true);
  });
});
