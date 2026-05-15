jest.mock('@prisma/client', () => ({
  appointment: { findMany: jest.fn(), count: jest.fn() },
  visit_queue: { findMany: jest.fn(), count: jest.fn() },
  appointment_reminder: { findMany: jest.fn(), count: jest.fn() },
  follow_up: { findMany: jest.fn(), count: jest.fn() },
  provider_schedule: { findMany: jest.fn(), count: jest.fn() },
  encounter: { findMany: jest.fn(), count: jest.fn() },
  facility: { findMany: jest.fn() },
  user: { findMany: jest.fn() },
}));

const prisma = require('@prisma/client');
const subject = require('@repositories/scheduling-workspace/scheduling-workspace.repository');

describe('scheduling-workspace.repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('buildAppointmentWhere includes scope and date range', () => {
    const result = subject.buildAppointmentWhere({
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      dayStart: new Date('2026-03-03T00:00:00.000Z'),
      dayEnd: new Date('2026-03-04T00:00:00.000Z'),
      search: 'Jane',
    });

    expect(result.tenant_id).toBe('tenant-1');
    expect(result.facility_id).toBe('facility-1');
    expect(result.scheduled_start).toEqual(
      expect.objectContaining({
        gte: expect.any(Date),
        lte: expect.any(Date),
      })
    );
    expect(result.AND).toHaveLength(1);
  });

  it('findQueueEntries queries queue rows with includes', async () => {
    prisma.visit_queue.findMany.mockResolvedValue([]);

    await subject.findQueueEntries({ where: { tenant_id: 'tenant-1' }, take: 5 });

    expect(prisma.visit_queue.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { tenant_id: 'tenant-1' },
        take: 5,
        include: expect.objectContaining({
          patient: expect.any(Object),
          appointment: expect.any(Object),
        }),
      })
    );
  });

  it('buildQueueWhere excludes deleted patients from queue results', () => {
    const result = subject.buildQueueWhere({
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      search: 'Jane',
    });

    expect(result).toEqual(
      expect.objectContaining({
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        deleted_at: null,
        patient: { deleted_at: null },
        status: { in: ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS'] },
      })
    );
    expect(result.AND).toHaveLength(1);
  });

  it('findSchedules includes provider and slot data', async () => {
    prisma.provider_schedule.findMany.mockResolvedValue([]);

    await subject.findSchedules({
      where: { tenant_id: 'tenant-1', day_of_week: 2 },
      take: 6,
      dayStart: new Date('2026-03-03T00:00:00.000Z'),
      dayEnd: new Date('2026-03-04T00:00:00.000Z'),
    });

    expect(prisma.provider_schedule.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        include: expect.objectContaining({
          provider: expect.any(Object),
          slots: expect.any(Object),
        }),
      })
    );
  });
});
