const {
  createShiftTemplateSchema,
  shiftTemplateIdParamsSchema} = require('@validations/shift-template/shift-template.schema');

describe('Shift Template Schemas', () => {
  const validData = {
    tenant_id: '550e8400-e29b-41d4-a716-446655440000',
    name: '6hr Morning',
    shift_type: 'DAY',
    default_start_time: '08:00',
    default_end_time: '14:00'};

  it('validates correct data', () => {
    expect(createShiftTemplateSchema.safeParse(validData).success).toBe(true);
  });

  it('requires tenant_id', () => {
    const { tenant_id, ...rest } = validData;
    expect(createShiftTemplateSchema.safeParse(rest).success).toBe(false);
  });

  it('accepts weekly_schedule_json', () => {
    expect(
      createShiftTemplateSchema.safeParse({
        ...validData,
        weekly_schedule_json: [
          {
            day_of_week: 1,
            time_slots: [{ start_time: '08:00', end_time: '17:00' }]}]}).success
    ).toBe(true);
  });

  it('requires schedule or default times', () => {
    const { default_start_time, default_end_time, ...rest } = validData;
    expect(createShiftTemplateSchema.safeParse(rest).success).toBe(false);
  });

  it('validates id param', () => {
    expect(shiftTemplateIdParamsSchema.safeParse({ id: '550e8400-e29b-41d4-a716-446655440000' }).success).toBe(true);
  });
});
