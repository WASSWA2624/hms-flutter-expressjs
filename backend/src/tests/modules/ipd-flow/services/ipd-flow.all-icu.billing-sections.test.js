/**
 * ICU All tab billing-sections scan (`/icu?section=all`).
 *
 * Unfiltered board reuses the same IPD ICU actions as Active. Proves
 * start-icu-stay → persistIcuStayBilling (explicit + facility fee),
 * no parallel cash ledger, idempotent ICU_STAY_START charge key, and
 * unauthorized settlement remains on Billing (not invented here).
 *
 * @module tests/modules/ipd-flow/services/ipd-flow.all-icu.billing-sections
 */

jest.mock('@repositories/ipd-flow/ipd-flow.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  IPD_EVENTS: { IPD_FLOW_UPDATED: 'ipd.flow.updated' },
  ADMISSION_BED_EVENTS: {
    PATIENT_ADMITTED: 'admission.patient_admitted',
    PATIENT_TRANSFERRED: 'admission.patient_transferred',
    PATIENT_DISCHARGED: 'admission.patient_discharged',
    BED_ASSIGNMENT_CHANGED: 'admission.bed_assignment_changed',
  },
  NOTIFICATION_EVENTS: { NOTIFICATION_CREATED: 'notification.created' },
}));

const mockPersistIcuStayBilling = jest.fn().mockResolvedValue({
  invoice_id: 'inv-all-icu-1',
  payment_status: 'PENDING',
  total_amount: '200000.00',
});
const mockPersistWardRoundBilling = jest.fn().mockResolvedValue({
  invoice_id: 'inv-all-round-1',
  payment_status: 'PENDING',
  total_amount: '40000.00',
});

jest.mock('@lib/billing/clinical-request-billing', () => ({
  persistIcuStayBilling: (...args) => mockPersistIcuStayBilling(...args),
  persistWardRoundBilling: (...args) => mockPersistWardRoundBilling(...args),
  persistAdmissionBilling: jest.fn(),
  persistNursingServiceBilling: jest.fn(),
  mapClinicalOrderBillingFields: jest.fn((value) => value),
  BILLABLE_SOURCE_MODULES: {
    ICU_STAY: 'ICU_STAY',
    WARD_ROUND: 'WARD_ROUND',
  },
}));

const mockBuildIcuStayBilling = jest.fn(({ billing }) => billing || null);
jest.mock('@lib/billing/icu-billing', () => ({
  buildIcuStayBilling: (...args) => mockBuildIcuStayBilling(...args),
  ICU_STAY_START_CHARGE_KEY: 'ICU_STAY_START',
}));

jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  admission: {
    findFirst: jest.fn(),
    update: jest.fn(),
  },
  ward_round: {
    create: jest.fn(),
  },
  icu_stay: {
    create: jest.fn(),
    update: jest.fn(),
  },
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() },
}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');

const now = new Date('2026-07-30T10:00:00.000Z');

const billingPayload = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: '200000.00',
  line_items: [
    {
      id: 'ICU_CRITICAL_CARE_PACKAGE',
      label: 'ICU critical-care package',
      quantity: 1,
      unit_price: '150000.00',
      line_total: '150000.00',
    },
    {
      id: 'ICU_BED_DAY',
      label: 'ICU bed/day',
      quantity: 1,
      unit_price: '50000.00',
      line_total: '50000.00',
    },
  ],
};

const facilityBilling = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: '75000.00',
  line_items: [
    {
      id: 'icu-critical-care-package',
      label: 'ICU critical-care package',
      quantity: 1,
      unit_price: '75000.00',
      line_total: '75000.00',
      catalog_type: 'SERVICE',
    },
  ],
};

const buildAdmission = (overrides = {}) => ({
  id: 'adm-all-1',
  human_friendly_id: 'ADM-ALL-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-all-1',
  encounter_id: 'enc-all-1',
  status: 'ADMITTED',
  admitted_at: now,
  discharged_at: null,
  created_at: now,
  updated_at: now,
  bed_assignments: [],
  transfer_requests: [],
  discharge_summaries: [],
  icu_stays: [],
  ward_rounds: [],
  nursing_notes: [],
  medication_administrations: [],
  ...overrides,
});

describe('ipd-flow ICU All billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.user_role.findMany.mockResolvedValue([]);
    prisma.notification.create.mockResolvedValue({ id: 'n-all-1' });
    mockBuildIcuStayBilling.mockImplementation(({ billing }) => billing || null);
  });

  it('AC2: startIcuStay with billing posts via persistIcuStayBilling (no bypass)', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-all-1' })
          .mockResolvedValueOnce(buildAdmission({ icu_stays: [] })),
      },
      facility: { findFirst: jest.fn().mockResolvedValue(null) },
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-all-1' }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-all-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-all-1',
            human_friendly_id: 'ICU-ALL-1',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: [],
          },
        ],
      })
    );

    await ipdFlowService.startIcuStay(
      'ADM-ALL-1',
      { billing: billingPayload },
      { tenant_id: 'tenant-1', user_id: 'user-all-1' }
    );

    expect(mockBuildIcuStayBilling).toHaveBeenCalledWith(
      expect.objectContaining({ billing: billingPayload })
    );
    expect(mockPersistIcuStayBilling).toHaveBeenCalledTimes(1);
    expect(mockPersistIcuStayBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        icuStayId: 'icu-all-1',
        billing: billingPayload,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-all-1',
        chargeKey: 'ICU_STAY_START',
        actorUserId: 'user-all-1',
      })
    );
  });

  it('AC2: facility fee path posts when request omits billing', async () => {
    mockBuildIcuStayBilling.mockReturnValue(facilityBilling);

    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-all-1' })
          .mockResolvedValueOnce(buildAdmission({ icu_stays: [] })),
      },
      facility: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'facility-1',
          extension_json: {
            billing: { icu_critical_care_package_fee: 75000, currency: 'UGX' },
          },
        }),
      },
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-all-fee' }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-all-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-all-fee',
            human_friendly_id: 'ICU-ALL-FEE',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: [],
          },
        ],
      })
    );

    await ipdFlowService.startIcuStay(
      'ADM-ALL-1',
      {},
      { tenant_id: 'tenant-1' }
    );

    expect(mockPersistIcuStayBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        icuStayId: 'icu-all-fee',
        billing: facilityBilling,
        chargeKey: 'ICU_STAY_START',
      })
    );
  });

  it('AC2: no fee and no billing → no parallel cash ledger', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-all-1' })
          .mockResolvedValueOnce(buildAdmission({ icu_stays: [] })),
      },
      facility: { findFirst: jest.fn().mockResolvedValue(null) },
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-all-none' }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-all-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-all-none',
            human_friendly_id: 'ICU-ALL-NONE',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: [],
          },
        ],
      })
    );

    await ipdFlowService.startIcuStay(
      'ADM-ALL-1',
      {},
      { tenant_id: 'tenant-1' }
    );

    expect(mockPersistIcuStayBilling).not.toHaveBeenCalled();
  });

  it('AC6: idempotent ICU_STAY_START charge key on persist helper', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-all-1' })
          .mockResolvedValueOnce(buildAdmission({ icu_stays: [] })),
      },
      facility: { findFirst: jest.fn().mockResolvedValue(null) },
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-all-idem' }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-all-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-all-idem',
            human_friendly_id: 'ICU-ALL-IDEM',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: [],
          },
        ],
      })
    );

    await ipdFlowService.startIcuStay(
      'ADM-ALL-1',
      { billing: billingPayload },
      { tenant_id: 'tenant-1' }
    );

    expect(mockPersistIcuStayBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        chargeKey: 'ICU_STAY_START',
        icuStayId: 'icu-all-idem',
      })
    );
  });

  it('AC2: intensivist round on All board posts via persistWardRoundBilling', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-all-1' })
          .mockResolvedValueOnce(buildAdmission()),
      },
      ward_round: {
        create: jest.fn().mockResolvedValue({ id: 'round-all-1' }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-all-1' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    const roundBilling = {
      payment_status: 'PENDING',
      currency: 'UGX',
      total_amount: '40000.00',
      line_items: [
        {
          id: 'WARD_ROUND_FEE',
          label: 'ICU intensivist review fee',
          quantity: 1,
          unit_price: '40000.00',
          line_total: '40000.00',
        },
      ],
    };

    await ipdFlowService.addWardRound(
      'ADM-ALL-1',
      { notes: 'All-board round', billing: roundBilling },
      { tenant_id: 'tenant-1' }
    );

    expect(mockPersistWardRoundBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        wardRoundId: 'round-all-1',
        billing: roundBilling,
        patientId: 'patient-all-1',
      })
    );
  });
});
