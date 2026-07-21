/**
 * @module tests/lib/billing/clinical-request-billing.idempotency
 *
 * Unit-level coverage for idempotent charge posting via billable_charge_event.
 */

const {
  applyClinicalRequestBilling,
  buildConsultationBillingPayload,
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
        const key = `${data.tenant_id}:${data.source_module}:${data.source_id}:${data.charge_key}`;
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
        const event = { id: `bce-${state.nextEvent++}`, ...data, deleted_at: null };
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
    resolveUnitPrices: jest.fn(async () => [])};
});

describe('applyClinicalRequestBilling idempotency', () => {
  it('reuses the same invoice on retry without existingSnapshot', async () => {
    const tx = createTx();
    const billing = buildConsultationBillingPayload({
      consultationFee: '50.00',
      currency: 'USD',
      catalogItemId: 'catalog-consult-1'});

    const first = await applyClinicalRequestBilling(tx, {
      billing,
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      patientId: 'patient-1',
      encounterId: 'encounter-1',
      sourceModule: BILLABLE_SOURCE_MODULES.CONSULTATION,
      sourceId: 'encounter-1',
      catalogType: 'CONSULTATION',
      catalogItemId: 'catalog-consult-1',
      description: 'Consultation fee'});

    expect(first?.invoice_id).toBeTruthy();
    expect(tx.invoice.create).toHaveBeenCalledTimes(1);
    expect(tx.billable_charge_event.create).toHaveBeenCalledTimes(1);

    const second = await applyClinicalRequestBilling(tx, {
      billing,
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      patientId: 'patient-1',
      encounterId: 'encounter-1',
      sourceModule: BILLABLE_SOURCE_MODULES.CONSULTATION,
      sourceId: 'encounter-1',
      catalogType: 'CONSULTATION',
      catalogItemId: 'catalog-consult-1',
      description: 'Consultation fee'});

    expect(second?.invoice_id).toBe(first.invoice_id);
    expect(tx.invoice.create).toHaveBeenCalledTimes(1);
    expect(tx._state.invoices.size).toBe(1);
  });

  it('preserves posted unit price snapshots on line items', async () => {
    const tx = createTx();
    const billing = buildConsultationBillingPayload({
      consultationFee: '65.50',
      currency: 'USD',
      catalogItemId: 'catalog-consult-2'});

    const snapshot = await applyClinicalRequestBilling(tx, {
      billing,
      tenantId: 'tenant-1',
      patientId: 'patient-1',
      sourceModule: BILLABLE_SOURCE_MODULES.CONSULTATION,
      sourceId: 'encounter-2',
      catalogType: 'CONSULTATION',
      catalogItemId: 'catalog-consult-2'});

    expect(snapshot.total_amount).toBe('65.50');
    const event = [...tx._state.events.values()][0];
    expect(event.unit_price_snapshot).toBe('65.50');
    expect(event.total_amount_snapshot).toBe('65.50');
    expect(tx._state.items[0].unit_price).toBe('65.50');
  });
});
