jest.mock('@repositories/staff-leave/staff-leave.repository');
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || undefined),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value || null),
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolvePublicIdentifier: jest.fn((...values) => values.find((value) => value) || null),
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));

const staffLeaveRepository = require('@repositories/staff-leave/staff-leave.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');
const staffLeaveService = require('@services/staff-leave/staff-leave.service');

/**
 * Billing & sections scan — staff leave create path used by Leave requests
 * "Request leave" dialog. Creating staff_leave must never post patient Billing.
 */
describe('staff-leave Leave requests billing-sections scan', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  const expectNoPatientBillingTouched = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  };

  it('createStaffLeave stays NOT_BILLED (no patient ledger post)', async () => {
    const mockData = {
      staff_profile_id: '550e8400-e29b-41d4-a716-446655440000',
      leave_type: 'ANNUAL',
      status: 'REQUESTED',
      start_date: new Date('2026-07-10'),
      end_date: new Date('2026-07-12'),
    };
    const mockLeave = { id: '456', ...mockData };
    staffLeaveRepository.create.mockResolvedValue(mockLeave);

    const result = await staffLeaveService.createStaffLeave(
      mockData,
      mockUserId,
      mockIpAddress
    );

    expect(result).toEqual(mockLeave);
    expect(createAuditLog).toHaveBeenCalled();
    expectNoPatientBillingTouched();
  });

  it('createStaffLeave UNPAID type does not invent patient charges', async () => {
    const mockData = {
      staff_profile_id: '550e8400-e29b-41d4-a716-446655440000',
      leave_type: 'UNPAID',
      status: 'REQUESTED',
      start_date: new Date('2026-07-10'),
      end_date: new Date('2026-07-11'),
    };
    const mockLeave = { id: '789', ...mockData };
    staffLeaveRepository.create.mockResolvedValue(mockLeave);

    const result = await staffLeaveService.createStaffLeave(
      mockData,
      mockUserId,
      mockIpAddress
    );

    expect(result.leave_type).toBe('UNPAID');
    expect(result).not.toHaveProperty('amount');
    expect(result).not.toHaveProperty('invoice_id');
    expectNoPatientBillingTouched();
  });

  it('createStaffLeave replay does not double-post Billing', async () => {
    const mockData = {
      staff_profile_id: '550e8400-e29b-41d4-a716-446655440000',
      leave_type: 'SICK',
      status: 'REQUESTED',
      start_date: new Date('2026-07-10'),
      end_date: new Date('2026-07-10'),
    };
    staffLeaveRepository.create
      .mockResolvedValueOnce({ id: 'a', ...mockData })
      .mockResolvedValue({ id: 'b', ...mockData });

    await staffLeaveService.createStaffLeave(mockData, mockUserId, mockIpAddress);
    await staffLeaveService.createStaffLeave(mockData, mockUserId, mockIpAddress);

    expect(staffLeaveRepository.create).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouched();
  });
});
