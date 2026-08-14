const {
  DEPARTMENT_STATUSES,
  DEPARTMENT_ACTIONS,
  departmentsQuerySchema,
  departmentIdentifierParamsSchema,
  departmentActionParamsSchema,
  createDepartmentSchema,
  updateDepartmentSchema,
  departmentActionSchema,
} = require('@validations/accounts-workspace/department-cost-centre.schema');

const validCreate = {
  department_code: 'CARD',
  department_name: 'Cardiology',
  cost_centre_code: 'CC-100',
  cost_centre_name: 'Cardiology Cost Centre',
};

describe('department-cost-centre schemas', () => {
  it('exposes the documented status model and actions', () => {
    expect(DEPARTMENT_STATUSES).toEqual([
      'DRAFT',
      'ACTIVE',
      'INACTIVE',
      'ARCHIVED',
    ]);
    expect(DEPARTMENT_ACTIONS).toEqual([
      'activate',
      'deactivate',
      'archive',
      'restore',
    ]);
  });

  describe('departmentsQuerySchema', () => {
    it('parses a comma-separated status multi-select', () => {
      const parsed = departmentsQuerySchema.parse({ status: 'ACTIVE, draft' });
      expect(parsed.status).toEqual(['ACTIVE', 'DRAFT']);
    });

    it('drops unknown status values instead of querying them', () => {
      const parsed = departmentsQuerySchema.parse({ status: 'BOGUS' });
      expect(parsed.status).toBeUndefined();
    });

    it('parses the hierarchical cost centre multi-select', () => {
      const parsed = departmentsQuerySchema.parse({
        cost_centre_code: 'CC-100, CC-200 ,',
      });
      expect(parsed.cost_centre_code).toEqual(['CC-100', 'CC-200']);
    });

    it('rejects an unparseable date boundary', () => {
      expect(() => departmentsQuerySchema.parse({ from: 'not-a-date' })).toThrow();
    });
  });

  describe('createDepartmentSchema', () => {
    it('accepts a minimal valid payload', () => {
      expect(() => createDepartmentSchema.parse(validCreate)).not.toThrow();
    });

    it.each([
      'department_code',
      'department_name',
      'cost_centre_code',
      'cost_centre_name',
    ])('requires %s', (field) => {
      const payload = { ...validCreate };
      delete payload[field];
      expect(() => createDepartmentSchema.parse(payload)).toThrow();
    });

    it('rejects an effective window that ends before it starts', () => {
      expect(() =>
        createDepartmentSchema.parse({
          ...validCreate,
          effective_from: '2026-06-01T00:00:00.000Z',
          effective_to: '2026-01-01T00:00:00.000Z',
        })
      ).toThrow(/effective_to_before_from/);
    });

    it('accepts an open-ended effective window', () => {
      expect(() =>
        createDepartmentSchema.parse({
          ...validCreate,
          effective_from: '2026-01-01T00:00:00.000Z',
          effective_to: null,
        })
      ).not.toThrow();
    });

    it('enforces the documented length limits', () => {
      expect(() =>
        createDepartmentSchema.parse({
          ...validCreate,
          department_code: 'X'.repeat(33),
        })
      ).toThrow();
      expect(() =>
        createDepartmentSchema.parse({
          ...validCreate,
          cost_centre_name: 'X'.repeat(161),
        })
      ).toThrow();
    });

    it('does not accept a client-supplied status', () => {
      const parsed = createDepartmentSchema.parse({
        ...validCreate,
        status: 'ACTIVE',
      });
      expect(parsed.status).toBeUndefined();
    });
  });

  describe('updateDepartmentSchema', () => {
    it('allows a partial patch carrying the optimistic version', () => {
      const parsed = updateDepartmentSchema.parse({
        department_name: 'Renamed',
        version: 3,
      });
      expect(parsed).toMatchObject({ department_name: 'Renamed', version: 3 });
    });

    it('still enforces effective-window ordering on a patch', () => {
      expect(() =>
        updateDepartmentSchema.parse({
          effective_from: '2026-06-01T00:00:00.000Z',
          effective_to: '2026-01-01T00:00:00.000Z',
        })
      ).toThrow(/effective_to_before_from/);
    });

    it('rejects a version below one', () => {
      expect(() => updateDepartmentSchema.parse({ version: 0 })).toThrow();
    });
  });

  describe('params and action schemas', () => {
    it('accepts a human-friendly identifier', () => {
      expect(() =>
        departmentIdentifierParamsSchema.parse({
          departmentIdentifier: 'DEP0000001',
        })
      ).not.toThrow();
    });

    it('rejects an action outside the documented set', () => {
      expect(() =>
        departmentActionParamsSchema.parse({
          departmentIdentifier: 'DEP0000001',
          action: 'delete',
        })
      ).toThrow();
    });

    it.each(DEPARTMENT_ACTIONS)('accepts the %s action', (action) => {
      expect(() =>
        departmentActionParamsSchema.parse({
          departmentIdentifier: 'DEP0000001',
          action,
        })
      ).not.toThrow();
    });

    it('caps the audit reason length', () => {
      expect(() =>
        departmentActionSchema.parse({ reason: 'X'.repeat(501) })
      ).toThrow();
    });
  });
});
