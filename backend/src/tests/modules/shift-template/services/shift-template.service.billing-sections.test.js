jest.mock('@repositories/shift-template/shift-template.repository');
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
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));

const shiftTemplateRepository = require('@repositories/shift-template/shift-template.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const shiftTemplateService = require('@services/shift-template/shift-template.service');

/**
 * Billing & sections scan for schedule-template CRUD opened from HR Shifts.
 * Templates are reusable roster patterns — NOT_BILLED internal ops.
 */
describe('shift-template service billing-sections scan (Shifts tab)', () => {
  const template = {
    id: 'template-uuid',
    human_friendly_id: 'SHI0000001',
    name: 'Day pattern',
    shift_type: 'DAY',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    is_active: true,
    weekly_schedule_json: [
      {
        day_of_week: 1,
        time_slots: [{ start_time: '08:00', end_time: '17:00' }],
      },
    ],
  };

  const expectNoPatientBillingTouch = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  };

  beforeEach(() => {
    jest.clearAllMocks();
    shiftTemplateRepository.create.mockResolvedValue(template);
    shiftTemplateRepository.findById.mockResolvedValue(template);
    shiftTemplateRepository.update.mockResolvedValue({
      ...template,
      name: 'Day pattern updated',
    });
    shiftTemplateRepository.softDelete.mockResolvedValue(undefined);
    shiftTemplateRepository.findMany.mockResolvedValue([template]);
    shiftTemplateRepository.count.mockResolvedValue(1);
  });

  it('create shift template does not post patient Billing', async () => {
    const result = await shiftTemplateService.create(
      {
        name: 'Day pattern',
        shift_type: 'DAY',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        weekly_schedule_json: template.weekly_schedule_json,
      },
      'user-1',
      '127.0.0.1'
    );

    expect(result).toEqual(expect.objectContaining({ id: 'template-uuid' }));
    expect(shiftTemplateRepository.create).toHaveBeenCalled();
    expectNoPatientBillingTouch();
  });

  it('create is idempotent on billing bypass — replay does not double-post', async () => {
    const payload = {
      name: 'Day pattern',
      shift_type: 'DAY',
      tenant_id: 'tenant-1',
      weekly_schedule_json: template.weekly_schedule_json,
    };

    await shiftTemplateService.create(payload, 'user-1', '127.0.0.1');
    await shiftTemplateService.create(payload, 'user-1', '127.0.0.1');

    expect(shiftTemplateRepository.create).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouch();
  });

  it('update / delete shift template do not settle or adjust Billing', async () => {
    await shiftTemplateService.update(
      'SHI0000001',
      { name: 'Day pattern updated' },
      'user-1',
      '127.0.0.1'
    );
    await shiftTemplateService.remove('SHI0000001', 'user-1', '127.0.0.1');

    expect(shiftTemplateRepository.update).toHaveBeenCalled();
    expect(shiftTemplateRepository.softDelete).toHaveBeenCalled();
    expectNoPatientBillingTouch();
  });

  it('list templates serializes without local paid flags or balances', async () => {
    const data = await shiftTemplateService.listShiftTemplates({}, 1, 20);

    expect(data.items).toHaveLength(1);
    expect(data.items[0]).not.toHaveProperty('payment_status');
    expect(data.items[0]).not.toHaveProperty('balance');
    expect(data.items[0]).not.toHaveProperty('amount_due');
    expect(data.items[0]).not.toHaveProperty('invoice_id');
    expectNoPatientBillingTouch();
  });

  it('unauthorized actor without billing scopes still cannot settle via template handlers', async () => {
    await shiftTemplateService.create(
      {
        name: 'Night',
        shift_type: 'NIGHT',
        tenant_id: 'tenant-1',
        weekly_schedule_json: template.weekly_schedule_json,
      },
      'user-no-billing',
      '127.0.0.1'
    );

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
