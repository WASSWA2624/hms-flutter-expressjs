const csrfMiddleware = require('@middlewares/csrf.middleware');

const makeRequest = (overrides = {}) => ({
  method: 'POST',
  path: '/api/v1/patients',
  headers: {},
  session: {},
  ip: '127.0.0.1',
  ...overrides
});

const runMiddleware = (request) => {
  const next = jest.fn();
  csrfMiddleware()(request, {}, next);
  return next;
};

describe('csrfMiddleware', () => {
  it.each([
    '/api/v1/auth/logout',
    '/api/v1/auth/change-password'
  ])('allows token-authenticated auth route %s without session CSRF', (path) => {
    const next = runMiddleware(makeRequest({ path }));

    expect(next).toHaveBeenCalledTimes(1);
    expect(next).toHaveBeenCalledWith();
  });

  it('still rejects protected state-changing routes without a CSRF token', () => {
    const next = runMiddleware(makeRequest());

    expect(next).toHaveBeenCalledTimes(1);
    expect(next.mock.calls[0][0]).toMatchObject({
      messageKey: 'errors.csrf.missing',
      statusCode: 403
    });
  });
});
