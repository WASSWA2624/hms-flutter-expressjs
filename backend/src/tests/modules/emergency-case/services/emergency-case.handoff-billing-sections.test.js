/**
 * Emergency All tab — handoff billing sections (posts deferred Billing records).
 *
 * @module tests/modules/emergency-case/services/emergency-case.handoff-billing-sections
 */

jest.mock('../../../../modules/emergency-case/repositories/emergency-case.repository');
jest.mock('@repositories/patient/patient.repository');
jest.mock('@repositories/patient-contact/patient-contact.repository');
jest.mock('@repositories/triage-assessment/triage-assessment.repository');
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn((fn) => fn({})),
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

describe('Emergency case handoff billing sections (All tab)', () => {
  const mockUser = { id: 'user-id', tenant_id: 'tenant-id' };
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

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    emergencyResponseRepository.create.mockResolvedValue({ id: 'response-id' });
  });

  it('OPD handoff creates deferred consultation invoice (no payment gate)', async () => {
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

  it('IPD handoff passes deferred admission billing into startIpdFlow', async () => {
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

  it('Theater handoff passes deferred theatre billing (no double cashier)', async () => {
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
          }),
        }),
      })
    );
  });

  it('terminal referral does not invent Billing charges', async () => {
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
});
