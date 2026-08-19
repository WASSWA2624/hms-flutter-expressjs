const {
  issueCsrfToken,
  verifyCsrfToken,
  DEFAULT_TTL_SECONDS
} = require('@lib/security/csrf-token');

describe('csrf-token', () => {
  const sessionId = 'a1b2c3d4e5f60718';

  it('issues a token that verifies against the same session', () => {
    const token = issueCsrfToken(sessionId);

    const result = verifyCsrfToken(token, { sessionId });

    expect(result.valid).toBe(true);
    expect(result.sessionBound).toBe(true);
  });

  it('verifies a token issued by another process holding the same secret', () => {
    // Nothing is retained between issue and verify, so a token minted by one
    // worker validates on any other. This is what the in-memory session store
    // could not do, and why every mutation failed under Passenger.
    const token = issueCsrfToken(sessionId);

    jest.resetModules();
    const freshModule = require('@lib/security/csrf-token');

    expect(freshModule.verifyCsrfToken(token, { sessionId }).valid).toBe(true);
  });

  it('rejects a forged token', () => {
    const result = verifyCsrfToken('1700000000.deadbeefdeadbeef.nonce.badsig', {
      sessionId
    });

    expect(result.valid).toBe(false);
    expect(result.reason).toBe('signature');
  });

  it('rejects a tampered token', () => {
    const token = issueCsrfToken(sessionId);
    const [issuedAt, binding, nonce, signature] = token.split('.');
    const tampered = [issuedAt, binding, `${nonce}0`, signature].join('.');

    expect(verifyCsrfToken(tampered, { sessionId }).valid).toBe(false);
  });

  it('rejects a malformed token', () => {
    expect(verifyCsrfToken('not-a-token', { sessionId }).reason).toBe('malformed');
    expect(verifyCsrfToken('', { sessionId }).reason).toBe('malformed');
    expect(verifyCsrfToken(undefined, { sessionId }).reason).toBe('malformed');
  });

  it('rejects an expired token', () => {
    const token = issueCsrfToken(sessionId);

    const result = verifyCsrfToken(token, { sessionId, ttlSeconds: -1 });

    expect(result.valid).toBe(false);
    expect(result.reason).toBe('expired');
  });

  it('accepts within the default TTL', () => {
    const token = issueCsrfToken(sessionId);

    expect(
      verifyCsrfToken(token, { sessionId, ttlSeconds: DEFAULT_TTL_SECONDS }).valid
    ).toBe(true);
  });

  it('reports a lost session cookie instead of failing outright', () => {
    const token = issueCsrfToken(sessionId);

    // The cookie did not come back (cross-site cookie blocking), so the caller
    // presents a different session id.
    const result = verifyCsrfToken(token, { sessionId: 'ffffffffffffffff' });

    expect(result.valid).toBe(true);
    expect(result.sessionBound).toBe(false);
  });
});
