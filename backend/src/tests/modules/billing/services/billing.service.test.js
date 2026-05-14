jest.mock('@repositories/billing/billing.repository', () => ({
  createApproval: jest.fn(),
  findApprovalById: jest.fn(),
}));

jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: jest.fn(() => true),
}));

jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelRecordByIdentifier: jest.fn(),
}));

jest.mock('@lib/notifications/sendEmail', () => ({
  sendEmail: jest.fn(async () => ({ sent: true, provider: 'smtp' })),
}));

jest.mock('@lib/billing/pdf', () => ({
  generateInvoicePdfBuffer: jest.fn(async () => Buffer.from('pdf')),
}));

jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(async () => {}),
}));

const billingRepository = require('@repositories/billing/billing.repository');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const billingService = require('@services/billing/billing.service');

describe('billing.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('requestAdjustment', () => {
    it('creates approval for major adjustment threshold', async () => {
      resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
        if (model === 'invoice') {
          return {
            id: 'inv-1',
            human_friendly_id: 'INV0001',
            tenant_id: 'tenant-1',
            facility_id: 'facility-1',
            status: 'SENT',
            billing_status: 'ISSUED',
            total_amount: '100.00',
          };
        }
        return null;
      });

      billingRepository.createApproval.mockResolvedValue({
        id: 'app-1',
        human_friendly_id: 'APP0001',
        status: 'PENDING',
        approval_type: 'ADJUSTMENT',
      });
      billingRepository.findApprovalById.mockResolvedValue({
        id: 'app-1',
        human_friendly_id: 'APP0001',
        status: 'PENDING',
        approval_type: 'ADJUSTMENT',
      });

      const result = await billingService.requestAdjustment(
        {
          invoice_id: 'INV0001',
          amount: '60.00',
          reason: 'Manual correction',
        },
        { id: 'user-1', tenant_id: 'tenant-1', facility_id: 'facility-1' },
        '127.0.0.1'
      );

      expect(result.approval_required).toBe(true);
      expect(billingRepository.createApproval).toHaveBeenCalledTimes(1);
    });
  });

  describe('approveApproval', () => {
    it('enforces separation of duties', async () => {
      resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
        if (model === 'billing_approval') {
          return {
            id: 'app-1',
            tenant_id: 'tenant-1',
            status: 'PENDING',
            requested_by_user_id: 'user-1',
            approval_type: 'REFUND',
            target_entity_id: 'pay-1',
          };
        }
        return null;
      });

      await expect(
        billingService.approveApproval(
          'APP0001',
          {},
          { id: 'user-1', tenant_id: 'tenant-1', facility_id: 'facility-1' },
          '127.0.0.1'
        )
      ).rejects.toMatchObject({
        messageKey: 'errors.billing_approval.separation_of_duties',
        statusCode: 400,
      });
    });
  });
});
