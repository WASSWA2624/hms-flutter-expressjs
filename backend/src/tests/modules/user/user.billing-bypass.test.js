/**
 * Directory tab user mutation billing bypass tests
 *
 * @module tests/modules/user/billing-bypass
 * @description Access-admin Directory create user / status updates must not
 * post to patient Billing ledgers (handlers: user.service createUser / updateUser).
 */

jest.mock('@repositories/user/user.repository');
jest.mock('@lib/audit');
jest.mock('@lib/crypto');
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
  persistClinicalRequestBilling: jest.fn(),
}));
jest.mock('@services/billing/billing.service', () => ({
  receivePayment: jest.fn(),
  requestAdjustment: jest.fn(),
  reconcilePayment: jest.fn(),
  createInvoice: jest.fn(),
}));

const userService = require('@services/user/user.service');
const userRepository = require('@repositories/user/user.repository');
const { createAuditLog } = require('@lib/audit');
const { hashPassword } = require('@lib/crypto');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const billingService = require('@services/billing/billing.service');

describe('User service billing bypass (Directory tab mutations)', () => {
  const tenantId = '550e8400-e29b-41d4-a716-446655440000';
  const userId = '550e8400-e29b-41d4-a716-446655440001';

  const createPayload = {
    tenant_id: tenantId,
    position_title: 'Charge Nurse',
    email: 'newuser@example.com',
    first_name: 'New',
    last_name: 'User',
    password_hash: '$2b$10$abcdefghijklmnopqrstuvwxyz',
    status: 'ACTIVE',
  };

  const createdUser = {
    id: userId,
    ...createPayload,
    created_at: new Date(),
    updated_at: new Date(),
  };

  const beforeUser = {
    id: userId,
    tenant_id: tenantId,
    email: 'existing@example.com',
    position_title: 'Nurse',
    status: 'ACTIVE',
    profile: { first_name: 'Existing', last_name: 'User' },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    hashPassword.mockResolvedValue('$2b$10$hashedpasswordplaceholder');
    userRepository.findMany.mockResolvedValue([]);
    createAuditLog.mockResolvedValue(true);
  });

  it('createUser does not post to patient Billing ledger', async () => {
    userRepository.create.mockResolvedValue(createdUser);

    const result = await userService.createUser(
      createPayload,
      'creator-id',
      '127.0.0.1'
    );

    expect(result).toEqual(createdUser);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.persistClinicalRequestBilling).not.toHaveBeenCalled();
    expect(billingService.receivePayment).not.toHaveBeenCalled();
    expect(billingService.createInvoice).not.toHaveBeenCalled();
  });

  it('createUser idempotent replay still avoids Billing posts', async () => {
    userRepository.create.mockResolvedValue(createdUser);

    await userService.createUser(createPayload, 'creator-id', '127.0.0.1');
    await userService.createUser(createPayload, 'creator-id', '127.0.0.1');

    expect(userRepository.create).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(billingService.receivePayment).not.toHaveBeenCalled();
  });

  it('updateUser status (activate/deactivate) does not post to Billing', async () => {
    userRepository.findById.mockResolvedValue(beforeUser);
    userRepository.update.mockResolvedValue({
      ...beforeUser,
      status: 'INACTIVE',
    });

    const result = await userService.updateUser(
      userId,
      { status: 'INACTIVE' },
      'updater-id',
      '127.0.0.1'
    );

    expect(result.status).toBe('INACTIVE');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(billingService.receivePayment).not.toHaveBeenCalled();
    expect(billingService.requestAdjustment).not.toHaveBeenCalled();
  });

  it('updateUser status replay is idempotent without Billing side effects', async () => {
    userRepository.findById.mockResolvedValue(beforeUser);
    userRepository.update.mockResolvedValue({
      ...beforeUser,
      status: 'INACTIVE',
    });

    await userService.updateUser(
      userId,
      { status: 'INACTIVE' },
      'updater-id',
      '127.0.0.1'
    );
    await userService.updateUser(
      userId,
      { status: 'INACTIVE' },
      'updater-id',
      '127.0.0.1'
    );

    expect(userRepository.update).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(billingService.receivePayment).not.toHaveBeenCalled();
  });
});
