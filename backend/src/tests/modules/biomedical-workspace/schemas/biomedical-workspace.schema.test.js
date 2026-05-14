const {
  faultReportSchema,
} = require('../../../../modules/biomedical-workspace/schemas/biomedical-workspace.schema');

describe('biomedical-workspace.schema', () => {
  it('accepts a fault report with a temporary equipment name when no equipment id is provided', () => {
    const result = faultReportSchema.safeParse({
      reported_equipment_name: 'Portable suction trolley',
      facility_id: 'FAC-001',
      source_scope: 'dashboard_workspace',
      source_route: '/dashboard',
      severity: 'HIGH',
      priority: 'HIGH',
      symptoms: '',
      description: '',
    });

    expect(result.success).toBe(true);
  });

  it('rejects a fault report when neither equipment id nor a temporary equipment name is provided', () => {
    const result = faultReportSchema.safeParse({
      source_scope: 'dashboard_workspace',
      source_route: '/dashboard',
      severity: 'HIGH',
    });

    expect(result.success).toBe(false);
    expect(result.error.issues).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          path: ['equipment_id'],
        }),
      ])
    );
  });
});
