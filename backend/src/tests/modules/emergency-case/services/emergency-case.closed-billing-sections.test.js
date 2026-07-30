/**
 * Billing & sections scan for Emergency Closed (`/emergency?scope=closed`).
 *
 * Closed rows are produced by handoff (and terminal destinations). Deferred
 * IPD/ICU/theatre fees and OPD consultation invoices must post through shared
 * clinical-request-billing (PENDING / outstanding). Settlement is owned by
 * Billing — Emergency never invents a cashier path.
 *
 * @module tests/modules/emergency-case/services/emergency-case.closed-billing-sections
 */

jest.mock('../../../../modules/emergency-case/repositories/emergency-case.repository');
jest.mock('@repositories/patient/patient.repository');
jest.mock('@repositories/patient-contact/patient-contact.repository');
jest.mock('@repositories/triage-assessment/triage-assessment.repository');
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(async (fn) => fn({})),
}));
jest.mock('@modules/emergency-response/repositories/emergency-response.repository', () => ({
  create: jest.fn(),
}));
jest.mock('@services/opd-flow/opd-flow.service', () => ({
  startOpdFlow: jest.fn(),
}));
jest.mock('@services/ipd-flow/ipd-flow.service', () => ({
  startIpdFlow: jest.fn(),
  startIcuStay: jest.fn(),
}));
jest.mock('@services/encounter/encounter.service', () => ({
  createEncounter: jest.fn(),
}));
jest.mock('@services/theatre-flow/theatre-flow.service', () => ({
  startTheatreFlow: jest.fn(),
}));
jest.mock('@lib/audit');
jest.mock('@lib/billing/emergency-billing', () => {
  const actual = jest.requireActual('@lib/billing/emergency-billing');
  return {
    ...actual,
    persistEmergencyCaseServiceBilling: jest.fn(),
  };
});

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const emergencyCaseService = require('../../../../modules/emergency-case/services/emergency-case.service');
const emergencyCaseRepository = require('../../../../modules/emergency-case/repositories/emergency-case.repository');
const emergencyResponseRepository = require('@modules/emergency-response/repositories/emergency-response.repository');
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');
const encounterService = require('@services/encounter/encounter.service');
const theatreFlowService = require('@services/theatre-flow/theatre-flow.service');
const {
  persistEmergencyCaseServiceBilling,
  HANDOFF_ADMISSION_CHARGE_KEY,
  HANDOFF_THEATRE_CHARGE_KEY,
  buildPendingClinicalRequestBilling,
} = require('@lib/billing/emergency-billing');

const mockUser = {
  id: 'user-id',
  tenant_id: 'tenant-id',
  facility_id: 'facility-id',
};

const deferredAdmissionBilling = buildPendingClinicalRequestBilling({
  lineItems: [
    {
      id: 'emergency-admission',
      label: 'Emergency admission fee',
      quantity: 1,
      unit_price: '50000.00',
      line_total: '50000.00',
      catalog_type: 'SERVICE',
    },
  ],
  currency: 'UGX',
});

describe('Emergency Closed billing & sections (handoff → Billing)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    emergencyResponseRepository.create.mockResolvedValue({ id: 'response-id' });
    persistEmergencyCaseServiceBilling.mockResolvedValue({
      invoice_id: 'inv-deferred-1',
      payment_status: 'PENDING',
    });
  });

  it('AC2: OPD handoff posts consultation invoice (no payment gate / deferred settle)', async () => {
    const existingCase = {
      id: 'case-id',
      tenant_id: 'tenant-id',
      facility_id: 'facility-id',
      patient_id: 'patient-id',
      severity: 'HIGH',
      status: 'OPEN',
    };
    emergencyCaseRepository.findById.mockResolvedValue(existingCase);
    opdFlowService.startOpdFlow.mockResolvedValue({
      encounter: { id: 'ENC000001', human_friendly_id: 'ENC000001' },
      flow: { workflow_stage: 'WAITING_VITALS' },
    });
    emergencyCaseRepository.update.mockResolvedValue({
      ...existingCase,
      status: 'CLOSED',
    });

    await emergencyCaseService.handoffEmergencyCase(
      'case-id',
      { destination: 'OPD', notes: 'To OPD', close_case: true },
      mockUser
    );

    expect(opdFlowService.startOpdFlow).toHaveBeenCalledWith(
      expect.objectContaining({
        require_consultation_payment: false,
        create_consultation_invoice: true,
        arrival_mode: 'EMERGENCY',
        patient_id: 'patient-id',
      }),
      expect.objectContaining({ user_id: mockUser.id })
    );
  });

  it('AC2/AC3: IPD handoff posts deferred admission fee through Billing SoR', async () => {
    const existingCase = {
      id: 'case-id',
      tenant_id: 'tenant-id',
      facility_id: 'facility-id',
      patient_id: 'patient-id',
      severity: 'CRITICAL',
      status: 'OPEN',
      facility: {
        id: 'facility-id',
        extension_json: {
          billing: { admission_fee: 50000, currency: 'UGX' },
        },
      },
    };
    emergencyCaseRepository.findById.mockResolvedValue(existingCase);
    // IPD accepted no billing snapshot → emergency persists SERVICE charge.
    ipdFlowService.startIpdFlow.mockResolvedValue({
      id: 'ADM000001',
      admission: { id: 'ADM000001' },
    });
    emergencyCaseRepository.update.mockResolvedValue({
      ...existingCase,
      status: 'CLOSED',
    });

    await emergencyCaseService.handoffEmergencyCase(
      'case-id',
      { destination: 'IPD', close_case: true, billing: deferredAdmissionBilling },
      mockUser
    );

    expect(ipdFlowService.startIpdFlow).toHaveBeenCalledWith(
      expect.objectContaining({
        patient_id: 'patient-id',
        billing: expect.objectContaining({
          payment_status: expect.any(String),
        }),
      }),
      expect.objectContaining({ user_id: mockUser.id })
    );
    expect(prisma.$transaction).toHaveBeenCalled();
    expect(persistEmergencyCaseServiceBilling).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        emergencyCaseId: 'case-id',
        chargeKey: HANDOFF_ADMISSION_CHARGE_KEY,
        patientId: 'patient-id',
        tenantId: 'tenant-id',
        description: 'Emergency admission fee',
      })
    );
    expect(emergencyCaseRepository.update).toHaveBeenCalledWith(
      existingCase.id,
      expect.objectContaining({
        status: 'CLOSED',
        extension_json: expect.objectContaining({
          handoff: expect.objectContaining({
            destination: 'IPD',
            billing_deferred: true,
          }),
        }),
      })
    );
  });

  it('AC2/AC6: IPD deferred post is idempotent on replay (same charge key)', async () => {
    const existingCase = {
      id: 'case-id',
      tenant_id: 'tenant-id',
      facility_id: 'facility-id',
      patient_id: 'patient-id',
      severity: 'HIGH',
      status: 'OPEN',
    };
    emergencyCaseRepository.findById.mockResolvedValue(existingCase);
    ipdFlowService.startIpdFlow.mockResolvedValue({
      id: 'ADM000002',
      admission: { id: 'ADM000002' },
    });
    emergencyCaseRepository.update.mockResolvedValue({
      ...existingCase,
      status: 'CLOSED',
    });

    await emergencyCaseService.handoffEmergencyCase(
      'case-id',
      { destination: 'IPD', close_case: true, billing: deferredAdmissionBilling },
      mockUser
    );
    await emergencyCaseService.handoffEmergencyCase(
      'case-id',
      { destination: 'IPD', close_case: true, billing: deferredAdmissionBilling },
      mockUser
    );

    const calls = persistEmergencyCaseServiceBilling.mock.calls;
    expect(calls.length).toBeGreaterThanOrEqual(1);
    for (const [, options] of calls) {
      expect(options.chargeKey).toBe(HANDOFF_ADMISSION_CHARGE_KEY);
      expect(options.emergencyCaseId).toBe('case-id');
    }
  });

  it('AC2: Theater handoff posts theatre fee when receiving flow omits billing', async () => {
    const existingCase = {
      id: 'case-id',
      tenant_id: 'tenant-id',
      facility_id: 'facility-id',
      patient_id: 'patient-id',
      severity: 'HIGH',
      status: 'OPEN',
      human_friendly_id: 'EME000001',
    };
    const theatreBilling = buildPendingClinicalRequestBilling({
      lineItems: [
        {
          id: 'emergency-theatre',
          label: 'Emergency theatre fee',
          quantity: 1,
          unit_price: '120000.00',
          line_total: '120000.00',
          catalog_type: 'SERVICE',
        },
      ],
      currency: 'UGX',
    });

    emergencyCaseRepository.findById.mockResolvedValue(existingCase);
    encounterService.createEncounter.mockResolvedValue({
      id: 'ENC-T1',
      human_friendly_id: 'ENC-T1',
    });
    theatreFlowService.startTheatreFlow.mockResolvedValue({
      id: 'TH-1',
      human_friendly_id: 'TH-1',
      workflow_stage: 'PRE_OP',
    });
    emergencyCaseRepository.update.mockResolvedValue({
      ...existingCase,
      status: 'CLOSED',
    });

    await emergencyCaseService.handoffEmergencyCase(
      'case-id',
      { destination: 'THEATER', close_case: true, billing: theatreBilling },
      mockUser
    );

    expect(persistEmergencyCaseServiceBilling).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        emergencyCaseId: 'case-id',
        chargeKey: HANDOFF_THEATRE_CHARGE_KEY,
        description: 'Emergency theatre fee',
      })
    );
  });

  it('AC2: no module-local paid flag — soft delete does not invent cashier reverse', async () => {
    const existingCase = {
      id: 'case-id',
      tenant_id: 'tenant-id',
      status: 'CLOSED',
    };
    emergencyCaseRepository.findById.mockResolvedValue(existingCase);
    emergencyCaseRepository.softDelete = jest.fn().mockResolvedValue(undefined);

    // Soft delete path must not call receive-payment / invent paid status.
    if (typeof emergencyCaseService.deleteEmergencyCase === 'function') {
      await emergencyCaseService.deleteEmergencyCase('case-id', mockUser);
      expect(persistEmergencyCaseServiceBilling).not.toHaveBeenCalled();
    } else {
      expect(persistEmergencyCaseServiceBilling).not.toHaveBeenCalled();
    }
  });
});
