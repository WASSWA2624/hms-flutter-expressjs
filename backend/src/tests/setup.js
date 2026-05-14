/**
 * Global Test Setup
 * 
 * Per testing.mdc: Global setup and mocks for Prisma, WebSocket, Storage
 * All tests must mock external dependencies (never hit production DB)
 */

const path = require('path');

/**
 * Register module aliases for Jest runtime.
 *
 * @description Jest does not execute `src/server.js`, so module-alias registration
 * must happen in test setup to allow imports like `@controllers/auth/...`.
 */
require('module-alias/register');
const moduleAlias = require('module-alias');

const srcRoot = path.join(__dirname, '..'); // src/

moduleAlias.addAliases({
  '@app': path.join(srcRoot, 'app'),
  '@lib': path.join(srcRoot, 'lib'),
  '@config': path.join(srcRoot, 'config'),
  '@middlewares': path.join(srcRoot, 'middlewares'),
  '@prisma/client': path.join(srcRoot, 'prisma', 'client.js'),
  '@prisma/client/runtime': path.join(srcRoot, '..', 'node_modules', '@prisma', 'client', 'runtime'),
  '@logs': path.join(process.cwd(), 'logs'),
  '@websockets': path.join(srcRoot, 'websockets')
});

// Mock environment variables (must be set before any config imports)
const { setEnvForTests } = require('@config/env');
setEnvForTests({
  JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
  NODE_ENV: 'test',
  DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
  CORS_ORIGINS: 'http://localhost:3000'
});

// Register module-scoped aliases (@controllers/<module>, @services/<module>, ...)
const { registerAllModuleAliases } = require('@lib/aliases');
registerAllModuleAliases();

// Mock Prisma client
jest.mock('@prisma/client', () => {
  const mockPrisma = {
    audit_log: {
      create: jest.fn()
    },
    $transaction: jest.fn(async (arg) => {
      if (typeof arg === 'function') {
        return await arg(mockPrisma);
      }
      if (Array.isArray(arg)) {
        return Promise.resolve(arg);
      }
      return Promise.resolve([]);
    }),
    $disconnect: jest.fn()
  };

  return mockPrisma;
});

/**
 * Mock WebSocket Server (ws library)
 * 
 * Per testing.mdc: WebSocket server must be mocked globally
 * Prevents tests from opening real sockets or requiring a running WS server
 */
jest.mock('ws', () => {
  const mockWebSocket = {
    OPEN: 1,
    CONNECTING: 0,
    CLOSING: 2,
    CLOSED: 3
  };

  const mockWebSocketServer = {
    clients: new Set(),
    on: jest.fn(),
    close: jest.fn((callback) => {
      if (callback) callback(null);
    }),
    options: {
      clientTracking: true
    }
  };

  return {
    WebSocketServer: jest.fn(() => mockWebSocketServer),
    WebSocket: jest.fn(() => ({
      ...mockWebSocket,
      readyState: mockWebSocket.OPEN,
      send: jest.fn(),
      close: jest.fn(),
      on: jest.fn()
    }))
  };
});

/**
 * Mock Storage Service
 * 
 * Per testing.mdc: StorageService must be mocked globally
 * Prevents tests from touching real filesystem/S3/network for storage
 */
jest.mock('@lib/storage', () => {
  const mockStorageService = {
    upload: jest.fn(async () => ({ path: 'mock/path/file.ext', size: 1024 })),
    delete: jest.fn(async () => true),
    download: jest.fn(async () => Buffer.from('mock file content')),
    exists: jest.fn(async () => true),
    getUrl: jest.fn(async () => 'https://mock-storage.example.com/file.ext'),
    getMetadata: jest.fn(async () => ({ size: 1024, mimeType: 'application/octet-stream' }))
  };

  const { createLocalStorageService: createLocalStorageServiceActual } = jest.requireActual('@lib/storage/local-storage.service');
  const { sanitizeFilename: sanitizeFilenameActual, createStorageServiceBase } = jest.requireActual('@lib/storage/storage-service');

  const mockedModule = {
    StorageService: jest.fn(() => mockStorageService),
    LocalStorageService: jest.fn(() => mockStorageService),
    S3StorageService: jest.fn(() => mockStorageService),
    createStorageService: jest.fn(() => mockStorageService),
    createStorageServiceBase,
    createLocalStorageService: jest.fn((...args) => {
      return createLocalStorageServiceActual(...args);
    }),
    sanitizeFilename: sanitizeFilenameActual
  };
  return mockedModule;
});

// Suppress console logs in tests (optional, can be removed if you want to see logs)
global.console = {
  ...console,
  log: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
};

afterAll(() => {
  try {
    const { logger } = require('@lib/logging');
    if (logger && typeof logger.close === 'function') {
      logger.close();
    }
  } catch (err) {
    // no-op: teardown should never fail tests
  }
});

