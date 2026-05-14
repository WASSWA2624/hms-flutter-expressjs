const { createEquipmentSafetyTestLogSchema } = require('@validations/equipment-safety-test-log/equipment-safety-test-log.schema');
describe('EquipmentSafetyTestLog schema', () => {
  it('validates create payload with tenant_id', () => {
    const result = createEquipmentSafetyTestLogSchema.safeParse({ tenant_id: '550e8400-e29b-41d4-a716-446655440000', any_field: 'ok' });
    expect(result.success).toBe(true);
  });
});
