describe('publishCrudRealtimeEvent', () => {
  const loadCrudRealtime = () => {
    jest.resetModules();

    const publishDomainEvent = jest.fn(() => 1);
    const findRealtimeRecipientUserIds = jest.fn(async () => ['user-2']);

    jest.doMock('@lib/logging', () => ({
      logger: {
        warn: jest.fn(),
        info: jest.fn(),
        error: jest.fn()
      }
    }));
    jest.doMock('@lib/websocket/emit', () => ({
      publishDomainEvent
    }));
    jest.doMock('@lib/realtime/recipients', () => ({
      findRealtimeRecipientUserIds
    }));

    return {
      publishCrudRealtimeEvent: require('@lib/websocket/crud-realtime').publishCrudRealtimeEvent,
      publishDomainEvent,
      findRealtimeRecipientUserIds
    };
  };

  afterEach(() => {
    jest.clearAllMocks();
  });

  test('publishes scoped CRUD events with stable snake_case payload', async () => {
    const { publishCrudRealtimeEvent, publishDomainEvent, findRealtimeRecipientUserIds } =
      loadCrudRealtime();

    const sent = await publishCrudRealtimeEvent({
      event: 'facility.layout_updated',
      resource: {
        id: 'ward-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'
      },
      resource_type: 'ward',
      actor_user_id: 'user-1',
      recipient_roles: ['FACILITY_ADMIN'],
      payload: {
        operation: 'updated',
        name: 'Ward A'
      }
    });

    expect(sent).toBe(1);
    expect(findRealtimeRecipientUserIds).toHaveBeenCalledWith({
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      roles: ['FACILITY_ADMIN'],
      extraUserIds: ['user-1']
    });
    expect(publishDomainEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        event: 'facility.layout_updated',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        resource_type: 'ward',
        resource_id: 'ward-1',
        payload: expect.objectContaining({
          ward_id: 'ward-1',
          operation: 'updated',
          name: 'Ward A'
        })
      })
    );
  });

  test('returns zero when required fields are missing', async () => {
    const { publishCrudRealtimeEvent, publishDomainEvent } = loadCrudRealtime();

    const sent = await publishCrudRealtimeEvent({
      event: 'patient.updated',
      resource: {},
      resource_type: 'patient'
    });

    expect(sent).toBe(0);
    expect(publishDomainEvent).not.toHaveBeenCalled();
  });
});
