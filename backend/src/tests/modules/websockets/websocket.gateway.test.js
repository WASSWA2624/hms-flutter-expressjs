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
    const ws1 = { OPEN: 1, readyState: 1, send: jest.fn(), close: jest.fn() };
    const ws2 = { OPEN: 1, readyState: 1, send: jest.fn(), close: jest.fn() };

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

  test('unregisters connections cleanly', () => {
    const { gateway } = createGateway();
    const ws = { OPEN: 1, readyState: 1, send: jest.fn(), close: jest.fn() };
    gateway.registerUserConnection('user-1', ws);
    expect(gateway.isUserConnected('user-1')).toBe(true);

    gateway.unregisterUserConnection('user-1');
    expect(gateway.isUserConnected('user-1')).toBe(false);
    gateway.cleanup();
  });
});
