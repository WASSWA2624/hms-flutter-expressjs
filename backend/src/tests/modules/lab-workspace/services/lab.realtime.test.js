jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn(),
  },
}));

const prisma = require('@prisma/client');
const {
  resolveLabRealtimeRecipients,
  resolveFacilityLabCatalogRecipients,
} = require('@services/lab-workspace/lab.realtime');

describe('lab.realtime', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('includes ordering physician and encounter provider before role recipients', async () => {
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: 'role-user-1' },
      { user_id: 'role-user-2' },
    ]);

    const recipients = await resolveLabRealtimeRecipients({
      orderRecord: {
        ordered_by_user_id: 'ordering-doctor-1',
        patient: { tenant_id: 'tenant-1', facility_id: 'facility-1' },
        encounter: { provider_user_id: 'provider-doctor-1' },
      },
      actorUserId: 'lab-tech-1',
    });

    expect(recipients).toEqual([
      'ordering-doctor-1',
      'provider-doctor-1',
      'role-user-1',
      'role-user-2',
    ]);
    expect(recipients).not.toContain('lab-tech-1');
  });

  it('returns an empty list when tenant context is missing', async () => {
    const recipients = await resolveLabRealtimeRecipients({
      orderRecord: {
        patient: {},
      },
    });

    expect(recipients).toEqual([]);
    expect(prisma.user_role.findMany).not.toHaveBeenCalled();
  });

  describe('resolveFacilityLabCatalogRecipients', () => {
    it('resolves lab-capable users in the facility and excludes the actor', async () => {
      prisma.user_role.findMany.mockResolvedValue([
        { user_id: 'lab-tech-1' },
        { user_id: 'doctor-1' },
        { user_id: 'actor-1' },
        { user_id: 'lab-tech-1' },
      ]);

      const recipients = await resolveFacilityLabCatalogRecipients({
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        actorUserId: 'actor-1',
      });

      expect(recipients).toEqual(['lab-tech-1', 'doctor-1']);
      expect(prisma.user_role.findMany).toHaveBeenCalledTimes(1);
    });

    it('returns an empty list when tenant id is missing', async () => {
      const recipients = await resolveFacilityLabCatalogRecipients({
        facilityId: 'facility-1',
      });

      expect(recipients).toEqual([]);
      expect(prisma.user_role.findMany).not.toHaveBeenCalled();
    });
  });
});
