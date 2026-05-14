const prisma = require('@prisma/client');
const subject = require('../../../../modules/hr-workspace/services/hr-workspace.service');

describe('hr-workspace.service contract', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    prisma.facility = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.department = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.staff_profile = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.staff_position = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.nurse_roster = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.payroll_run = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.shift_template = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.role = { findMany: jest.fn().mockResolvedValue([]) };
  });

  it('exports service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject)).toEqual(
      expect.arrayContaining([
        'getWorkspace',
        'getWorkItems',
        'getReferenceData',
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
});
