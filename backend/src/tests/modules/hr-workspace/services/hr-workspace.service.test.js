const prisma = require('@prisma/client');
const subject = require('../../../../modules/hr-workspace/services/hr-workspace.service');

jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: jest.fn((...values) => values.find((value) => value) || null),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || undefined),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value || null),
}));

describe('hr-workspace.service contract', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    prisma.staff_position = {
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn().mockResolvedValue({ id: 'pos-1', name: 'Nurse' }),
    };
    prisma.facility = {
      findMany: jest.fn().mockResolvedValue([]),
      findFirst: jest.fn().mockResolvedValue({ tenant_id: 'tenant-1' }),
    };
    prisma.department = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.unit = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.room = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.staff_profile = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.nurse_roster = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.payroll_run = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.shift_template = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.role = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.user = { findMany: jest.fn().mockResolvedValue([]) };
  });

  it('exports service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject)).toEqual(
      expect.arrayContaining([
        'getWorkspace',
        'getWorkItems',
        'getReferenceData',
        'generateStaffNumber',
        'getStaffAccessSummary',
        'getRosterWorkflow',
        'generateRosterAssignments',
        'publishRoster',
        'overrideShiftAssignment',
        'approveSwap',
        'rejectSwap',
        'approveLeave',
        'rejectLeave',
        'previewPayrollRun',
        'processPayrollRun',
        'resolveLegacyRouteIdentifier',
      ])
    );
  });

  it('builds staff profile options from nested user profile names', async () => {
    prisma.staff_profile.findMany.mockResolvedValue([
      {
        id: 'staff-uuid',
        human_friendly_id: 'STF0001',
        staff_number: 'STAFF-01',
        position: 'Nurse',
        practitioner_type: 'MO',
        department_id: 'department-uuid',
        user: {
          email: 'nurse@example.com',
          profile: {
            first_name: 'Grace',
            last_name: 'Nakato',
          },
        },
      },
    ]);

    const result = await subject.getReferenceData({});

    expect(prisma.staff_profile.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        select: expect.objectContaining({
          user: {
            select: {
              email: true,
              profile: {
                select: {
                  first_name: true,
                  last_name: true,
                },
              },
            },
          },
        }),
      })
    );
    expect(result.staff_profiles).toEqual([
      expect.objectContaining({
        value: 'STF0001',
        label: 'STAFF-01 | Grace Nakato | Nurse',
        display_id: 'STF0001',
        department_id: 'department-uuid',
      }),
    ]);
  });

  it('seeds default staff positions when catalog is empty', async () => {
    prisma.staff_position.count.mockResolvedValue(0);
    prisma.staff_position.create.mockImplementation(({ data }) =>
      Promise.resolve({ id: `pos-${data.name}`, ...data })
    );

    await subject.getReferenceData({ facility_id: 'facility-1' });

    expect(prisma.staff_position.count).toHaveBeenCalled();
    expect(prisma.staff_position.create).toHaveBeenCalled();
    expect(prisma.staff_position.create.mock.calls.length).toBeGreaterThan(10);
  });

    it('returns practitioner type options with human-friendly labels', async () => {
    const result = await subject.getReferenceData({});

    expect(result.practitioner_types).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          value: 'MO',
          label_key: 'labels.hr.reference.practitioner_type.mo',
          label: expect.stringContaining('Medical Officer'),
        }),
        expect.objectContaining({
          value: 'SPECIALIST',
          label_key: 'labels.hr.reference.practitioner_type.specialist',
        }),
      ])
    );
    expect(result.compensation_pay_types).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          value: 'PER_MONTH',
          label_key: 'labels.hr.reference.compensation_pay_type.per_month',
        }),
      ])
    );
  });

  it('falls back to the staff position catalog when no positions exist', async () => {
    const result = await subject.getReferenceData({});

    expect(result.staff_positions.length).toBeGreaterThan(10);
    expect(result.staff_positions).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          value: 'Nurse',
          label_key: 'labels.hr.reference.staff_position.nurse',
        }),
        expect.objectContaining({
          value: 'Doctor',
          label_key: 'labels.hr.reference.staff_position.doctor',
        }),
      ])
    );
  });

  it('includes departments and roles without human-friendly ids', async () => {
    prisma.department.findMany.mockResolvedValue([
      {
        id: 'department-uuid',
        human_friendly_id: null,
        name: 'Emergency',
        short_name: 'ER',
        facility_id: 'facility-1',
      },
    ]);
    prisma.role.findMany.mockResolvedValue([
      {
        id: 'role-uuid',
        human_friendly_id: null,
        name: 'NURSE',
        permissions: [{ permission_id: 'perm-1' }],
      },
    ]);

    const result = await subject.getReferenceData({});

    expect(result.departments).toEqual([
      expect.objectContaining({
        value: 'department-uuid',
        label: 'Emergency',
      }),
    ]);
    expect(result.roles).toEqual([
      expect.objectContaining({
        value: 'role-uuid',
        label: expect.stringContaining('NURSE'),
        name: 'NURSE',
        permission_count: 1,
      }),
    ]);
  });
});
