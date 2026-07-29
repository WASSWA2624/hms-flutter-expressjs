const { ROLE_PACKS, metricsToRoleSummary } = require('@lib/dashboard/summary');

describe('home dashboard billing metrics', () => {
  it('surfaces live billing pack KPIs from invoice/payment aggregates', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.BILLING, {
      collectionsToday: 1500,
      pendingBalanceAmount: 4200,
      overdueBalanceAmount: 800,
      invoicesToday: 6,
      overdueInvoices: 2,
      openBalances: 5,
      refundsToday: 100,
      pendingApprovals: 1,
      pendingInsuranceClaims: 3,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'collections_today',
          value: 1500,
          format: 'currency',
          required_permissions: ['billing:read'],
        }),
        expect.objectContaining({
          id: 'pending_balance_amount',
          value: 4200,
          format: 'currency',
          required_permissions: ['billing:read'],
        }),
        expect.objectContaining({
          id: 'refunds_today',
          value: 100,
          format: 'currency',
          required_permissions: ['billing:write'],
        }),
      ])
    );
  });

  it('gates pharmacy billing_pending on billing:read (status parity)', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.PHARMACIST, {
      ordersToday: 4,
      pendingDispense: 2,
      pendingBalanceAmount: 900,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'billing_pending',
          value: 900,
          format: 'currency',
          required_permissions: ['billing:read'],
        }),
      ])
    );
  });

  it('facility admin billing KPIs require billing:read', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.FACILITY_ADMIN, {
      collectionsToday: 2000,
      openInvoices: 4,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'collections_today',
          required_permissions: ['billing:read'],
        }),
        expect.objectContaining({
          id: 'billing_exceptions',
          value: 4,
          required_permissions: ['billing:read'],
        }),
      ])
    );
  });

  it('patient portal open bills KPI reads live billing balance (no bypass)', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.PATIENT, {
      myOpenBills: 3,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'my_open_bills',
          value: 3,
          required_permissions: ['billing:read'],
        }),
      ])
    );
  });

  it('receptionist pending payments KPI requires billing:read', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.RECEPTIONIST, {
      pendingBalanceAmount: 1500,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'pending_balance_amount',
          value: 1500,
          format: 'currency',
          required_permissions: ['billing:read'],
        }),
      ])
    );
  });

  it('mortuary billable events KPI requires mortuary:billing_event', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.MORTUARY_STAFF, {
      billableEventsToCapture: 2,
    });

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'billable_events_to_capture',
          value: 2,
          required_permissions: ['mortuary:billing_event'],
        }),
      ])
    );
  });
});
