/**
 * Clinical Urgent billing-sections coverage for shared clinical-request-billing
 * (request-time charges from `/clinical?section=urgent` order/procedure flows).
 *
 * @module tests/lib/billing/clinical-request-billing.urgent-billing-sections
 */

const {
  isClinicalRequestBillingCandidate,
  shouldApplyClinicalRequestBilling,
  resolveScopedBillingAmount,
  enrichBillingWithPriceEngine,
  applyClinicalRequestBilling,
  BILLABLE_SOURCE_MODULES} = require('@lib/billing/clinical-request-billing');

const money = (value) => ({
  toString: () => String(value),
  toNumber: () => Number(value)});

const createTx = () => {
  const state = {
    invoices: new Map(),
    items: [],
    payments: [],
    events: new Map(),
    nextInvoice: 1,
    nextPayment: 1,
    nextEvent: 1,
    nextItem: 1};

  const tx = {
    invoice: {
      findFirst: jest.fn(async ({ where, include } = {}) => {
        const invoice = state.invoices.get(where?.id);
        if (!invoice || invoice.deleted_at) {
          return null;
        }
        if (include?.payments) {
          return {
            ...invoice,
            payments: state.payments.filter(
              (payment) => payment.invoice_id === invoice.id && !payment.deleted_at
            )};
        }
        if (include?.items) {
          return {
            ...invoice,
            items: state.items.filter(
              (item) => item.invoice_id === invoice.id && !item.deleted_at
            )};
        }
        return { ...invoice };
      }),
      create: jest.fn(async ({ data }) => {
        const id = `inv-${state.nextInvoice++}`;
        const invoice = {
          id,
          ...data,
          total_amount: money(data.total_amount),
          deleted_at: null};
        state.invoices.set(id, invoice);
        for (const item of data.items?.create || []) {
          state.items.push({
            id: `item-${state.nextItem++}`,
            invoice_id: id,
            ...item,
            deleted_at: null});
        }
        return { ...invoice };
      }),
      update: jest.fn(async ({ where, data }) => {
        const current = state.invoices.get(where.id);
        const next = {
          ...current,
          ...data,
          total_amount: money(data.total_amount ?? current.total_amount)};
        delete next.items;
        state.invoices.set(where.id, next);
        for (const item of data.items?.create || []) {
          state.items.push({
            id: `item-${state.nextItem++}`,
            invoice_id: where.id,
            ...item,
            deleted_at: null});
        }
        return { ...next };
      })},
    invoice_item: {
      updateMany: jest.fn(async ({ where, data }) => {
        for (const item of state.items) {
          if (item.invoice_id === where.invoice_id && !item.deleted_at) {
            Object.assign(item, data);
          }
        }
        return { count: 1 };
      })},
    payment: {
      create: jest.fn(async ({ data }) => {
        const payment = {
          id: `pay-${state.nextPayment++}`,
          ...data,
          amount: money(data.amount),
          deleted_at: null};
        state.payments.push(payment);
        return payment;
      }),
      updateMany: jest.fn(async () => ({ count: 0 }))},
    billable_charge_event: {
      findFirst: jest.fn(async ({ where }) => {
        for (const event of state.events.values()) {
          if (
            event.tenant_id === where.tenant_id &&
            event.source_module === where.source_module &&
            event.source_id === where.source_id &&
            event.charge_key === where.charge_key &&
            event.status === where.status &&
            !event.deleted_at
          ) {
            return { ...event };
          }
        }
        return null;
      }),
      findMany: jest.fn(async ({ where }) =>
        [...state.events.values()].filter(
          (event) =>
            event.invoice_id === where.invoice_id &&
            event.status === where.status &&
            !event.deleted_at
        )
      ),
      create: jest.fn(async ({ data }) => {
        if (
          [...state.events.values()].some(
            (event) =>
              event.tenant_id === data.tenant_id &&
              event.source_module === data.source_module &&
              event.source_id === data.source_id &&
              event.charge_key === data.charge_key &&
              !event.deleted_at
          )
        ) {
          const error = new Error('Unique constraint failed');
          error.code = 'P2002';
          throw error;
        }
        const event = {
          id: `bce-${state.nextEvent++}`,
          ...data,
          deleted_at: null};
        state.events.set(event.id, event);
        return event;
      }),
      update: jest.fn(async ({ where, data }) => {
        const current = state.events.get(where.id);
        const next = { ...current, ...data };
        state.events.set(where.id, next);
        return next;
      })},
    _state: state};

  return tx;
};

jest.mock('@lib/billing/financials', () => {
  const actual = jest.requireActual('@lib/billing/financials');
  return {
    ...actual,
    recalculateInvoiceStateTx: jest.fn(async (tx, invoiceId) => {
      const invoice = await tx.invoice.findFirst({
        where: { id: invoiceId },
        include: { payments: true }});
      return { invoice, financials: actual.computeInvoiceFinancials(invoice || {}) };
    })};
});

jest.mock('@lib/billing/price-resolver', () => {
  const actual = jest.requireActual('@lib/billing/price-resolver');
  return {
    ...actual,
    resolveUnitPrices: jest.fn(async ({ items }) =>
      (items || []).map(() => ({
        unitPrice: '55.00',
        paymentMode: 'SELF_PAY',
        billingEntity: 'FACILITY',
        priceSource: 'FACILITY',
        coveragePlanId: null,
        insuranceCompanyId: null,
        priceBookEntryId: null,
        schemeOfferId: null,
        coveragePercentage: null,
        copayType: null,
        copayValue: null,
        isExcluded: false,
        requiresPreAuth: false}))
    )};
});

describe('Clinical Urgent clinical-request-billing (AC2–AC6)', () => {
  it('candidate gate allows PENDING with zero amount before enrich', () => {
    expect(
      isClinicalRequestBillingCandidate({
        payment_status: 'PENDING',
        total_amount: 0,
        line_items: [
          {
            id: 'RAD-1',
            catalog_type: 'RADIOLOGY_TEST',
            catalog_item_id: 'RAD-1'}]})
    ).toBe(true);
    expect(
      shouldApplyClinicalRequestBilling({
        payment_status: 'PENDING',
        total_amount: 0})
    ).toBe(false);
  });

  it('skips explicit NOT_REQUIRED / NO_CHARGE / NOT_BILLED (no bypass invent)', () => {
    for (const status of ['NOT_REQUIRED', 'NO_CHARGE', 'NOT_BILLED']) {
      expect(
        isClinicalRequestBillingCandidate({
          payment_status: status,
          total_amount: 50})
      ).toBe(false);
      expect(
        shouldApplyClinicalRequestBilling({
          payment_status: status,
          total_amount: 50})
      ).toBe(false);
    }
  });

  it('zero total_amount does not hide priced line items (parity)', () => {
    expect(
      resolveScopedBillingAmount({
        total_amount: 0,
        line_items: [
          {
            id: 'PROC-1',
            unit_price: 40,
            line_total: 40}]})
    ).toBe('40.00');
  });

  it('enrich fills zero-price pending payloads from price engine', async () => {
    const enriched = await enrichBillingWithPriceEngine(
      {
        payment_status: 'PENDING',
        currency: 'USD',
        total_amount: 0,
        line_items: [
          {
            id: 'RAD-CHEST',
            label: 'Chest X-ray',
            quantity: 1,
            catalog_type: 'RADIOLOGY_TEST',
            catalog_item_id: 'RAD-CHEST'}]},
      {
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        catalogType: 'RADIOLOGY_TEST'}
    );

    expect(toNumber(enriched.line_items[0].unit_price)).toBe(55);
    expect(toNumber(enriched.total_amount)).toBeGreaterThan(0);
  });

  it('apply posts invoice after enriching zero-amount PENDING (Urgent radiology path)', async () => {
    const tx = createTx();
    const snapshot = await applyClinicalRequestBilling(tx, {
      billing: {
        payment_status: 'PENDING',
        currency: 'USD',
        total_amount: 0,
        line_items: [
          {
            id: 'RAD-CHEST',
            label: 'Chest X-ray',
            quantity: 1,
            catalog_type: 'RADIOLOGY_TEST',
            catalog_item_id: 'RAD-CHEST'}]},
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      patientId: 'patient-1',
      encounterId: 'encounter-1',
      sourceModule: BILLABLE_SOURCE_MODULES.RADIOLOGY,
      sourceId: 'rad-order-urgent-1',
      catalogType: 'RADIOLOGY_TEST',
      description: 'Radiology: Chest X-ray'});

    expect(snapshot).toEqual(
      expect.objectContaining({
        invoice_id: expect.any(String),
        payment_status: expect.any(String)})
    );
    expect(tx.invoice.create).toHaveBeenCalled();
  });

  it('idempotent replay reuses billable_charge_event / invoice', async () => {
    const tx = createTx();
    const billing = {
      payment_status: 'PENDING',
      currency: 'USD',
      total_amount: 55,
      line_items: [
        {
          id: 'PROC-1',
          label: 'Wound care',
          quantity: 1,
          unit_price: 55,
          line_total: 55}]};

    const first = await applyClinicalRequestBilling(tx, {
      billing,
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      patientId: 'patient-1',
      encounterId: 'encounter-1',
      sourceModule: BILLABLE_SOURCE_MODULES.PROCEDURE,
      sourceId: 'proc-urgent-1',
      description: 'Procedure: Wound care'});
    const second = await applyClinicalRequestBilling(tx, {
      billing,
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      patientId: 'patient-1',
      encounterId: 'encounter-1',
      sourceModule: BILLABLE_SOURCE_MODULES.PROCEDURE,
      sourceId: 'proc-urgent-1',
      description: 'Procedure: Wound care'});

    expect(first.invoice_id).toBe(second.invoice_id);
    expect(tx.invoice.create).toHaveBeenCalledTimes(1);
  });

  it('unauthorized collect/adjust is not owned by clinical-request-billing', () => {
    const billing = require('@lib/billing/clinical-request-billing');
    expect(billing.receivePayment).toBeUndefined();
    expect(billing.adjustInvoice).toBeUndefined();
  });
});

function toNumber(value) {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  if (typeof value === 'object' && typeof value.toNumber === 'function') {
    return value.toNumber();
  }
  return Number(value);
}
