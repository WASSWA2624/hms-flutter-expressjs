/**
 * Billing & sections scan for Emergency Handoff ready (`/emergency?scope=handoff`).
 *
 * Primary tab mutation is handoffEmergencyCase. Deferred OPD consultation,
 * IPD/ICU admission, and theatre fees must post through shared
 * clinical-request-billing / emergency-billing helpers (PENDING / outstanding).
 * Settlement is owned by Billing — Emergency never invents a cashier path.
 * Terminal referral / discharge is NOT_BILLED.
 *
 * @module tests/modules/emergency-case/services/emergency-case.handoff-billing-sections
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

const emergencyCaseService = require('../../../../modules/emergency-case/services/emergency-case.service');
const emergencyCaseRepository = require('../../../../modules/emergency-case/repositories/emergency-case.repository');
const emergencyResponseRepository = require('@modules/emergency-response/repositories/emergency-response.repository');
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');
const theatreFlowService = require('@services/theatre-flow/theatre-flow.service');
const encounterService = require('@services/encounter/encounter.service');
const { createAuditLog } = require('@lib/audit');
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

const facilityWithFees = {
  id: 'facility-id',
  extension_json: {
    billing: {
      admission_fee: 250,
      theatre_fee: 800,
      currency: 'USD',
    },
  },
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

describe('Emergency Handoff ready billing & sections (handoff → Billing)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    emergencyResponseRepository.create.mockResolvedValue({ id: 'response-id' });
    persistEmergencyCaseServiceBilling.mockResolvedValue({
      invoice_id: 'inv-deferred-1',
      payment_status: 'PENDING',
    });
  });

  it('AC2: OPD handoff posts deferred consultation invoice (no payment gate)', async () => {
    const existingCase = {
      id: 'case-id',
      tenant_id: 'tenant-id',
      facility_id: 'facility-id',
      patient_id: 'patient-id',
      severity: 'HIGH',
      status: 'OPEN',
      facility: facilityWithFees,
    };
    emergencyCaseRepository.findById.mockResolvedValue(existingCase);
    opdFlowService.startOpdFlow.mockResolvedValue({
      encounter: { id: 'ENC000001' },
      flow: {
        workflow_stage: 'WAITING_VITALS',
        consultation: {
          invoice_id: 'inv-consult-1',
          payment_status: 'PENDING',
          require_payment: false,
          billing: { invoice_id: 'inv-consult-1', payment_status: 'PENDING' },
        },
      },
    });
    emergencyCaseRepository.update.mockResolvedValue({
      ...existingCase,
      status: 'CLOSED',
    });

    await emergencyCaseService.handoffEmergencyCase(
      'case-id',
      { destination: 'OPD', notes: 'Stabilize then settle.' },
      mockUser
    );

    expect(opdFlowService.startOpdFlow).toHaveBeenCalledWith(
      expect.objectContaining({
        require_consultation_payment: false,
        create_consultation_invoice: true,
        arrival_mode: 'EMERGENCY',
      }),
      expect.any(Object)
    );
    expect(emergencyCaseRepository.update).toHaveBeenCalledWith(
      existingCase.id,
      expect.objectContaining({
        extension_json: expect.objectContaining({
          handoff: expect.objectContaining({
            billing_deferred: true,
            billing_invoice_id: 'inv-consult-1',
            billing_payment_status: 'PENDING',
          }),
        }),
      })
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
      facility: facilityWithFees,
    };
    emergencyCaseRepository.findById.mockResolvedValue(existingCase);
    ipdFlowService.startIpdFlow.mockResolvedValue({
      id: 'ADM000001',
      admission: { id: 'ADM000001' },
      flow: { stage: 'ADMITTED' },
    });
    emergencyCaseRepository.update.mockResolvedValue({
      ...existingCase,
      status: 'CLOSED',
    });

    await emergencyCaseService.handoffEmergencyCase(
      'case-id',
      { destination: 'IPD' },
      mockUser
    );

    expect(ipdFlowService.startIpdFlow).toHaveBeenCalledWith(
      expect.objectContaining({
        patient_id: 'patient-id',
        billing: expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '250.00',
        }),
      }),
      expect.any(Object)
    );
    expect(emergencyCaseRepository.update).toHaveBeenCalledWith(
      existingCase.id,
      expect.objectContaining({
        extension_json: expect.objectContaining({
          handoff: expect.objectContaining({
            billing_deferred: true,
          }),
        }),
      })
    );
  });

  it('AC2/AC6: IPD handoff falls back to persistEmergencyCaseServiceBilling (idempotent key)', async () => {
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

    expect(persistEmergencyCaseServiceBilling).toHaveBeenCalledTimes(1);
    expect(persistEmergencyCaseServiceBilling).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        chargeKey: HANDOFF_ADMISSION_CHARGE_KEY,
        emergencyCaseId: 'case-id',
      })
    );
    const [, options] = persistEmergencyCaseServiceBilling.mock.calls[0];
    expect(options.chargeKey).toBe(HANDOFF_ADMISSION_CHARGE_KEY);
    expect(options.emergencyCaseId).toBe('case-id');
  });

  it('AC2: Theater handoff posts deferred theatre billing (no double cashier)', async () => {
    const existingCase = {
      id: 'case-id',
      tenant_id: 'tenant-id',
      facility_id: 'facility-id',
      patient_id: 'patient-id',
      severity: 'HIGH',
      status: 'OPEN',
      facility: facilityWithFees,
      human_friendly_id: 'EME000001',
    };
    emergencyCaseRepository.findById.mockResolvedValue(existingCase);
    encounterService.createEncounter.mockResolvedValue({ id: 'ENC000001' });
    theatreFlowService.startTheatreFlow.mockResolvedValue({
      id: 'THR000001',
      billing: { invoice_id: 'inv-thr-1', payment_status: 'PENDING' },
    });
    emergencyCaseRepository.update.mockResolvedValue({
      ...existingCase,
      status: 'CLOSED',
    });

    await emergencyCaseService.handoffEmergencyCase(
      'case-id',
      { destination: 'THEATER' },
      mockUser
    );

    expect(theatreFlowService.startTheatreFlow).toHaveBeenCalledWith(
      expect.objectContaining({
        billing: expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '800.00',
        }),
      }),
      expect.any(Object)
    );
    expect(emergencyCaseRepository.update).toHaveBeenCalledWith(
      existingCase.id,
      expect.objectContaining({
        extension_json: expect.objectContaining({
          handoff: expect.objectContaining({
            billing_deferred: true,
            billing_payment_status: 'PENDING',
          }),
        }),
      })
    );
  });

  it('AC2: Theater handoff persists SERVICE charge when receiving flow omits billing', async () => {
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

  it('AC2: terminal referral does not invent Billing charges (NOT_BILLED)', async () => {
    const existingCase = {
      id: 'case-id',
      tenant_id: 'tenant-id',
      facility_id: 'facility-id',
      patient_id: 'patient-id',
      severity: 'MEDIUM',
      status: 'OPEN',
    };
    emergencyCaseRepository.findById.mockResolvedValue(existingCase);
    emergencyCaseRepository.update.mockImplementation(async (id, data) => ({
      ...existingCase,
      ...data,
    }));

    await emergencyCaseService.handoffEmergencyCase(
      'case-id',
      { destination: 'REFERRAL' },
      mockUser
    );

    expect(opdFlowService.startOpdFlow).not.toHaveBeenCalled();
    expect(ipdFlowService.startIpdFlow).not.toHaveBeenCalled();
    expect(persistEmergencyCaseServiceBilling).not.toHaveBeenCalled();
    expect(emergencyCaseRepository.update).toHaveBeenCalledWith(
      existingCase.id,
      expect.objectContaining({
        extension_json: expect.objectContaining({
          handoff: expect.objectContaining({
            destination: 'REFERRAL',
            terminal: true,
            billing_deferred: false,
          }),
        }),
      })
    );
  });

  it('AC2: soft delete does not invent a module cashier reverse', async () => {
    const existingCase = {
      id: 'case-id',
      tenant_id: 'tenant-id',
      status: 'CLOSED',
    };
    emergencyCaseRepository.findById.mockResolvedValue(existingCase);
    emergencyCaseRepository.softDelete.mockResolvedValue(undefined);

    await emergencyCaseService.deleteEmergencyCase('case-id', mockUser);

    expect(emergencyCaseRepository.softDelete).toHaveBeenCalledWith('case-id');
    expect(persistEmergencyCaseServiceBilling).not.toHaveBeenCalled();
  });
});
