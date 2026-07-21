/**
 * server bootstrap tests
 */

describe('server bootstrap', () => {
  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetModules();
  });

  it('gracefully shuts down on unhandled promise rejection', async () => {
    const handlers = {};
    const processOnSpy = jest.spyOn(process, 'on').mockImplementation((event, handler) => {
      handlers[event] = handler;
      return process;
    });
    const processExitSpy = jest.spyOn(process, 'exit').mockImplementation(() => undefined);

    const closeSpy = jest.fn((callback) => {
      if (typeof callback === 'function') {
        callback();
      }
    });
    const mockServer = {
      close: closeSpy,
      once: jest.fn((event, handler) => {
        if (event === 'listening' && typeof handler === 'function') {
          handler();
        }
        return mockServer;
      })
    };
    const listenSpy = jest.fn(() => mockServer);

    const logger = {
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn()
    };
    const initializeWebSocketServer = jest.fn();
    const initializeGateway = jest.fn();
    const closeWebSocketServer = jest.fn(async () => undefined);
    const startReportRunScheduler = jest.fn();
    const stopReportRunScheduler = jest.fn();
    const startNotificationDeliveryRuntime = jest.fn();
    const stopNotificationDeliveryRuntime = jest.fn();
    const startBreakGlassExpiryRuntime = jest.fn();
    const stopBreakGlassExpiryRuntime = jest.fn();
    const syncActiveSubscriptionModuleEntitlements = jest
      .fn()
      .mockResolvedValue({ subscriptions: 0 });
    const assertDatabaseConnection = jest.fn(async () => undefined);
    const cleanup = jest.fn();

    jest.doMock('@lib/aliases', () => ({
      registerAllModuleAliases: jest.fn()
    }));
    jest.doMock('@config/env', () => ({
      PORT: 3000,
      HOST: '127.0.0.1',
      NODE_ENV: 'test',
      HANDLE_SIGINT: true
    }));
    jest.doMock('@app/index', () => jest.fn(() => ({ listen: listenSpy })));
    jest.doMock('@lib/logging', () => ({ logger }));
    jest.doMock('@lib/health/startupDatabaseCheck', () => ({
      assertDatabaseConnection}));
    jest.doMock('@lib/reports/runtime', () => ({
      startReportRunScheduler,
      stopReportRunScheduler}));
    jest.doMock('@lib/notifications/runtime', () => ({
      startNotificationDeliveryRuntime,
      stopNotificationDeliveryRuntime}));
    jest.doMock('@lib/authorization/break-glass-expiry', () => ({
      startBreakGlassExpiryRuntime,
      stopBreakGlassExpiryRuntime}));
    jest.doMock(
      '@lib/subscriptions/sync-subscription-module-entitlements',
      () => ({
        syncActiveSubscriptionModuleEntitlements})
    );
    jest.doMock('@websockets/server', () => ({
      initializeWebSocketServer,
      closeWebSocketServer
    }));
    jest.doMock('@websockets/gateway', () => ({
      initializeGateway,
      cleanup
    }));

    let startServer;
    jest.isolateModules(() => {
      ({ startServer } = require('../../server'));
    });

    await startServer();

    expect(typeof handlers.unhandledRejection).toBe('function');

    handlers.unhandledRejection(new Error('boom'), Promise.resolve());
    await Promise.resolve();
    await Promise.resolve();

    expect(closeSpy).toHaveBeenCalledTimes(1);
    expect(startNotificationDeliveryRuntime).toHaveBeenCalledTimes(1);
    expect(startBreakGlassExpiryRuntime).toHaveBeenCalledTimes(1);
    expect(syncActiveSubscriptionModuleEntitlements).toHaveBeenCalledTimes(1);
    expect(stopReportRunScheduler).toHaveBeenCalledTimes(1);
    expect(stopNotificationDeliveryRuntime).toHaveBeenCalledTimes(1);
    expect(stopBreakGlassExpiryRuntime).toHaveBeenCalledTimes(1);
    expect(closeWebSocketServer).toHaveBeenCalledTimes(1);
    expect(cleanup).toHaveBeenCalledTimes(1);
    expect(processExitSpy).toHaveBeenCalledWith(1);

    processOnSpy.mockRestore();
    processExitSpy.mockRestore();
  });
});
