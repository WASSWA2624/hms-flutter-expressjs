/**
 * Platform realtime publishing tests
 */

jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn()
  }
}));

jest.mock('@lib/websocket/emit', () => ({
  publishDomainEvent: jest.fn().mockReturnValue(1)
}));

const prisma = require('@prisma/client');
const { publishDomainEvent } = require('@lib/websocket/emit');
const {
  findPlatformAdminRecipientUserIds,
  publishPlatformRealtimeEvent,
  buildTenantDashboardDeltas
} = require('@lib/realtime/platform-realtime');

describe('platform-realtime', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('resolves platform admin recipients', async () => {
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: 'super-admin-1' }
    ]);

    const recipients = await findPlatformAdminRecipientUserIds(['actor-1']);

    expect(recipients).toEqual(expect.arrayContaining(['super-admin-1', 'actor-1']));
  });

  it('publishes tenant dashboard deltas', async () => {
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: 'super-admin-1' }
    ]);

    await publishPlatformRealtimeEvent({
      event: 'tenant.created',
      resource_type: 'tenant',
      resource_id: 'tenant-1',
      actor_user_id: 'actor-1',
      dashboard_deltas: buildTenantDashboardDeltas({ is_active: true }, 'create')
    });

    expect(publishDomainEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        event: 'tenant.created',
        resource_type: 'tenant',
        resource_id: 'tenant-1',
        recipient_user_ids: expect.arrayContaining(['super-admin-1', 'actor-1']),
        payload: expect.objectContaining({
          dashboard_deltas: expect.objectContaining({
            status_cards: expect.objectContaining({
              tenants_active: expect.objectContaining({
                value_delta: 1,
                secondary_delta: 1
              })
            })
          })
        })
      })
    );
  });
});
