/**
 * @module tests/lib/billing/clinical-request-billing
 */

const {
  buildPendingClinicalRequestBilling,
  normalizeBillingOfficeClinicalBilling,
  resolveInvoicePaymentStatus,
  syncClinicalOrderBillingSnapshotsFromInvoiceTx} = require('@lib/billing/clinical-request-billing');

describe('clinical-request-billing helpers', () => {
  it('buildPendingClinicalRequestBilling returns pending payload with totals', () => {
    const billing = buildPendingClinicalRequestBilling({
      lineItems: [
        {
          id: 'LAB-CBC',
          label: 'Complete blood count',
          quantity: 1,
          unit_price: '25.00',
          line_total: '25.00'}],
      currency: 'USD'});

    expect(billing).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        currency: 'USD',
        total_amount: '25.00'})
    );
    expect(billing.line_items).toHaveLength(1);
  });

  it('normalizeBillingOfficeClinicalBilling strips pay-now fields', () => {
    const billing = normalizeBillingOfficeClinicalBilling({
      payment_status: 'PAID',
      paid_amount: '25.00',
      payment_method: 'CASH',
      currency: 'USD',
      line_items: [
        {
          id: 'LAB-CBC',
          label: 'Complete blood count',
          quantity: 1,
          unit_price: '25.00',
          line_total: '25.00'}]});

    expect(billing).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        total_amount: '25.00'})
    );
    expect(billing.paid_amount).toBeUndefined();
    expect(billing.payment_method).toBeUndefined();
  });

  it('buildPendingClinicalRequestBilling preserves pharmacy price source', () => {
    const billing = buildPendingClinicalRequestBilling({
      lineItems: [
        {
          id: 'item-1',
          label: 'Artemether',
          quantity: 24,
          unit_price: '500.00',
          line_total: '12000.00',
          price_source: 'PHARMACY'}],
      currency: 'TZS'});

    expect(billing.line_items[0]).toEqual(
      expect.objectContaining({
        id: 'item-1',
        unit_price: '500.00',
        price_source: 'PHARMACY'})
    );
  });

  it('resolveInvoicePaymentStatus returns PAID when billing_status is PAID', () => {
    expect(
      resolveInvoicePaymentStatus({
        billing_status: 'PAID',
        total_amount: '40.00',
        payments: []})
    ).toBe('PAID');
  });

  it('resolveInvoicePaymentStatus returns PARTIAL for partial payments', () => {
    expect(
      resolveInvoicePaymentStatus({
        billing_status: 'PARTIAL',
        total_amount: '40.00',
        payments: [{ status: 'COMPLETED', amount: '10.00' }]})
    ).toBe('PARTIAL');
  });

  it('syncs reconciled invoice status into radiology request billing', async () => {
    const tx = {
      invoice: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'invoice-1',
          status: 'PAID',
          billing_status: 'PAID',
          total_amount: '80.00',
          payments: [{ status: 'COMPLETED', amount: '80.00' }]})},
      lab_order: { findMany: jest.fn().mockResolvedValue([]) },
      pharmacy_order: { findMany: jest.fn().mockResolvedValue([]) },
      radiology_order: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'radiology-order-1',
            request_details: {
              modality: 'XRAY',
              billing: {
                invoice_id: 'invoice-1',
                payment_status: 'PENDING'}}}]),
        update: jest.fn().mockResolvedValue({})}};

    const result = await syncClinicalOrderBillingSnapshotsFromInvoiceTx(
      tx,
      'invoice-1'
    );

    expect(tx.radiology_order.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          request_details: {
            path: '$.billing.invoice_id',
            equals: 'invoice-1',
          },
        }),
      })
    );
    expect(result.radiologyOrderIds).toEqual(['radiology-order-1']);
    expect(tx.radiology_order.update).toHaveBeenCalledWith({
      where: { id: 'radiology-order-1' },
      data: {
        request_details: {
          modality: 'XRAY',
          billing: expect.objectContaining({
            invoice_id: 'invoice-1',
            payment_status: 'PAID',
            paid_amount: '80.00'})}}});
  });
});
