const createGateway = () => {
  jest.resetModules();

  const mockWss = { on: jest.fn() };

  jest.doMock('@lib/logging', () => ({
    logger: {
      warn: jest.fn(),
      info: jest.fn(),
      error: jest.fn()
    }
  }));

  jest.doMock('@websockets/server', () => ({
    getWebSocketServer: jest.fn(() => mockWss)
  }));

  const gateway = require('@websockets/gateway');

  return { gateway, mockWss };
};

const socket = () => ({
  OPEN: 1,
  readyState: 1,
  send: jest.fn(),
  close: jest.fn()
});

describe('WebSocket gateway', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  test('initializes gateway and registers connection handler', () => {
    const { gateway, mockWss } = createGateway();
    gateway.initializeGateway();
    expect(mockWss.on).toHaveBeenCalled();
    expect(mockWss.on.mock.calls[0][0]).toBe('connection');
    expect(typeof mockWss.on.mock.calls[0][1]).toBe('function');
    gateway.cleanup();
  });

  test('registers connections and sends events', () => {
    const { gateway } = createGateway();
    const ws1 = socket();
    const ws2 = socket();

    gateway.registerUserConnection('user-1', ws1);
    gateway.registerUserConnection('user-2', ws2);

    const sent = gateway.sendToUser('user-1', 'test.event', { ok: true });
    expect(sent).toBe(true);
    expect(ws1.send).toHaveBeenCalled();

    const count = gateway.broadcast('test.broadcast', { ok: true });
    expect(count).toBe(2);
    expect(ws2.send).toHaveBeenCalled();
    gateway.cleanup();
  });

  test('supports multiple active sockets for one user', () => {
    const { gateway } = createGateway();
    const firstTab = socket();
    const secondTab = socket();

    gateway.registerUserConnection('user-1', firstTab);
    gateway.registerUserConnection('user-1', secondTab);

    expect(gateway.getConnectionCount()).toBe(2);
    expect(gateway.getConnectedUsers()).toEqual(['user-1']);

    const sent = gateway.sendToUser('user-1', 'patient.updated', {
      patient_id: 'patient-1'
    });
    expect(sent).toBe(true);
    expect(firstTab.send).toHaveBeenCalledTimes(1);
    expect(secondTab.send).toHaveBeenCalledTimes(1);

    gateway.cleanup();
  });

  test('broadcast reaches every non-excluded socket across users', () => {
    const { gateway } = createGateway();
    const userOneTabA = socket();
    const userOneTabB = socket();
    const userTwo = socket();

    gateway.registerUserConnection('user-1', userOneTabA);
    gateway.registerUserConnection('user-1', userOneTabB);
    gateway.registerUserConnection('user-2', userTwo);

    const count = gateway.broadcast('payment.reconciled', {}, ['user-2']);

    expect(count).toBe(2);
    expect(userOneTabA.send).toHaveBeenCalledTimes(1);
    expect(userOneTabB.send).toHaveBeenCalledTimes(1);
    expect(userTwo.send).not.toHaveBeenCalled();

    gateway.cleanup();
  });

  test('unregistering one user closes only that user mapping', () => {
    const { gateway } = createGateway();
    const ws1 = socket();
    const ws2 = socket();
    gateway.registerUserConnection('user-1', ws1);
    gateway.registerUserConnection('user-1', ws2);
    expect(gateway.isUserConnected('user-1')).toBe(true);

    gateway.unregisterUserConnection('user-1');
    expect(gateway.isUserConnected('user-1')).toBe(false);
    expect(gateway.getConnectionCount()).toBe(0);
    gateway.cleanup();
  });

  test('cleanup closes all sockets and removes mappings safely', () => {
    const { gateway } = createGateway();
    const userOne = socket();
    const userTwo = socket();

    gateway.registerUserConnection('user-1', userOne);
    gateway.registerUserConnection('user-2', userTwo);
    gateway.cleanup();

    expect(userOne.close).toHaveBeenCalledWith(1001, 'Server shutting down');
    expect(userTwo.close).toHaveBeenCalledWith(1001, 'Server shutting down');
    expect(gateway.getConnectionCount()).toBe(0);
    expect(gateway.getConnectedUsers()).toEqual([]);
  });
});
