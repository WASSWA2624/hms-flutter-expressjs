const departmentService = require('@services/accounts-workspace/department-cost-centre.service');
const repo = require('@repositories/accounts-workspace/department-cost-centre.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/accounts-workspace/department-cost-centre.repository');
jest.mock('@lib/audit');
jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: () => true,
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelRecordByIdentifier: jest.fn(async ({ identifier }) => ({
    id: `resolved-${identifier}`,
  })),
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) => values.find((value) => value) || null,
}));

const USER = { id: 'user-1', tenant_id: 'tenant-1', facility_id: 'facility-1' };

const buildRecord = (overrides = {}) => ({
  id: 'dept-1',
  human_friendly_id: 'DEP0000001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  code: 'CARD',
  name: 'Cardiology',
  cost_centre_code: 'CC-100',
  cost_centre_name: 'Cardiology Cost Centre',
  department_type: 'CLINICAL',
  parent_id: null,
  parent: null,
  manager_id: null,
  manager: null,
  budget_owner_id: null,
  budget_owner: null,
  default_revenue_account_id: null,
  default_revenue_account: null,
  default_expense_account_id: null,
  default_expense_account: null,
  effective_from: new Date('2026-01-01T00:00:00.000Z'),
  effective_to: null,
  status: 'DRAFT',
  is_active: false,
  version: 1,
  created_at: new Date('2026-01-01T00:00:00.000Z'),
  updated_at: new Date('2026-01-01T00:00:00.000Z'),
  archived_at: null,
  facility: {
    id: 'facility-1',
    human_friendly_id: 'FAC0001',
    name: 'Main Hospital',
  },
  ...overrides,
});

const noBlockingReferences = () =>
  repo.countBlockingReferences.mockResolvedValue({
    children: 0,
    units: 0,
    wards: 0,
    total: 0,
  });

describe('department-cost-centre service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
    repo.groupByStatus.mockResolvedValue([]);
    noBlockingReferences();
  });

  describe('listDepartments', () => {
    it('scopes rows to the caller tenant and facility and returns public rows', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);

      const result = await departmentService.listDepartments({}, 1, 20, USER);

      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
        }),
        0,
        20,
        expect.any(Array)
      );
      expect(result.items).toHaveLength(1);
      expect(result.pagination.total).toBe(1);
      expect(result.meta.section).toBe('departments-and-cost-centres');
    });

    it('never leaks a raw database id in a public row', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);

      const result = await departmentService.listDepartments({}, 1, 20, USER);
      const row = result.items[0];

      expect(row.human_friendly_id).toBe('DEP0000001');
      expect(JSON.stringify(row)).not.toContain('dept-1');
      expect(JSON.stringify(row)).not.toContain('facility-1');
      expect(row).not.toHaveProperty('id');
      expect(row).not.toHaveProperty('tenant_id');
    });

    it('rejects a caller with no tenant instead of widening scope', async () => {
      await expect(
        departmentService.listDepartments({ tenant_id: '' }, 1, 20, {})
      ).rejects.toMatchObject({ statusCode: 403 });
    });

    it('ignores a crafted tenant_id filter and uses the session tenant', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await departmentService.listDepartments(
        { tenant_id: 'other-tenant' },
        1,
        20,
        USER
      );

      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ tenant_id: 'tenant-1' }),
        0,
        20,
        expect.any(Array)
      );
    });

    it('filters by status, cost centre, and search together', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await departmentService.listDepartments(
        { status: 'ACTIVE,DRAFT', cost_centre_code: 'CC-100,CC-200', search: 'card' },
        1,
        20,
        USER
      );

      const where = repo.findMany.mock.calls[0][0];
      expect(where.status).toEqual({ in: ['ACTIVE', 'DRAFT'] });
      expect(where.cost_centre_code).toEqual({ in: ['CC-100', 'CC-200'] });
      expect(where.OR).toEqual(
        expect.arrayContaining([{ name: { contains: 'card' } }])
      );
    });

    it('treats an open effective window as overlapping the requested range', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await departmentService.listDepartments(
        { from: '2026-01-01', to: '2026-12-31' },
        1,
        20,
        USER
      );

      const where = repo.findMany.mock.calls[0][0];
      expect(where.effective_from).toEqual({ lte: expect.any(Date) });
      expect(where.OR).toEqual([
        { effective_to: null },
        { effective_to: { gte: expect.any(Date) } },
      ]);
    });

    it('matches the owner filter against manager or budget owner', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await departmentService.listDepartments({ owner_id: 'USR001' }, 1, 20, USER);

      const where = repo.findMany.mock.calls[0][0];
      expect(where.OR).toEqual([
        { manager_id: 'resolved-USR001' },
        { budget_owner_id: 'resolved-USR001' },
      ]);
    });

    it('maps documented sort keys and falls back to the spec default', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await departmentService.listDepartments(
        {},
        1,
        20,
        USER,
        'department_name',
        'asc'
      );
      expect(repo.findMany.mock.calls[0][3]).toEqual([
        { name: 'asc' },
        { code: 'asc' },
      ]);

      await departmentService.listDepartments({}, 1, 20, USER, 'nonsense', 'asc');
      expect(repo.findMany.mock.calls[1][3]).toEqual([
        { effective_from: 'desc' },
        { code: 'desc' },
      ]);
    });
  });

  describe('createDepartment', () => {
    it('forces DRAFT status, mirrors is_active, and writes an audit event', async () => {
      repo.findFirst
        .mockResolvedValueOnce(null) // duplicate probe
        .mockResolvedValueOnce(buildRecord());
      repo.create.mockResolvedValue({ id: 'dept-1' });

      const row = await departmentService.createDepartment(
        {
          department_code: 'CARD',
          department_name: 'Cardiology',
          cost_centre_code: 'CC-100',
          cost_centre_name: 'Cardiology Cost Centre',
          status: 'ACTIVE',
        },
        USER,
        '10.0.0.1'
      );

      const payload = repo.create.mock.calls[0][0];
      expect(payload.status).toBe('DRAFT');
      expect(payload.is_active).toBe(false);
      expect(payload.tenant_id).toBe('tenant-1');
      expect(row.status).toBe('DRAFT');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'CREATE', entity: 'department' })
      );
    });

    it('rejects a duplicate department or cost centre code', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord());

      await expect(
        departmentService.createDepartment(
          {
            department_code: 'CARD',
            department_name: 'Cardiology',
            cost_centre_code: 'CC-100',
            cost_centre_name: 'Cardiology Cost Centre',
          },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.create).not.toHaveBeenCalled();
    });

    it('refuses a reference that does not resolve inside the tenant', async () => {
      const {
        resolveModelRecordByIdentifier,
      } = require('@lib/identifiers/resolve-entity-id');
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(
        departmentService.createDepartment(
          {
            department_code: 'CARD',
            department_name: 'Cardiology',
            cost_centre_code: 'CC-100',
            cost_centre_name: 'Cardiology Cost Centre',
            parent_id: 'FOREIGN',
          },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
      expect(repo.create).not.toHaveBeenCalled();
    });
  });

  describe('updateDepartment', () => {
    it('rejects a stale optimistic version', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ version: 4 }));

      await expect(
        departmentService.updateDepartment(
          'DEP0000001',
          { department_name: 'Renamed', version: 2 },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('rejects an archived record as not editable', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'ARCHIVED' }));

      await expect(
        departmentService.updateDepartment(
          'DEP0000001',
          { department_name: 'Renamed' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
    });

    it('rejects an effective window that ends before it starts', async () => {
      repo.findFirst.mockResolvedValue(buildRecord());

      await expect(
        departmentService.updateDepartment(
          'DEP0000001',
          {
            effective_from: '2026-06-01T00:00:00.000Z',
            effective_to: '2026-01-01T00:00:00.000Z',
          },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
    });

    it('rejects a department that would become its own parent', async () => {
      repo.findFirst.mockResolvedValue(buildRecord());
      const {
        resolveModelRecordByIdentifier,
      } = require('@lib/identifiers/resolve-entity-id');
      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: 'dept-1' });

      await expect(
        departmentService.updateDepartment(
          'DEP0000001',
          { parent_id: 'DEP0000001' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
    });

    it('reports a conflict when the guarded update matches no row', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord())
        .mockResolvedValueOnce(null); // duplicate probe
      repo.updateWithVersion.mockResolvedValue(null);

      await expect(
        departmentService.updateDepartment(
          'DEP0000001',
          { department_name: 'Renamed' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
    });

    it('writes a before/after audit diff on success', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord())
        .mockResolvedValueOnce(null);
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ name: 'Renamed', version: 2 })
      );

      await departmentService.updateDepartment(
        'DEP0000001',
        { department_name: 'Renamed' },
        USER,
        '10.0.0.1'
      );

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'UPDATE',
          entity: 'department',
          diff: expect.objectContaining({
            before: expect.any(Object),
            after: expect.any(Object),
          }),
        })
      );
    });
  });

  describe('applyDepartmentAction', () => {
    it('activates a draft and mirrors is_active', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'DRAFT' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ACTIVE', is_active: true, version: 2 })
      );

      const row = await departmentService.applyDepartmentAction(
        'DEP0000001',
        'activate',
        { reason: 'Go live' },
        USER,
        '10.0.0.1'
      );

      const patch = repo.updateWithVersion.mock.calls[0][2];
      expect(patch.status).toBe('ACTIVE');
      expect(patch.is_active).toBe(true);
      expect(row.status).toBe('ACTIVE');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'ACTIVATE',
          diff: expect.objectContaining({ reason: 'Go live' }),
        })
      );
    });

    it('refuses a transition the status model does not allow', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'DRAFT' }));

      await expect(
        departmentService.applyDepartmentAction(
          'DEP0000001',
          'deactivate',
          {},
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('refuses to archive while live children, units, or wards reference it', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'ACTIVE' }));
      repo.countBlockingReferences.mockResolvedValue({
        children: 1,
        units: 2,
        wards: 0,
        total: 3,
      });

      await expect(
        departmentService.applyDepartmentAction(
          'DEP0000001',
          'archive',
          {},
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('archives as a soft state change, never a delete', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'ACTIVE' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ARCHIVED', archived_at: new Date(), version: 2 })
      );

      await departmentService.applyDepartmentAction(
        'DEP0000001',
        'archive',
        {},
        USER
      );

      const patch = repo.updateWithVersion.mock.calls[0][2];
      expect(patch.status).toBe('ARCHIVED');
      expect(patch.is_active).toBe(false);
      expect(patch.archived_at).toBeInstanceOf(Date);
    });

    it('restores an archived record back to active', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'ARCHIVED' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ACTIVE', is_active: true, version: 3 })
      );

      const row = await departmentService.applyDepartmentAction(
        'DEP0000001',
        'restore',
        {},
        USER
      );

      expect(row.status).toBe('ACTIVE');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'RESTORE' })
      );
    });

    it('rejects an unknown action', async () => {
      await expect(
        departmentService.applyDepartmentAction('DEP0000001', 'explode', {}, USER)
      ).rejects.toMatchObject({ statusCode: 400 });
    });

    it('rejects a stale version before touching the row', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'DRAFT', version: 5 }));

      await expect(
        departmentService.applyDepartmentAction(
          'DEP0000001',
          'activate',
          { version: 2 },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });
  });

  describe('countActiveDepartments', () => {
    it('counts only ACTIVE rows inside the caller scope', async () => {
      repo.count.mockResolvedValue(7);

      const total = await departmentService.countActiveDepartments({}, USER);

      expect(total).toBe(7);
      expect(repo.count).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'ACTIVE',
        })
      );
    });

    it('degrades to zero rather than breaking the workspace summary', async () => {
      repo.count.mockRejectedValue(new Error('db down'));

      await expect(
        departmentService.countActiveDepartments({}, USER)
      ).resolves.toBe(0);
    });
  });
});
