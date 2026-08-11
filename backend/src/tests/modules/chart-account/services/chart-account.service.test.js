const chartAccountService = require('@services/chart-account/chart-account.service');
const chartAccountRepository = require('@repositories/chart-account/chart-account.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/chart-account/chart-account.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  sanitizeIdentifier: (value) => value,
  resolvePublicIdentifier: (...values) => values.find((v) => v) || null,
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolveEntityId: jest.fn(async ({ identifier }) => identifier)
}));

describe('chart-account service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  it('maps display_id and nested parent on create', async () => {
    const created = {
      id: 'ca-1',
      human_friendly_id: 'CA-0001',
      tenant_id: 'tenant-1',
      facility_id: null,
      code: '1000',
      name: 'Cash',
      account_type: 'ASSET',
      parent_id: 'parent-1',
      currency: 'UGX',
      is_active: true,
      parent: { id: 'parent-1', code: '100', name: 'Current Assets', human_friendly_id: 'CA-P001' },
      tenant: { id: 'tenant-1', human_friendly_id: 'T-1' },
      facility: null
    };

    chartAccountRepository.create.mockResolvedValue(created);
    chartAccountRepository.findById.mockResolvedValue(created);

    const result = await chartAccountService.createChartAccount(
      {
        tenant_id: 'tenant-1',
        code: '1000',
        name: 'Cash',
        account_type: 'ASSET',
        parent_id: 'parent-1',
        currency: 'UGX'
      },
      'user-1',
      '127.0.0.1'
    );

    expect(result.display_id).toBe('CA-0001');
    expect(result.parent).toEqual(
      expect.objectContaining({
        id: 'parent-1',
        code: '100',
        name: 'Current Assets',
        display_id: 'CA-P001'
      })
    );
    expect(chartAccountRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-1',
        code: '1000',
        name: 'Cash',
        account_type: 'ASSET',
        currency: 'UGX',
        is_active: true
      })
    );
    expect(createAuditLog).toHaveBeenCalled();
  });

  it('deactivates via update is_active false', async () => {
    const before = {
      id: 'ca-1',
      tenant_id: 'tenant-1',
      code: '1000',
      name: 'Cash',
      account_type: 'ASSET',
      is_active: true,
      human_friendly_id: 'CA-0001'
    };
    const after = { ...before, is_active: false };

    chartAccountRepository.findById
      .mockResolvedValueOnce(before)
      .mockResolvedValueOnce(after);
    chartAccountRepository.update.mockResolvedValue(after);

    const result = await chartAccountService.updateChartAccount(
      'ca-1',
      { is_active: false },
      'user-1',
      '127.0.0.1'
    );

    expect(chartAccountRepository.update).toHaveBeenCalledWith('ca-1', { is_active: false });
    expect(result.is_active).toBe(false);
    expect(result.display_id).toBe('CA-0001');
  });

  it('returns not found for missing account', async () => {
    chartAccountRepository.findById.mockResolvedValue(null);

    await expect(chartAccountService.getChartAccountById('missing')).rejects.toMatchObject({
      statusCode: 404,
      message: 'errors.chart_account.not_found'
    });
  });
});
