/**
 * Auth change-password billing bypass tests (Profile tab)
 *
 * @module tests/modules/auth/billing-bypass
 * @description Password change must not post to patient Billing ledgers.
 */

jest.mock('@lib/billing/clinical-request-billing', () => ({
  persistClinicalRequestBilling: jest.fn(),
  buildPendingClinicalRequestBilling: jest.fn(),
  cancelInvoiceIfReversible: jest.fn()
}));

jest.mock('@services/billing/billing.service', () => ({
  receivePayment: jest.fn(),
  requestAdjustment: jest.fn(),
  reconcilePayment: jest.fn(),
  createInvoice: jest.fn()
}));

const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const billingService = require('@services/billing/billing.service');
const authService = require('@services/auth/auth.service');
const authRepository = require('@repositories/auth/auth.repository');
const { comparePassword, hashPassword } = require('@lib/crypto');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/auth/auth.repository');
jest.mock('@lib/crypto');
jest.mock('@lib/audit');

describe('Auth changePassword billing bypass (Profile tab)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('changePassword does not call Billing services', async () => {
    const changeData = {
      user_id: 'user-123',
      old_password: 'OldPassword123!',
      new_password: 'NewPassword123!',
      ip_address: '127.0.0.1',
      user_agent: 'Mozilla'
    };

    authRepository.findUserById.mockResolvedValue({
      id: 'user-123',
      tenant_id: 'tenant-123',
      facility_id: 'facility-123',
      password_hash: 'old-hash'
    });
    comparePassword.mockResolvedValue(true);
    hashPassword.mockResolvedValue('new-hash');
    authRepository.updateUserPassword.mockResolvedValue({});
    authRepository.revokeAllUserSessions.mockResolvedValue({ count: 1 });

    await authService.changePassword(changeData);

    expect(clinicalRequestBilling.persistClinicalRequestBilling).not.toHaveBeenCalled();
    expect(billingService.receivePayment).not.toHaveBeenCalled();
    expect(billingService.requestAdjustment).not.toHaveBeenCalled();
    expect(billingService.createInvoice).not.toHaveBeenCalled();
  });

  it('idempotent changePassword replay still does not post to Billing', async () => {
    const changeData = {
      user_id: 'user-123',
      old_password: 'OldPassword123!',
      new_password: 'NewPassword123!',
      ip_address: '127.0.0.1'
    };

    authRepository.findUserById.mockResolvedValue({
      id: 'user-123',
      tenant_id: 'tenant-123',
      password_hash: 'old-hash'
    });
    comparePassword.mockResolvedValue(true);
    hashPassword.mockResolvedValue('new-hash');
    authRepository.updateUserPassword.mockResolvedValue({});
    authRepository.revokeAllUserSessions.mockResolvedValue({ count: 1 });

    await authService.changePassword(changeData);
    await authService.changePassword(changeData);

    expect(billingService.receivePayment).not.toHaveBeenCalled();
    expect(billingService.createInvoice).not.toHaveBeenCalled();
  });
});
