/**
 * Claim remittance → Billing ledger tests (Claims pending tab).
 *
 * @module tests/lib/billing/claim-remittance
 */

jest.mock('@lib/billing/realtime', () => ({
  publishBillingRealtimeUpdate: jest.fn(async () => {}),
}));

jest.mock('@lib/websocket', () => ({
  BILLING_EVENTS: {
    BILLING_PAYMENT_RECEIVED: 'billing.payment_received',
    INVOICE_UPDATED: 'invoice.updated',
    BILLING_BALANCE_UPDATED: 'billing.balance_updated',
  },
  PAYMENT_EVENTS: {
    PAYMENT_RECONCILED: 'payment.reconciled',
  },
}));

const mockTransaction = jest.fn();
const mockPaymentFindFirst = jest.fn();
const mockPaymentCreate = jest.fn();
const mockInvoiceFindFirst = jest.fn();

jest.mock('@prisma/client', () => ({
  $transaction: (...args) => mockTransaction(...args),
  payment: {
    findFirst: (...args) => mockPaymentFindFirst(...args),
  },
  invoice: {
    findFirst: (...args) => mockInvoiceFindFirst(...args),
  },
}));

jest.mock('@lib/billing/financials', () => ({
  toDecimalNumber: (value) => Number(value || 0),
  toMoneyString: (value) => Number(value || 0).toFixed(2),
  roundMoney: (value) => Math.round(Number(value || 0) * 100) / 100,
  recalculateInvoiceStateTx: jest.fn(async (_tx, invoiceId) => ({
    invoice: {
      id: invoiceId,
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1',
      billing_status: 'PARTIAL',
      status: 'SENT',
      total_amount: '200.00',
    },
    financials: {
      invoice_total: '200.00',
      balance_due: '50.00',
      net_paid_total: '150.00',
      effective_total: '200.00',
      gross_paid_total: '150.00',
    },
  })),
}));

const { HttpError } = require('@lib/errors');
const { publishBillingRealtimeUpdate } = require('@lib/billing/realtime');
const { recalculateInvoiceStateTx } = require('@lib/billing/financials');
const {
  remittanceTransactionRef,
  resolveRemittanceAmount,
  applyClaimRemittanceTx,
  applyClaimRemittance,
} = require('@lib/billing/claim-remittance');

describe('claim-remittance (Claims pending)', () => {
  const claim = {
    id: 'claim-1',
    invoice_id: 'inv-1',
    claim_amount: '150.00',
    settlement_amount: null,
    invoice: {
      id: 'inv-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1',
      total_amount: '200.00',
      items: [{ insurer_share: '150.00', patient_share: '50.00' }],
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    mockTransaction.mockImplementation(async (fn) =>
      fn({
        invoice: { findFirst: mockInvoiceFindFirst },
        payment: {
          findFirst: mockPaymentFindFirst,
          create: mockPaymentCreate,
        },
      })
    );
    mockInvoiceFindFirst.mockResolvedValue({
      id: 'inv-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1',
      total_amount: '200.00',
      items: [{ insurer_share: '150.00', patient_share: '50.00' }],
      patient: { id: 'patient-1', human_friendly_id: 'PT-1' },
    });
  });

  test('resolveRemittanceAmount posts for PAID using claim_amount default', () => {
    expect(
      resolveRemittanceAmount({
        status: 'PAID',
        settlementAmount: undefined,
        claim,
        invoice: claim.invoice,
      })
    ).toBe(150);
  });

  test('resolveRemittanceAmount requires amount for PARTIAL', () => {
    expect(() =>
      resolveRemittanceAmount({
        status: 'PARTIAL',
        settlementAmount: undefined,
        claim,
        invoice: claim.invoice,
      })
    ).toThrow(HttpError);
  });

  test('resolveRemittanceAmount skips APPROVED/REJECTED (no payment)', () => {
    expect(
      resolveRemittanceAmount({
        status: 'APPROVED',
        settlementAmount: 100,
        claim,
        invoice: claim.invoice,
      })
    ).toBeNull();
    expect(
      resolveRemittanceAmount({
        status: 'REJECTED',
        settlementAmount: 100,
        claim,
        invoice: claim.invoice,
      })
    ).toBeNull();
  });

  test('applyClaimRemittanceTx creates INSURANCE payment and recalculates invoice', async () => {
    mockPaymentFindFirst.mockResolvedValue(null);
    mockPaymentCreate.mockResolvedValue({
      id: 'pay-1',
      invoice_id: 'inv-1',
      method: 'INSURANCE',
      status: 'COMPLETED',
      amount: '150.00',
      transaction_ref: remittanceTransactionRef('claim-1'),
    });

    const result = await applyClaimRemittanceTx(
      {
        invoice: { findFirst: mockInvoiceFindFirst },
        payment: {
          findFirst: mockPaymentFindFirst,
          create: mockPaymentCreate,
        },
      },
      { claim, status: 'PAID', settlementAmount: 150 }
    );

    expect(mockPaymentCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          method: 'INSURANCE',
          status: 'COMPLETED',
          amount: '150.00',
          transaction_ref: remittanceTransactionRef('claim-1'),
          invoice_id: 'inv-1',
        }),
      })
    );
    expect(recalculateInvoiceStateTx).toHaveBeenCalled();
    expect(result.created).toBe(true);
    expect(result.payment.id).toBe('pay-1');
    expect(result.invoiceState.financials.balance_due).toBe('50.00');
  });

  test('applyClaimRemittanceTx is idempotent on replay (no double charge)', async () => {
    mockPaymentFindFirst.mockResolvedValue({
      id: 'pay-existing',
      invoice_id: 'inv-1',
      method: 'INSURANCE',
      status: 'COMPLETED',
      amount: '150.00',
      transaction_ref: remittanceTransactionRef('claim-1'),
    });

    const result = await applyClaimRemittanceTx(
      {
        invoice: { findFirst: mockInvoiceFindFirst },
        payment: {
          findFirst: mockPaymentFindFirst,
          create: mockPaymentCreate,
        },
      },
      { claim, status: 'PAID', settlementAmount: 150 }
    );

    expect(mockPaymentCreate).not.toHaveBeenCalled();
    expect(result.created).toBe(false);
    expect(result.payment.id).toBe('pay-existing');
  });

  test('applyClaimRemittance publishes Billing realtime after payment', async () => {
    mockPaymentFindFirst.mockResolvedValue(null);
    mockPaymentCreate.mockResolvedValue({
      id: 'pay-1',
      invoice_id: 'inv-1',
      method: 'INSURANCE',
      status: 'COMPLETED',
      amount: '150.00',
      transaction_ref: remittanceTransactionRef('claim-1'),
    });

    const result = await applyClaimRemittance({
      claim,
      status: 'PAID',
      settlementAmount: 150,
      actorUserId: 'user-1',
    });

    expect(result.created).toBe(true);
    expect(publishBillingRealtimeUpdate).toHaveBeenCalled();
    expect(result.financials.balance_due).toBe('50.00');
  });

  test('unauthorized-path: APPROVED does not create payment (no bypass cashier)', async () => {
    const result = await applyClaimRemittanceTx(
      {
        invoice: { findFirst: mockInvoiceFindFirst },
        payment: {
          findFirst: mockPaymentFindFirst,
          create: mockPaymentCreate,
        },
      },
      { claim, status: 'APPROVED', settlementAmount: 150 }
    );

    expect(mockPaymentCreate).not.toHaveBeenCalled();
    expect(result.skipped).toBe(true);
    expect(result.payment).toBeNull();
  });
});
