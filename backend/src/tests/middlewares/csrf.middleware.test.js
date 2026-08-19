const csrfMiddleware = require('@middlewares/csrf.middleware');
const { issueCsrfToken } = require('@lib/security/csrf-token');

const SESSION_ID = 'a1b2c3d4e5f60718';

const makeRequest = (overrides = {}) => ({
  method: 'POST',
  path: '/api/v1/patients',
  headers: {},
  session: {},
  sessionId: SESSION_ID,
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
      statusCode: 403,
      // Explicit, so clients cannot confuse this with any other 403 whose
      // message key happens to end in `.missing`.
      problemCode: 'CSRF_MISSING'
    });
  });

  it('accepts a signed token with no matching session entry', () => {
    // The defining multi-process case: the token was issued by another worker,
    // so this worker's session map holds nothing for it.
    const token = issueCsrfToken(SESSION_ID);
    const next = runMiddleware(
      makeRequest({ headers: { 'x-csrf-token': token }, session: {} })
    );

    expect(next).toHaveBeenCalledWith();
  });

  it('accepts a signed token when the session cookie was dropped', () => {
    const token = issueCsrfToken(SESSION_ID);
    const next = runMiddleware(
      makeRequest({
        headers: { 'x-csrf-token': token },
        sessionId: 'ffffffffffffffff',
        session: {}
      })
    );

    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a forged token with an explicit code', () => {
    const next = runMiddleware(
      makeRequest({ headers: { 'x-csrf-token': 'forged-token' }, session: {} })
    );

    expect(next.mock.calls[0][0]).toMatchObject({
      messageKey: 'errors.csrf.invalid',
      statusCode: 403,
      problemCode: 'CSRF_INVALID'
    });
  });

  it('still accepts a legacy session-stored token', () => {
    const next = runMiddleware(
      makeRequest({
        headers: { 'x-csrf-token': 'legacy-token' },
        session: { _csrf: 'legacy-token' }
      })
    );

    expect(next).toHaveBeenCalledWith();
  });
});
