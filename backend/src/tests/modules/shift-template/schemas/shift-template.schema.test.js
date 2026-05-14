const {
  createShiftTemplateSchema,
  shiftTemplateIdParamsSchema,
} = require('@validations/shift-template/shift-template.schema');

describe('Shift Template Schemas', () => {
  const validData = {
    tenant_id: '550e8400-e29b-41d4-a716-446655440000',
    name: '6hr Morning',
    shift_type: 'DAY',
    default_start_time: '08:00',
    default_end_time: '14:00',
  };

  it('validates correct data', () => {
    expect(createShiftTemplateSchema.safeParse(validData).success).toBe(true);
  });

  it('requires tenant_id', () => {
    const { tenant_id, ...rest } = validData;
    expect(createShiftTemplateSchema.safeParse(rest).success).toBe(false);
  });

  it('validates time format', () => {
    expect(createShiftTemplateSchema.safeParse({ ...validData, default_start_time: '8:00' }).success).toBe(true);
    expect(createShiftTemplateSchema.safeParse({ ...validData, default_start_time: 'invalid' }).success).toBe(false);
  });

  it('validates id param', () => {
    expect(shiftTemplateIdParamsSchema.safeParse({ id: '550e8400-e29b-41d4-a716-446655440000' }).success).toBe(true);
  });
});
