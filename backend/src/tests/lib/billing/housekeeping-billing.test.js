/**
 * Unit tests for housekeeping-billing helpers (Tasks tab surcharge wiring).
 */

jest.mock('@prisma/client', () => ({
  $transaction: jest.fn((fn) => fn({})),
  facility: { findFirst: jest.fn() },
  bed_assignment: { findFirst: jest.fn() },
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));
jest.mock('@lib/billing/clinical-request-billing', () => ({
  applyClinicalRequestBilling: jest.fn(),
  buildPendingClinicalRequestBilling: jest.fn(({ lineItems, currency }) => ({
    payment_status: 'PENDING',
    total_amount: lineItems?.[0]?.line_total || '0.00',
    currency: currency || 'USD',
    line_items: lineItems,
  })),
  shouldApplyClinicalRequestBilling: jest.fn(
    (billing) =>
      Boolean(billing) &&
      billing.payment_status !== 'NOT_BILLED' &&
      billing.payment_status !== 'NOT_REQUIRED' &&
      billing.payment_status !== 'NO_CHARGE'
  ),
  BILLABLE_SOURCE_MODULES: { SERVICE: 'SERVICE' },
}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const {
  applyClinicalRequestBilling,
  shouldApplyClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');
const {
  ROOM_TURNOVER_CLEANING_CHARGE_KEY,
  PRIVATE_ROOM_CLEANING_CHARGE_KEY,
  buildHousekeepingCleaningBilling,
  persistHousekeepingTaskBilling,
  maybeBillCompletedHousekeepingTask,
} = require('@lib/billing/housekeeping-billing');

describe('housekeeping-billing', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    prisma.$transaction.mockImplementation(async (fn) => fn({}));
    createAuditLog.mockResolvedValue({});
  });

  describe('buildHousekeepingCleaningBilling', () => {
    it('returns null when no facility fee is configured', () => {
      expect(
        buildHousekeepingCleaningBilling({
          facility: { extension_json: { billing: { currency: 'USD' } } },
        })
      ).toBeNull();
    });

    it('builds PENDING turnover cleaning payload from facility fee', () => {
      const billing = buildHousekeepingCleaningBilling({
        facility: {
          extension_json: {
            billing: { room_turnover_cleaning_fee: 45, currency: 'UGX' },
          },
        },
      });
      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          currency: 'UGX',
          line_items: [
            expect.objectContaining({
              id: 'room-turnover-cleaning',
              label: 'Room turnover cleaning',
            }),
          ],
        })
      );
    });

    it('prefers private-room fee when requested', () => {
      const billing = buildHousekeepingCleaningBilling({
        preferPrivateRoom: true,
        facility: {
          extension_json: {
            billing: {
              private_room_cleaning_surcharge: 80,
              room_turnover_cleaning_fee: 45,
              currency: 'USD',
            },
          },
        },
      });
      expect(billing.line_items[0].id).toBe('private-room-cleaning');
    });
  });

  describe('persistHousekeepingTaskBilling', () => {
    it('posts via applyClinicalRequestBilling with SERVICE source', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-1',
        payment_status: 'PENDING',
      });
      const billing = {
        payment_status: 'PENDING',
        total_amount: '45.00',
        currency: 'USD',
        line_items: [],
      };
      shouldApplyClinicalRequestBilling.mockReturnValue(true);

      const snapshot = await persistHousekeepingTaskBilling(
        {},
        {
          taskId: 'task-1',
          billing,
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          patientId: 'patient-1',
        }
      );

      expect(snapshot.invoice_id).toBe('inv-1');
      expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
        {},
        expect.objectContaining({
          sourceModule: 'SERVICE',
          sourceId: 'task-1',
          chargeKey: ROOM_TURNOVER_CLEANING_CHARGE_KEY,
          patientId: 'patient-1',
        })
      );
    });

    it('returns null without patient or tenant (no bypass invent)', async () => {
      const result = await persistHousekeepingTaskBilling(
        {},
        {
          taskId: 'task-1',
          billing: { payment_status: 'PENDING' },
          tenantId: 'tenant-1',
          patientId: null,
        }
      );
      expect(result).toBeNull();
      expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
    });
  });

  describe('maybeBillCompletedHousekeepingTask', () => {
    it('audits NOT_BILLED when no fee configured', async () => {
      const snapshot = await maybeBillCompletedHousekeepingTask(
        {
          id: 'task-1',
          status: 'COMPLETED',
          facility_id: 'facility-1',
          facility: { extension_json: { billing: {} } },
        },
        { user_id: 'user-1', tenant_id: 'tenant-1' }
      );

      expect(snapshot).toBeNull();
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'HOUSEKEEPING_TASK_BILLING_SKIPPED',
          details: expect.objectContaining({ audit_code: 'NOT_BILLED' }),
        })
      );
      expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
    });

    it('posts charge when fee + patient present', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-hk',
        payment_status: 'PENDING',
      });
      shouldApplyClinicalRequestBilling.mockReturnValue(true);

      const snapshot = await maybeBillCompletedHousekeepingTask(
        {
          id: 'task-1',
          status: 'COMPLETED',
          facility_id: 'facility-1',
          room_id: 'room-1',
          facility: {
            extension_json: {
              billing: { room_turnover_cleaning_fee: 45, currency: 'USD' },
            },
          },
        },
        { user_id: 'user-1', tenant_id: 'tenant-1' },
        { patientId: 'patient-1' }
      );

      expect(snapshot).toEqual(
        expect.objectContaining({ invoice_id: 'inv-hk' })
      );
      expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
        {},
        expect.objectContaining({
          chargeKey: ROOM_TURNOVER_CLEANING_CHARGE_KEY,
          patientId: 'patient-1',
        })
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'HOUSEKEEPING_TASK_BILLED' })
      );
    });

    it('idempotent replay uses same charge key', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-hk',
        payment_status: 'PENDING',
      });
      shouldApplyClinicalRequestBilling.mockReturnValue(true);

      const task = {
        id: 'task-1',
        status: 'COMPLETED',
        facility: {
          extension_json: {
            billing: { private_room_cleaning_surcharge: 80 },
          },
        },
      };
      const context = { user_id: 'user-1', tenant_id: 'tenant-1' };

      await maybeBillCompletedHousekeepingTask(task, context, {
        patientId: 'patient-1',
        preferPrivateRoom: true,
      });
      await maybeBillCompletedHousekeepingTask(task, context, {
        patientId: 'patient-1',
        preferPrivateRoom: true,
      });

      expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(2);
      expect(applyClinicalRequestBilling.mock.calls[0][1].chargeKey).toBe(
        PRIVATE_ROOM_CLEANING_CHARGE_KEY
      );
      expect(applyClinicalRequestBilling.mock.calls[1][1].chargeKey).toBe(
        PRIVATE_ROOM_CLEANING_CHARGE_KEY
      );
      expect(applyClinicalRequestBilling.mock.calls[0][1].sourceId).toBe(
        'task-1'
      );
    });

    it('skips non-COMPLETED statuses', async () => {
      const result = await maybeBillCompletedHousekeepingTask(
        { id: 'task-1', status: 'IN_PROGRESS' },
        { tenant_id: 'tenant-1' }
      );
      expect(result).toBeNull();
      expect(createAuditLog).not.toHaveBeenCalled();
      expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
    });
  });
});
