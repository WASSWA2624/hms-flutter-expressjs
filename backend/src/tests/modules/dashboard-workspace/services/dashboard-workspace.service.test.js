jest.mock('@repositories/dashboard-workspace/dashboard-workspace.repository');
jest.mock('@repositories/dashboard-widget/dashboard-widget.repository', () => ({}));
jest.mock('@lib/dashboard/summary', () => ({
  ROLE_PACKS: {
    ADMIN: 'admin',
    DOCTOR: 'doctor',
    NURSE: 'nurse',
    LAB_TECH: 'lab_tech',
    PHARMACIST: 'pharmacist',
    RECEPTIONIST: 'receptionist',
    BILLING: 'billing',
    OPERATIONS: 'operations',
    HR: 'hr',
    BIOMED: 'biomed',
    HOUSE_KEEPER: 'house_keeper',
    AMBULANCE_OPERATOR: 'ambulance_operator',
  },
  resolveEffectiveRole: jest.fn(() => 'SUPER_ADMIN'),
  buildDashboardSummary: jest.fn(async () => ({
    roleProfile: { id: 'super_admin', role: 'SUPER_ADMIN', pack: 'admin' },
    summaryCards: [{ id: 'patients_today', label: 'Patients today', value: 12, format: 'number' }],
  })),
}));

const repository = require('@repositories/dashboard-workspace/dashboard-workspace.repository');
const { buildDashboardSummary } = require('@lib/dashboard/summary');
const subject = require('../../../../modules/dashboard-workspace/services/dashboard-workspace.service');

describe('dashboard-workspace service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    repository.safePublicId.mockImplementation((value, fallback) => value || fallback || null);
  });

  it('returns tenant-context-required payloads for global admins without scope', async () => {
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'tenant_context_required',
      scope: null,
    });
    repository.findLookups.mockResolvedValue({
      tenants: [{ id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' }],
    });

    const result = await subject.getWorkspace({}, 1, 20, undefined, 'desc', {
      role: 'SUPER_ADMIN',
    });

    expect(result.state).toBe('tenant_context_required');
    expect(result.tenant_options).toEqual([
      { id: 'TEN0001', label: 'Acme' },
    ]);
  });

  it('returns ready workspace payloads without exposing raw summary structure directly', async () => {
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'ready',
      scope: {
        tenant_id: 'TEN0001',
        facility_id: 'FAC0001',
        branch_id: 'BR0001',
      },
    });
    repository.findFacilityContext.mockResolvedValue({
      id: 'facility-uuid',
      human_friendly_id: 'FAC0001',
      name: 'Central Hospital',
      facility_type: 'HOSPITAL',
    });
    repository.findCurrentSubscription.mockResolvedValue({
      id: 'sub-uuid',
      human_friendly_id: 'SUB0001',
      plan: { name: 'Pro' },
      module_subscriptions: [],
    });
    repository.findLookups.mockResolvedValue({
      tenants: [{ id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' }],
      facilities: [{ id: 'facility-uuid', human_friendly_id: 'FAC0001', name: 'Central Hospital', facility_type: 'HOSPITAL' }],
      branches: [{ id: 'branch-uuid', human_friendly_id: 'BR0001', name: 'Main Branch', facility_id: 'FAC0001' }],
    });
    repository.countRows.mockResolvedValue(0);
    repository.sumRows.mockResolvedValue(0);
    repository.findRows.mockResolvedValue([]);

    const result = await subject.getWorkspace(
      { panel: 'overview' },
      1,
      20,
      'updated_at',
      'desc',
      { role: 'SUPER_ADMIN' }
    );

    expect(buildDashboardSummary).toHaveBeenCalled();
    expect(result.state).toBe('ready');
    expect(result.context).toEqual(
      expect.objectContaining({
        tenant_id: 'TEN0001',
        facility_id: 'FAC0001',
        branch_id: 'BR0001',
      })
    );
    expect(Array.isArray(result.status_strip)).toBe(true);
    expect(Array.isArray(result.quick_action_ids)).toBe(true);
    expect(result.queue).toEqual(
      expect.objectContaining({
        items: expect.any(Array),
        pagination: expect.any(Object),
      })
    );
  });

  it('returns normalized lookups collections', async () => {
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'ready',
      scope: {
        tenant_id: 'TEN0001',
        facility_id: 'FAC0001',
      },
    });
    repository.findLookups.mockResolvedValue({
      tenants: [{ id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' }],
      facilities: [{ id: 'facility-uuid', human_friendly_id: 'FAC0001', name: 'Central Hospital', facility_type: 'HOSPITAL' }],
      branches: [{ id: 'branch-uuid', human_friendly_id: 'BR0001', name: 'Main Branch', facility_id: 'FAC0001' }],
    });

    const result = await subject.getLookups({}, { role: 'SUPER_ADMIN' });

    expect(result).toEqual(
      expect.objectContaining({
        state: 'ready',
        tenants: [{ id: 'TEN0001', label: 'Acme' }],
        facilities: [
          {
            id: 'FAC0001',
            label: 'Central Hospital',
            meta: { facility_type: 'HOSPITAL' },
          },
        ],
        branches: [
          {
            id: 'BR0001',
            label: 'Main Branch',
            meta: { facility_id: 'FAC0001' },
          },
        ],
      })
    );
    expect(result.queue_statuses).toEqual(
      expect.arrayContaining([
        { id: 'SCHEDULED', label_key: 'dashboard.statusValues.scheduled' },
        { id: 'OVERDUE', label_key: 'dashboard.statusValues.overdue' },
      ])
    );
    expect(result.activity_statuses).toEqual(
      expect.arrayContaining([
        { id: 'OPEN', label_key: 'dashboard.statusValues.open' },
      ])
    );
  });

  it('returns structured empty-state metadata instead of placeholder guide rows', async () => {
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'ready',
      scope: {
        tenant_id: 'TEN0001',
        facility_id: 'FAC0001',
      },
    });
    repository.findFacilityContext.mockResolvedValue({
      id: 'facility-uuid',
      human_friendly_id: 'FAC0001',
      name: 'Central Hospital',
      facility_type: 'HOSPITAL',
    });
    repository.findCurrentSubscription.mockResolvedValue(null);
    repository.countRows.mockResolvedValue(0);
    repository.sumRows.mockResolvedValue(0);
    repository.findRows.mockResolvedValue([]);

    const result = await subject.getWorkspace(
      { panel: 'queue' },
      1,
      20,
      'occurred_at',
      'desc',
      { role: 'SUPER_ADMIN' }
    );

    expect(result.queue.items).toEqual([]);
    expect(result.queue.empty_state).toEqual(
      expect.objectContaining({
        reason: 'guided_setup',
        target: expect.objectContaining({
          module_slug: 'dashboard',
          resource: 'getting-started',
          action: 'open',
        }),
      })
    );
    expect(result.activity.items).toEqual([]);
    expect(result.activity.empty_state).toEqual(
      expect.objectContaining({
        reason: 'guided_setup',
      })
    );
  });

  it('builds maintenance queue items from status when the model has no priority field', async () => {
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'ready',
      scope: {
        tenant_id: 'TEN0001',
        facility_id: 'FAC0001',
      },
    });
    repository.findFacilityContext.mockResolvedValue({
      id: 'facility-uuid',
      human_friendly_id: 'FAC0001',
      name: 'Central Hospital',
      facility_type: 'HOSPITAL',
    });
    repository.findCurrentSubscription.mockResolvedValue(null);
    repository.findLookups.mockResolvedValue({
      tenants: [],
      facilities: [],
      branches: [],
    });
    repository.countRows.mockResolvedValue(0);
    repository.sumRows.mockResolvedValue(0);
    repository.findRows.mockImplementation(async ({ model }) => {
      if (model === 'maintenance_request') {
        return [
          {
            id: 'maintenance-uuid',
            human_friendly_id: 'MNT0001',
            status: 'OPEN',
            reported_at: '2026-03-01T10:00:00.000Z',
            updated_at: '2026-03-01T10:15:00.000Z',
            created_at: '2026-03-01T09:55:00.000Z',
          },
        ];
      }
      return [];
    });

    const result = await subject.getWorkspace(
      { panel: 'queue', queue: 'maintenance_requests' },
      1,
      20,
      'updated_at',
      'desc',
      { role: 'SUPER_ADMIN' }
    );

    expect(repository.findRows).toHaveBeenCalledWith(
      expect.objectContaining({
        model: 'maintenance_request',
        select: expect.not.objectContaining({ priority: true }),
      })
    );
    expect(result.queue.items).toEqual([
      expect.objectContaining({
        id: 'maintenance_requests:MNT0001',
        queue: 'maintenance_requests',
        priority: null,
        severity: 'high',
        status: 'OPEN',
      }),
    ]);
  });

  it('preserves queue predicates when applying human-friendly search filters', async () => {
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'ready',
      scope: {
        tenant_id: 'TEN0001',
        facility_id: 'FAC0001',
      },
    });
    repository.findFacilityContext.mockResolvedValue({
      id: 'facility-uuid',
      human_friendly_id: 'FAC0001',
      name: 'Central Hospital',
      facility_type: 'HOSPITAL',
    });
    repository.findCurrentSubscription.mockResolvedValue(null);
    repository.findLookups.mockResolvedValue({
      tenants: [],
      facilities: [],
      branches: [],
    });
    repository.countRows.mockResolvedValue(0);
    repository.sumRows.mockResolvedValue(0);
    repository.findRows.mockResolvedValue([]);

    await subject.getWorkspace(
      { panel: 'queue', queue: 'billing_follow_up', search: 'inv0001' },
      1,
      20,
      'occurred_at',
      'desc',
      { role: 'SUPER_ADMIN' }
    );

    expect(repository.findRows).toHaveBeenCalledWith(
      expect.objectContaining({
        model: 'invoice',
        where: expect.objectContaining({
          AND: [
            expect.objectContaining({
              deleted_at: null,
              tenant_id: 'TEN0001',
              facility_id: 'FAC0001',
              OR: [
                { status: { in: ['SENT', 'OVERDUE'] } },
                { billing_status: { in: ['DRAFT', 'ISSUED', 'PARTIAL'] } },
              ],
            }),
            {
              OR: [
                { human_friendly_id: { contains: 'inv0001' } },
                { human_friendly_id: { contains: 'INV0001' } },
              ],
            },
          ],
        }),
      })
    );
  });
});
