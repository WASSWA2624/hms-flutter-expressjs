jest.mock('@lib/logging', () => ({
  logger: {
    warn: jest.fn(),
    info: jest.fn(),
    error: jest.fn()
  }
}));

const { rateLimit, defaultRateLimit } = require('@middlewares/rateLimit.middleware');

const createRes = () => {
  const res = {
    locals: { locale: 'en', direction: 'ltr' },
    headers: {},
    statusCode: 200,
    setHeader: jest.fn((key, value) => {
      res.headers[key] = value;
    }),
    status: jest.fn((code) => {
      res.statusCode = code;
      return res;
    }),
    json: jest.fn((payload) => {
      res.body = payload;
      return res;
    })
  };
  return res;
};

describe('rate limit middleware', () => {
  test('sets rate limit headers and allows under limit', () => {
    const middleware = rateLimit({ windowMs: 1000, max: 2 });
    const req = { path: '/test', ip: '127.0.0.1' };
    const res = createRes();
    const next = jest.fn();

    middleware(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(res.headers['X-RateLimit-Limit']).toBe(2);
    expect(res.headers['X-RateLimit-Remaining']).toBe(1);
    expect(res.headers['X-RateLimit-Reset']).toBeDefined();
  });

  test('blocks when limit exceeded', () => {
    const middleware = rateLimit({ windowMs: 1000, max: 2 });
    const req = { path: '/test', ip: '127.0.0.1' };
    const next = jest.fn();

    const res1 = createRes();
    middleware(req, res1, next);

    const res2 = createRes();
    middleware(req, res2, next);

    const res3 = createRes();
    middleware(req, res3, next);

    expect(res3.statusCode).toBe(429);
    expect(res3.body.status).toBe(429);
    expect(res3.body.type).toBe('urn:problem-type:hms:EXCEEDED');
    expect(res3.body.detail).toBeDefined();
    expect(res3.body.meta).toBeDefined();
    expect(Array.isArray(res3.body.errors)).toBe(true);
    expect(res3.headers['Content-Type']).toBe('application/problem+json');
    expect(res3.headers['X-RateLimit-Remaining']).toBe(0);
  });

  test('uses authenticated limits when a bearer token is present before auth middleware runs', () => {
    const middleware = defaultRateLimit();
    const next = jest.fn();
    const req = {
      path: '/authenticated-test',
      ip: '127.0.0.1',
      headers: {
        authorization: 'Bearer test-access-token',
      },
    };

    for (let index = 0; index < 101; index += 1) {
      const res = createRes();
      middleware(req, res, next);
      expect(res.statusCode).toBe(200);
    }

    expect(next).toHaveBeenCalledTimes(101);
  });
});
