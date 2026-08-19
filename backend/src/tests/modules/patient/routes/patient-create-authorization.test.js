/**
 * Pins the 401-vs-403 contract for `POST /api/v1/patients`.
 *
 * The route guards with `authenticate()` then
 * `authorize(PERMISSIONS.PATIENT_WRITE, 'permission')`. A signed-in clinician
 * without the permission must get 403 — a client that receives 401 will show
 * "Sign-in required" and, on the refresh path, end the session.
 */

jest.mock('@lib/audit', () => ({ createAuditLog: jest.fn().mockResolvedValue(undefined) }));
jest.mock('@lib/telemetry/metrics', () => ({
  markSpanError: jest.fn(),
  recordSecurityEvent: jest.fn()
}));

const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const { generateToken } = require('@lib/jwt');

const runGuards = async (req) => {
  const errors = [];
  const collect = (err) => {
    if (err) {
      errors.push(err);
    }
  };

  await new Promise((resolve) => authenticate()(req, {}, (err) => {
    collect(err);
    resolve();
  }));

  if (errors.length === 0) {
    authorize(PERMISSIONS.PATIENT_WRITE, 'permission')(req, {}, collect);
  }

  return errors[0] || null;
};

const makeRequest = (headers = {}) => ({
  method: 'POST',
  path: '/',
  originalUrl: '/api/v1/patients',
  headers,
  ip: '127.0.0.1',
  get: () => undefined
});

describe('POST /patients authorization', () => {
  it('returns 401 when no credentials are presented', async () => {
    const error = await runGuards(makeRequest());

    expect(error).toMatchObject({
      statusCode: 401,
      messageKey: 'errors.auth.missing_token'
    });
  });

  it('returns 401 for an unusable token', async () => {
    const error = await runGuards(
      makeRequest({ authorization: 'Bearer not-a-real-token' })
    );

    expect(error).toMatchObject({
      statusCode: 401,
      messageKey: 'errors.auth.invalid_token'
    });
  });

  it('returns 403 — not 401 — for a signed-in user without the permission', async () => {
    const token = generateToken({
      userId: 'user-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      roles: ['DOCTOR'],
      permissions: [PERMISSIONS.PATIENT_READ]
    });

    const error = await runGuards(makeRequest({ authorization: `Bearer ${token}` }));

    expect(error).toMatchObject({
      statusCode: 403,
      messageKey: 'errors.auth.insufficient_permissions'
    });
    expect(error.statusCode).not.toBe(401);
  });

  it('passes a signed-in user holding patient write', async () => {
    const token = generateToken({
      userId: 'user-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      roles: ['DOCTOR'],
      permissions: [PERMISSIONS.PATIENT_WRITE]
    });

    const error = await runGuards(makeRequest({ authorization: `Bearer ${token}` }));

    expect(error).toBeNull();
  });
});
