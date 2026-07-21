describe('publishDomainEvent', () => {
  const loadEmitWithGateway = (gatewayOverrides = {}) => {
    jest.resetModules();
    const sendToUser = jest.fn(() => true);
    const broadcast = jest.fn(() => 0);

    jest.doMock('@lib/logging', () => ({
      logger: {
        warn: jest.fn(),
        info: jest.fn(),
        error: jest.fn()
      }
    }));
    jest.doMock('@lib/identifiers/sanitize-friendly-ids', () => ({
      sanitizeFriendlyIds: (payload) => payload
    }));
    jest.doMock('@websockets/gateway', () => ({
      sendToUser,
      broadcast,
      ...gatewayOverrides
    }));

    return {
      emit: require('@lib/websocket/emit'),
      sendToUser,
      broadcast
    };
  };

  afterEach(() => {
    jest.clearAllMocks();
  });

  test('creates a stable snake_case domain payload shape', () => {
    const { emit, sendToUser } = loadEmitWithGateway();

    const sent = emit.publishDomainEvent({
      event: 'payment.reconciled',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      actor_user_id: 'user-1',
      resource_type: 'payment',
      resource_id: 'payment-1',
      affected: {
        payment_id: 'payment-1',
        invoice_id: 'invoice-1'
      },
      payload: {
        payment_id: 'payment-1',
        status: 'COMPLETED'
      },
      recipient_user_ids: ['user-2']
    });

    expect(sent).toBe(2);
    expect(sendToUser).toHaveBeenCalledTimes(2);
    const [ event, payload] = sendToUser.mock.calls[0];
    expect(event).toBe('payment.reconciled');
    expect(payload).toMatchObject({
      event: 'payment.reconciled',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      actor_user_id: 'user-1',
      resource_type: 'payment',
      resource_id: 'payment-1',
      affected: {
        payment_id: 'payment-1',
        invoice_id: 'invoice-1'
      },
      payload: {
        payment_id: 'payment-1',
        status: 'COMPLETED'
      }
    });
    expect(payload.occurred_at).toBeDefined();
    expect(payload.payload.occurred_at).toBeDefined();
  });

  test('does not throw into service flow when delivery fails', () => {
    const { emit } = loadEmitWithGateway({
      sendToUser: jest.fn(() => {
        throw new Error('socket down');
      })
    });

    expect(() => {
      emit.publishDomainEvent({
        event: 'patient.updated',
        tenant_id: 'tenant-1',
        actor_user_id: 'user-1',
        resource_type: 'patient',
        resource_id: 'patient-1',
        recipient_user_ids: ['user-2']
      });
    }).not.toThrow();
  });
});
