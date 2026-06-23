describe('publishAuditRealtime', () => {
  const loadAuditRealtime = () => {
    jest.resetModules();

    const publishCrudRealtimeEvent = jest.fn(async () => 1);

    jest.doMock('@lib/logging', () => ({
      logger: {
        warn: jest.fn(),
        info: jest.fn(),
        error: jest.fn()
      }
    }));
    jest.doMock('@lib/websocket/crud-realtime', () => ({
      publishCrudRealtimeEvent
    }));

    return {
      auditRealtime: require('@lib/realtime/audit-realtime'),
      publishCrudRealtimeEvent
    };
  };

  afterEach(() => {
    jest.clearAllMocks();
  });

  test('publishes department.updated for update audit entries', async () => {
    const { auditRealtime, publishCrudRealtimeEvent } = loadAuditRealtime();

    await auditRealtime.publishAuditRealtime(
      {
        action: 'DEPARTMENT_UPDATED',
        entity: 'department',
        entity_id: 'department-1',
        user_id: 'user-1',
        diff: {
          after: {
            tenant_id: 'tenant-1',
            facility_id: 'facility-1',
            name: 'Emergency'
          }
        }
      },
      'tenant-1',
      'UPDATE'
    );

    expect(publishCrudRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        event: 'department.updated',
        resource_type: 'department',
        actor_user_id: 'user-1',
        resource: expect.objectContaining({
          id: 'department-1',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1'
        })
      })
    );
  });

  test('maps cancel actions to canceled events', async () => {
    const { auditRealtime, publishCrudRealtimeEvent } = loadAuditRealtime();

    await auditRealtime.publishAuditRealtime(
      {
        action: 'CANCEL',
        entity: 'appointment',
        entity_id: 'appointment-1',
        user_id: 'user-1',
        diff: {
          after: {
            tenant_id: 'tenant-1',
            facility_id: 'facility-1'
          }
        }
      },
      'tenant-1',
      'UPDATE'
    );

    expect(publishCrudRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        event: 'appointment.canceled'
      })
    );
  });

  test('skips entities with bespoke realtime publishers', async () => {
    const { auditRealtime, publishCrudRealtimeEvent } = loadAuditRealtime();

    await auditRealtime.publishAuditRealtime(
      {
        action: 'UPDATE',
        entity: 'patient',
        entity_id: 'patient-1',
        diff: { after: { tenant_id: 'tenant-1' } }
      },
      'tenant-1',
      'UPDATE'
    );

    expect(publishCrudRealtimeEvent).not.toHaveBeenCalled();
  });

  test('honors realtime opt-out flag', async () => {
    const { auditRealtime, publishCrudRealtimeEvent } = loadAuditRealtime();

    await auditRealtime.publishAuditRealtime(
      {
        realtime: false,
        action: 'CREATE',
        entity: 'department',
        entity_id: 'department-1',
        diff: { after: { tenant_id: 'tenant-1' } }
      },
      'tenant-1',
      'CREATE'
    );

    expect(publishCrudRealtimeEvent).not.toHaveBeenCalled();
  });
});
