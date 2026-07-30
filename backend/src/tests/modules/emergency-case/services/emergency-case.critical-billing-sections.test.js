/**
 * Emergency Critical tab — handoff billing sections.
 *
 * Critical acuity cases (`severity: CRITICAL`) must still post deferred
 * Billing records on handoff; settlement stays on Billing (no module cashier).
 *
 * @module tests/modules/emergency-case/services/emergency-case.critical-billing-sections
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

describe('Emergency case critical-billing-sections (Critical tab)', () => {
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

  const criticalCase = {
    id: 'case-crit-id',
    tenant_id: 'tenant-id',
    facility_id: 'facility-id',
    patient_id: 'patient-id',
    severity: 'CRITICAL',
    status: 'OPEN',
    facility: facilityWithFees,
    human_friendly_id: 'EMECRIT001',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    emergencyResponseRepository.create.mockResolvedValue({ id: 'response-id' });
  });

  it('Critical OPD handoff creates deferred consultation invoice (no payment gate)', async () => {
    emergencyCaseRepository.findById.mockResolvedValue(criticalCase);
    opdFlowService.startOpdFlow.mockResolvedValue({
      encounter: { id: 'ENC-CRIT-1' },
      flow: {
        workflow_stage: 'WAITING_VITALS',
        consultation: {
          invoice_id: 'inv-crit-consult',
          payment_status: 'PENDING',
          require_payment: false,
          billing: {
            invoice_id: 'inv-crit-consult',
            payment_status: 'PENDING',
          },
        },
      },
    });
    emergencyCaseRepository.update.mockResolvedValue({
      ...criticalCase,
      status: 'CLOSED',
    });

    await emergencyCaseService.handoffEmergencyCase(
      'case-crit-id',
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
      criticalCase.id,
      expect.objectContaining({
        extension_json: expect.objectContaining({
          handoff: expect.objectContaining({
            billing_deferred: true,
            billing_invoice_id: 'inv-crit-consult',
            billing_payment_status: 'PENDING',
          }),
        }),
      })
    );
  });

  it('Critical IPD handoff posts deferred admission billing (parity PENDING)', async () => {
    emergencyCaseRepository.findById.mockResolvedValue(criticalCase);
    ipdFlowService.startIpdFlow.mockResolvedValue({
      id: 'ADM-CRIT-1',
      admission: { id: 'ADM-CRIT-1' },
      flow: { stage: 'ADMITTED' },
    });
    emergencyCaseRepository.update.mockResolvedValue({
      ...criticalCase,
      status: 'CLOSED',
    });

    await emergencyCaseService.handoffEmergencyCase(
      'case-crit-id',
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
      criticalCase.id,
      expect.objectContaining({
        extension_json: expect.objectContaining({
          handoff: expect.objectContaining({
            billing_deferred: true,
          }),
        }),
      })
    );
  });

  it('Critical Theater handoff posts deferred theatre billing (no double cashier)', async () => {
    emergencyCaseRepository.findById.mockResolvedValue(criticalCase);
    encounterService.createEncounter.mockResolvedValue({ id: 'ENC-CRIT-THR' });
    theatreFlowService.startTheatreFlow.mockResolvedValue({
      id: 'THR-CRIT-1',
      billing: { invoice_id: 'inv-thr-crit', payment_status: 'PENDING' },
    });
    emergencyCaseRepository.update.mockResolvedValue({
      ...criticalCase,
      status: 'CLOSED',
    });

    await emergencyCaseService.handoffEmergencyCase(
      'case-crit-id',
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
  });

  it('Critical terminal discharge does not invent Billing charges (NOT_BILLED)', async () => {
    emergencyCaseRepository.findById.mockResolvedValue(criticalCase);
    emergencyCaseRepository.update.mockImplementation(async (id, data) => ({
      ...criticalCase,
      ...data,
    }));

    await emergencyCaseService.handoffEmergencyCase(
      'case-crit-id',
      { destination: 'DISCHARGE' },
      mockUser
    );

    expect(opdFlowService.startOpdFlow).not.toHaveBeenCalled();
    expect(ipdFlowService.startIpdFlow).not.toHaveBeenCalled();
    expect(theatreFlowService.startTheatreFlow).not.toHaveBeenCalled();
    expect(emergencyCaseRepository.update).toHaveBeenCalledWith(
      criticalCase.id,
      expect.objectContaining({
        extension_json: expect.objectContaining({
          handoff: expect.objectContaining({
            destination: 'DISCHARGE',
            terminal: true,
            billing_deferred: false,
          }),
        }),
      })
    );
  });
});
