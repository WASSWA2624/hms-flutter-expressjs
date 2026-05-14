/**
 * error middleware tests
 */

jest.mock('@lib/errors', () => ({
  handleApiError: jest.fn(),
}));

jest.mock('@lib/logging', () => ({
  logger: {
    error: jest.fn(),
  },
}));

jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(() => Promise.resolve()),
}));

const { handleApiError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
const errorMiddleware = require('@middlewares/error.middleware');

describe('error middleware', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('delegates to handleApiError', () => {
    const err = { message: 'boom', statusCode: 500, stack: 'stack' };
    const req = { path: '/x', method: 'GET', ip: '127.0.0.1', get: jest.fn() };
    const res = {};
    const next = jest.fn();

    errorMiddleware(err, req, res, next);

    expect(handleApiError).toHaveBeenCalledWith(err, req, res, next);
  });

  it('logs 403 authorization audit with null tenant/user fallbacks', () => {
    const err = { message: 'forbidden', statusCode: 403, stack: 'stack' };
    const req = {
      path: '/api/v1/auth/login',
      method: 'POST',
      ip: '127.0.0.1',
      get: jest.fn(() => 'jest-agent'),
      user: undefined,
    };
    const res = {};
    const next = jest.fn();

    errorMiddleware(err, req, res, next);

    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'ACCESS',
        entity: 'authorization',
        entity_id: '/api/v1/auth/login',
        user_id: null,
        tenant_id: null,
        facility_id: null,
      })
    );
  });
});
