/**
 * ICU Critical alerts tab — billing-sections scan.
 *
 * Critical alert queue (`severity` / has_critical_alert). Acknowledge is
 * NOT_BILLED. Stay-start package / bed-day posts through icu-billing +
 * persistIcuStayBilling (idempotent ICU_STAY). No module cashier.
 *
 * @module tests/modules/ipd-flow/services/ipd-flow.icu-critical-billing-sections
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
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  admission: { findFirst: jest.fn(), update: jest.fn(), create: jest.fn() },
  facility: { findFirst: jest.fn() },
  tenant: { findFirst: jest.fn() },
  patient: { findFirst: jest.fn() },
  encounter: { findFirst: jest.fn() },
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() },
  follow_up: { create: jest.fn() },
  icu_stay: { create: jest.fn(), update: jest.fn(), findFirst: jest.fn() },
  critical_alert: { create: jest.fn(), update: jest.fn(), findFirst: jest.fn() },
}));
jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    persistIcuStayBilling: jest.fn().mockResolvedValue({
      payment_status: 'PENDING',
      invoice_id: 'inv-icu-crit-1',
    }),
    persistWardRoundBilling: jest.fn().mockResolvedValue({
      payment_status: 'PENDING',
      invoice_id: 'inv-round-1',
    }),
  };
});

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const {
  persistIcuStayBilling,
} = require('@lib/billing/clinical-request-billing');
const {
  buildIcuStayBilling,
  ICU_STAY_START_CHARGE_KEY,
} = require('@lib/billing/icu-billing');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');

const now = new Date('2026-07-30T08:00:00.000Z');

const facilityWithIcuFees = {
  id: 'facility-1',
  extension_json: {
    billing: {
      critical_care_package_fee: 500,
      icu_bed_day_fee: 150,
      currency: 'USD',
    },
  },
};

const buildAdmission = (overrides = {}) => ({
  id: 'adm-crit-1',
  human_friendly_id: 'ADMCRIT1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-1',
  encounter_id: 'enc-1',
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

describe('IPD ICU Critical billing-sections (Critical alerts tab)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-crit-1' });
  });

  describe('buildIcuStayBilling (reuse / no bypass)', () => {
    it('builds PENDING package + bed-day from facility fees', () => {
      const billing = buildIcuStayBilling({ facility: facilityWithIcuFees });
      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          currency: 'USD',
        })
      );
      expect(billing.line_items).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ id: 'icu-critical-care-package' }),
          expect.objectContaining({ id: 'icu-bed-day' }),
        ])
      );
    });

    it('returns null when no fee and no caller billing (NOT_REQUIRED)', () => {
      expect(buildIcuStayBilling({})).toBeNull();
      expect(
        buildIcuStayBilling({
          facility: { extension_json: { billing: {} } },
        })
      ).toBeNull();
    });

    it('prefers explicit caller billing over facility defaults', () => {
      const billing = buildIcuStayBilling({
        facility: facilityWithIcuFees,
        billing: {
          payment_status: 'PENDING',
          currency: 'UGX',
          total_amount: '90.00',
          line_items: [
            {
              id: 'custom',
              label: 'Custom ICU package',
              quantity: 1,
              unit_price: '90.00',
              line_total: '90.00',
            },
          ],
        },
      });
      expect(billing.currency).toBe('UGX');
      expect(billing.line_items[0].id).toBe('custom');
    });
  });

  it('start ICU stay posts Billing via persistIcuStayBilling (facility fee)', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-crit-1' })
          .mockResolvedValueOnce(buildAdmission()),
      },
      facility: {
        findFirst: jest.fn().mockResolvedValue(facilityWithIcuFees),
      },
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-crit-1' }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-crit-1',
            human_friendly_id: 'ICUCRIT1',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: [],
          },
        ],
      })
    );

    await ipdFlowService.startIcuStay(
      'ADMCRIT1',
      {},
      { tenant_id: 'tenant-1', user_id: 'user-1' }
    );

    expect(persistIcuStayBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        icuStayId: 'icu-crit-1',
        patientId: 'patient-1',
        tenantId: 'tenant-1',
        chargeKey: ICU_STAY_START_CHARGE_KEY,
        billing: expect.objectContaining({ payment_status: 'PENDING' }),
      })
    );
  });

  it('start ICU stay with explicit billing posts once (no dual ledger)', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-crit-1' })
          .mockResolvedValueOnce(buildAdmission()),
      },
      facility: {
        findFirst: jest.fn().mockResolvedValue(facilityWithIcuFees),
      },
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-crit-2' }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-crit-2',
            human_friendly_id: 'ICUCRIT2',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: [],
          },
        ],
      })
    );

    const explicitBilling = {
      payment_status: 'PENDING',
      currency: 'USD',
      total_amount: '200.00',
      line_items: [
        {
          id: 'ICU_CRITICAL_CARE_PACKAGE',
          label: 'ICU critical-care package',
          quantity: 1,
          unit_price: '200.00',
          line_total: '200.00',
        },
      ],
    };

    await ipdFlowService.startIcuStay(
      'ADMCRIT1',
      { billing: explicitBilling },
      { tenant_id: 'tenant-1' }
    );

    expect(persistIcuStayBilling).toHaveBeenCalledTimes(1);
    expect(persistIcuStayBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        icuStayId: 'icu-crit-2',
        billing: expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '200.00',
        }),
      })
    );
  });

  it('start ICU stay without fees does not invent Billing charges', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-crit-1' })
          .mockResolvedValueOnce(buildAdmission()),
      },
      facility: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'facility-1',
          extension_json: { billing: {} },
        }),
      },
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-crit-3' }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-crit-3',
            human_friendly_id: 'ICUCRIT3',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: [],
          },
        ],
      })
    );

    await ipdFlowService.startIcuStay('ADMCRIT1', {}, { tenant_id: 'tenant-1' });

    expect(persistIcuStayBilling).not.toHaveBeenCalled();
  });

  it('resolve critical alert does not call Billing (NOT_BILLED)', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-crit-1' })
          .mockResolvedValueOnce(
            buildAdmission({
              icu_stays: [
                {
                  id: 'icu-1',
                  human_friendly_id: 'ICU0001',
                  started_at: now,
                  ended_at: null,
                  observations: [],
                  alerts: [
                    {
                      id: 'alert-1',
                      human_friendly_id: 'CAL0001',
                      severity: 'CRITICAL',
                      message: 'Hypotension',
                      created_at: now,
                      deleted_at: null,
                    },
                  ],
                },
              ],
            })
          ),
      },
      critical_alert: {
        update: jest.fn().mockResolvedValue({ id: 'alert-1' }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-1',
            human_friendly_id: 'ICU0001',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: [],
          },
        ],
      })
    );

    // Empty body resolves the latest open alert on the active stay.
    await ipdFlowService.resolveCriticalAlert(
      'ADMCRIT1',
      {},
      { tenant_id: 'tenant-1' }
    );

    expect(tx.critical_alert.update).toHaveBeenCalled();
    expect(persistIcuStayBilling).not.toHaveBeenCalled();
  });

  it('idempotent charge key is ICU_STAY_START for Critical stay package', () => {
    expect(ICU_STAY_START_CHARGE_KEY).toBe('ICU_STAY_START');
  });
});
