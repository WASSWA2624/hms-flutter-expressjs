/**
 * response error helper tests
 */

const { sendError } = require('@lib/response/error');
const { handleApiError } = require('@lib/errors');
const { z } = require('zod');

const createResponse = (path = '/api/v1/example') => {
  const headers = new Map();
  const res = {
    locals: { locale: 'en', direction: 'ltr' },
    req: {
      originalUrl: path,
      path,
      url: path
    },
    statusCode: 200,
    payload: null,
    status: jest.fn((code) => {
      res.statusCode = code;
      return res;
    }),
    json: jest.fn((payload) => {
      res.payload = payload;
      return res;
    }),
    type: jest.fn((value) => {
      headers.set('content-type', value);
      return res;
    }),
    setHeader: jest.fn((name, value) => {
      headers.set(String(name).toLowerCase(), value);
    }),
    getHeader: jest.fn((name) => headers.get(String(name).toLowerCase())),
    removeHeader: jest.fn()
  };
  return res;
};

describe('response error helpers', () => {
  it('sendError returns RFC 9457 Problem Details', () => {
    const res = createResponse();

    sendError(res, 404, 'errors.not_found');

    expect(res.statusCode).toBe(404);
    expect(res.getHeader('Content-Type')).toBe('application/problem+json');
    expect(res.payload).toMatchObject({
      type: 'urn:problem-type:hms:NOT_FOUND',
      title: expect.any(String),
      status: 404,
      detail: expect.any(String),
      code: 'NOT_FOUND',
      instance: '/api/v1/example'
    });
    expect(Array.isArray(res.payload.errors)).toBe(true);
    expect(res.payload.errors).toEqual([]);
  });

  it('handleApiError returns RFC 9457 Problem Details', () => {
    const res = createResponse();
    const req = { path: '/api/v1/example', method: 'GET', ip: '127.0.0.1' };
    const next = jest.fn();

    handleApiError(new Error('unexpected'), req, res, next);

    expect(res.statusCode).toBe(500);
    expect(res.getHeader('Content-Type')).toBe('application/problem+json');
    expect(res.payload).toMatchObject({
      type: 'urn:problem-type:hms:UNEXPECTED',
      title: expect.any(String),
      status: 500,
      detail: expect.any(String),
      code: 'UNEXPECTED',
      instance: '/api/v1/example'
    });
    expect(Array.isArray(res.payload.errors)).toBe(true);
    expect(res.payload.errors).toEqual([]);
  });

  it('handleApiError formats validation failures as Problem Details', () => {
    const res = createResponse('/api/v1/addresses');
    const req = { path: '/api/v1/addresses', method: 'POST', ip: '127.0.0.1' };
    const next = jest.fn();

    const schema = z.object({
      line1: z.string().min(1)
    });

    let validationError;
    try {
      schema.parse({ line1: '' });
    } catch (error) {
      validationError = error;
    }

    handleApiError(validationError, req, res, next);

    expect(res.statusCode).toBe(400);
    expect(res.getHeader('Content-Type')).toBe('application/problem+json');
    expect(res.payload).toMatchObject({
      status: 400,
      instance: '/api/v1/addresses'
    });
    expect(Array.isArray(res.payload.errors)).toBe(true);
    expect(res.payload.errors[0]).toMatchObject({
      field: 'line1',
      message: expect.any(String)
    });
  });

  it('handleApiError preserves translated validation keys and required-field details', () => {
    const res = createResponse('/api/v1/auth/reset-password');
    const req = { path: '/api/v1/auth/reset-password', method: 'POST', ip: '127.0.0.1' };
    const next = jest.fn();

    const schema = z.object({
      old_password: z.string(),
      new_password: z.string().min(8, 'errors.validation.password.min_length'),
    });

    let validationError;
    try {
      schema.parse({ new_password: 'short' });
    } catch (error) {
      validationError = error;
    }

    handleApiError(validationError, req, res, next);

    expect(res.statusCode).toBe(400);
    expect(res.payload.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          field: 'old_password',
          message: 'old_password is required',
        }),
        expect.objectContaining({
          field: 'new_password',
          message: 'Password must be at least 8 characters',
        }),
      ])
    );
  });
});
