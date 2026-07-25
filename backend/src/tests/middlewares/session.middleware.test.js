const sessionMiddleware = require('@middlewares/session.middleware');

describe('sessionMiddleware CSRF persistence', () => {
  beforeEach(() => {
    sessionMiddleware._store.delete('session-a');
  });

  it('persists CSRF token before the response finish event', () => {
    const middleware = sessionMiddleware();
    const req = {
      cookies: { sessionId: 'session-a' }
    };
    const res = {
      on: jest.fn(),
      cookie: jest.fn()
    };

    middleware(req, res, () => {});

    req.session._csrf = 'token-one';

    expect(sessionMiddleware._store.get('session-a')._csrf).toBe('token-one');
  });

  it('makes a follow-up request see the token set by getCsrfToken', () => {
    const middleware = sessionMiddleware();

    const firstReq = { cookies: { sessionId: 'session-a' } };
    const firstRes = { on: jest.fn(), cookie: jest.fn() };
    middleware(firstReq, firstRes, () => {});
    firstReq.session._csrf = 'fresh-token';

    const secondReq = { cookies: { sessionId: 'session-a' } };
    const secondRes = { on: jest.fn(), cookie: jest.fn() };
    middleware(secondReq, secondRes, () => {});

    expect(secondReq.session._csrf).toBe('fresh-token');
  });
});
