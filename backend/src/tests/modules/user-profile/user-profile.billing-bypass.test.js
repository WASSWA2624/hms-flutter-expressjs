/**
 * Profile tab billing bypass tests
 *
 * @module tests/modules/user-profile/billing-bypass
 * @description Profile mutations must not post to patient Billing ledgers.
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
const userProfileService = require('@services/user-profile/user-profile.service');
const userProfileRepository = require('@repositories/user-profile/user-profile.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/user-profile/user-profile.repository');
jest.mock('@lib/audit');

describe('User profile billing bypass (Profile tab)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('updateUserProfile does not call Billing services', async () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const before = { id: profileId, first_name: 'Alex', last_name: 'Demo' };
    const after = { id: profileId, first_name: 'Jordan', last_name: 'Demo' };

    userProfileRepository.findById.mockResolvedValue(before);
    userProfileRepository.update.mockResolvedValue(after);

    const result = await userProfileService.updateUserProfile(
      profileId,
      { first_name: 'Jordan' },
      'user-id',
      '127.0.0.1'
    );

    expect(result).toEqual(after);
    expect(clinicalRequestBilling.persistClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.buildPendingClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.cancelInvoiceIfReversible).not.toHaveBeenCalled();
    expect(billingService.receivePayment).not.toHaveBeenCalled();
    expect(billingService.requestAdjustment).not.toHaveBeenCalled();
    expect(billingService.reconcilePayment).not.toHaveBeenCalled();
    expect(billingService.createInvoice).not.toHaveBeenCalled();
  });

  it('getUserProfileById does not call Billing services', async () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const profile = { id: profileId, first_name: 'Alex', last_name: 'Demo' };
    userProfileRepository.findById.mockResolvedValue(profile);

    const result = await userProfileService.getUserProfileById(
      profileId,
      'user-id',
      '127.0.0.1'
    );

    expect(result).toEqual(profile);
    expect(clinicalRequestBilling.persistClinicalRequestBilling).not.toHaveBeenCalled();
    expect(billingService.receivePayment).not.toHaveBeenCalled();
    expect(billingService.createInvoice).not.toHaveBeenCalled();
  });

  it('updateUserProfile is idempotent on replay — still no Billing posts', async () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const before = { id: profileId, first_name: 'Alex', last_name: 'Demo' };
    const after = { id: profileId, first_name: 'Jordan', last_name: 'Demo' };

    userProfileRepository.findById.mockResolvedValue(before);
    userProfileRepository.update.mockResolvedValue(after);

    await userProfileService.updateUserProfile(
      profileId,
      { first_name: 'Jordan' },
      'user-id',
      '127.0.0.1'
    );
    await userProfileService.updateUserProfile(
      profileId,
      { first_name: 'Jordan' },
      'user-id',
      '127.0.0.1'
    );

    expect(userProfileRepository.update).toHaveBeenCalledTimes(2);
    expect(billingService.receivePayment).not.toHaveBeenCalled();
    expect(billingService.createInvoice).not.toHaveBeenCalled();
  });
});
