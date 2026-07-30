const {
  computeInvoiceFinancials,
  sumBalancesDue,
} = require('@lib/billing/financials');

describe('home dashboard balance parity (Billing financials)', () => {
  it('sumBalancesDue matches ledger balance after partial payment (no total_amount bypass)', () => {
    const invoice = {
      total_amount: 1000,
      payments: [
        {
          status: 'COMPLETED',
          amount: 400,
          refunds: [],
        },
      ],
      billing_adjustments: [],
    };

    const financials = computeInvoiceFinancials(invoice);
    expect(financials.balance_due).toBe('600.00');

    // Raw total_amount would leak 1000 on home KPIs; ledger balance is 600.
    expect(sumBalancesDue([invoice])).toBe(600);
    expect(sumBalancesDue([invoice])).not.toBe(1000);
  });

  it('idempotent replay of the same invoice set does not inflate balances', () => {
    const invoices = [
      {
        total_amount: 500,
        payments: [{ status: 'COMPLETED', amount: 100, refunds: [] }],
        billing_adjustments: [],
      },
      {
        total_amount: 200,
        status: 'OVERDUE',
        payments: [],
        billing_adjustments: [],
      },
    ];

    const first = sumBalancesDue(invoices);
    const second = sumBalancesDue(invoices);
    expect(first).toBe(600);
    expect(second).toBe(first);
  });

  it('clamps overpayment credits so home KPIs do not invent negative ledgers', () => {
    const invoice = {
      total_amount: 100,
      payments: [{ status: 'COMPLETED', amount: 150, refunds: [] }],
      billing_adjustments: [],
    };
    expect(sumBalancesDue([invoice])).toBe(0);
  });
});
