const { HttpError } = require('@lib/errors');
const licenseRepository = require('@repositories/license/license.repository');
const { createAuditLog } = require('@lib/audit');
const subject = require('@services/license/license.service');

jest.mock('@repositories/license/license.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null),
}));

const buildRecord = (overrides = {}) => ({
  id: 'license-uuid',
  human_friendly_id: 'LIC0001',
  tenant_id: 'tenant-uuid',
  tenant: {
    id: 'tenant-uuid',
    human_friendly_id: 'TEN0001',
    name: 'Acme',
  },
  license_type: 'PER_USER',
  status: 'ACTIVE',
  plan_tier_code: 'PRO',
  issued_at: '2026-03-01T00:00:00.000Z',
  expires_at: '2026-04-01T00:00:00.000Z',
  ...overrides,
});

describe('License Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('returns serialized license details', async () => {
    licenseRepository.findById.mockResolvedValue(buildRecord());

    await expect(subject.getLicenseById('LIC0001')).resolves.toEqual(
      expect.objectContaining({
        id: 'LIC0001',
        tenant_id: 'TEN0001',
        tenant_label: 'Acme',
        license_type: 'PER_USER',
      })
    );
  });

  it('lists licenses with serialized rows and pagination', async () => {
    licenseRepository.findMany.mockResolvedValue([
      buildRecord(),
      buildRecord({
        id: 'license-uuid-2',
        human_friendly_id: 'LIC0002',
      }),
    ]);
    licenseRepository.count.mockResolvedValue(2);

    const result = await subject.listLicenses(
      { tenant_id: 'TEN0001', status: 'ACTIVE' },
      1,
      20
    );

    expect(licenseRepository.findMany).toHaveBeenCalledWith(
      { tenant_id: 'TEN0001', status: 'ACTIVE' },
      0,
      20,
      { created_at: 'desc' }
    );
    expect(result.licenses).toEqual([
      expect.objectContaining({ id: 'LIC0001' }),
      expect.objectContaining({ id: 'LIC0002' }),
    ]);
  });

  it('creates a license, reloads it, and writes an audit log', async () => {
    const created = buildRecord({
      id: 'license-uuid-2',
      human_friendly_id: 'LIC0002',
    });
    licenseRepository.create.mockResolvedValue({ id: created.id });
    licenseRepository.findById.mockResolvedValue(created);

    const result = await subject.createLicense(
      {
        tenant_id: 'TEN0001',
        human_friendly_id: 'LIC0002',
        license_type: 'PER_USER',
        status: 'ACTIVE',
      },
      {
        user: { id: 'user-1', role: 'SUPER_ADMIN' },
        ip: '127.0.0.1',
        tenant_id: 'tenant-uuid',
      }
    );

    expect(result).toEqual(expect.objectContaining({ id: 'LIC0002' }));
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'license',
      })
    );
  });

  it('updates a license and returns the serialized record', async () => {
    const before = buildRecord();
    const after = buildRecord({ status: 'CANCELLED' });
    licenseRepository.findById
      .mockResolvedValueOnce(before)
      .mockResolvedValueOnce(after);
    licenseRepository.update.mockResolvedValue(after);

    const result = await subject.updateLicense(
      'LIC0001',
      { status: 'CANCELLED' },
      {
        user: { id: 'user-1', role: 'SUPER_ADMIN' },
        ip: '127.0.0.1',
        tenant_id: 'tenant-uuid',
      }
    );

    expect(result).toEqual(
      expect.objectContaining({
        id: 'LIC0001',
        status: 'CANCELLED',
      })
    );
  });

  it('throws HttpError when the license does not exist', async () => {
    licenseRepository.findById.mockResolvedValue(null);

    await expect(subject.getLicenseById('LIC404')).rejects.toThrow(HttpError);
  });
});
