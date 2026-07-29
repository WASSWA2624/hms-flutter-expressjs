const {
  workspaceQuerySchema,
  workItemsQuerySchema,
  patientLedgerParamsSchema,
  invoiceIdentifierParamsSchema,
  paymentIdentifierParamsSchema,
  approvalIdentifierParamsSchema,
  adjustmentRequestSchema} = require('@validations/billing/billing.schema');

describe('billing schema', () => {
  it('accepts UUID and friendly IDs in params', () => {
    expect(patientLedgerParamsSchema.safeParse({ patientIdentifier: '550e8400-e29b-41d4-a716-446655440000' }).success).toBe(true);
    expect(invoiceIdentifierParamsSchema.safeParse({ invoiceIdentifier: 'INV0000123' }).success).toBe(true);
    expect(paymentIdentifierParamsSchema.safeParse({ paymentIdentifier: 'PAY0000123' }).success).toBe(true);
    expect(approvalIdentifierParamsSchema.safeParse({ approvalIdentifier: 'APP0000123' }).success).toBe(true);
  });

  it('validates workspace/work-items queries', () => {
    expect(workspaceQuerySchema.safeParse({ page: '1', limit: '20', search: 'john' }).success).toBe(true);
    expect(workItemsQuerySchema.safeParse({ queue: 'APPROVAL_REQUIRED', page: '1', limit: '10' }).success).toBe(true);
    expect(workItemsQuerySchema.safeParse({ page: '1', limit: '20' }).success).toBe(true);
    expect(
      workItemsQuerySchema.safeParse({
        queue: 'PENDING_PAYMENT',
        patient_id: 'PAT0000001',
        invoice_number: 'INV0000004',
        encounter_id: 'ENC0000001',
        source_module: 'Laboratory',
        billing_status: 'ISSUED',
        from: '2026-07-01T00:00:00.000Z',
        to: '2026-07-04T23:59:59.000Z',
        search: 'wilson',
        page: '1',
        limit: '12'}).success
    ).toBe(true);
  });

  it('allows signed amount for adjustments', () => {
    expect(
      adjustmentRequestSchema.safeParse({
        invoice_id: 'INV0000123',
        amount: '-25.50',
        reason: 'Loyalty discount'}).success
    ).toBe(true);
  });

  it('rejects invalid adjustment amount', () => {
    expect(
      adjustmentRequestSchema.safeParse({
        invoice_id: 'INV0000123',
        amount: 'abc',
        reason: 'Invalid'}).success
    ).toBe(false);
  });
});
