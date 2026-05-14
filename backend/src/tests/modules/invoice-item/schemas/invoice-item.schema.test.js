/**
 * Invoice item schema tests
 */

const {
  createInvoiceItemSchema,
  updateInvoiceItemSchema,
  invoiceItemIdParamsSchema,
  listInvoiceItemsQuerySchema
} = require('@validations/invoice-item/invoice-item.schema');

describe('Invoice Item Schemas', () => {
  const validCreateData = {
    invoice_id: '550e8400-e29b-41d4-a716-446655440000',
    description: 'Consultation fee',
    quantity: 2,
    unit_price: '50.00',
    total_price: '100.00'
  };

  describe('createInvoiceItemSchema', () => {
    it('should validate valid payload', () => {
      const result = createInvoiceItemSchema.safeParse(validCreateData);
      expect(result.success).toBe(true);
    });

    it('should require invoice_id', () => {
      const data = { ...validCreateData };
      delete data.invoice_id;
      const result = createInvoiceItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid invoice_id', () => {
      const result = createInvoiceItemSchema.safeParse({
        ...validCreateData,
        invoice_id: 'bad-id'
      });
      expect(result.success).toBe(false);
    });

    it('should require description', () => {
      const data = { ...validCreateData };
      delete data.description;
      const result = createInvoiceItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty description', () => {
      const result = createInvoiceItemSchema.safeParse({
        ...validCreateData,
        description: '   '
      });
      expect(result.success).toBe(false);
    });

    it('should reject overly long description', () => {
      const result = createInvoiceItemSchema.safeParse({
        ...validCreateData,
        description: 'a'.repeat(256)
      });
      expect(result.success).toBe(false);
    });

    it('should require unit_price and total_price as decimals', () => {
      const badUnitPrice = createInvoiceItemSchema.safeParse({
        ...validCreateData,
        unit_price: 'abc'
      });
      const badTotalPrice = createInvoiceItemSchema.safeParse({
        ...validCreateData,
        total_price: '12.345'
      });
      expect(badUnitPrice.success).toBe(false);
      expect(badTotalPrice.success).toBe(false);
    });

    it('should reject zero or negative quantity', () => {
      const zeroQty = createInvoiceItemSchema.safeParse({
        ...validCreateData,
        quantity: 0
      });
      const negativeQty = createInvoiceItemSchema.safeParse({
        ...validCreateData,
        quantity: -2
      });
      expect(zeroQty.success).toBe(false);
      expect(negativeQty.success).toBe(false);
    });

    it('should allow omitted quantity', () => {
      const data = { ...validCreateData };
      delete data.quantity;
      const result = createInvoiceItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateInvoiceItemSchema', () => {
    it('should validate partial payload', () => {
      const result = updateInvoiceItemSchema.safeParse({
        description: 'Updated description'
      });
      expect(result.success).toBe(true);
    });

    it('should validate empty payload', () => {
      const result = updateInvoiceItemSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should reject invalid quantity', () => {
      const result = updateInvoiceItemSchema.safeParse({
        quantity: -1
      });
      expect(result.success).toBe(false);
    });
  });

  describe('invoiceItemIdParamsSchema', () => {
    it('should validate valid id params', () => {
      const result = invoiceItemIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid id params', () => {
      const result = invoiceItemIdParamsSchema.safeParse({
        id: 'bad-id'
      });
      expect(result.success).toBe(false);
    });
  });

  describe('listInvoiceItemsQuerySchema', () => {
    it('should validate list query payload', () => {
      const result = listInvoiceItemsQuerySchema.safeParse({
        page: '1',
        limit: '20',
        invoice_id: '550e8400-e29b-41d4-a716-446655440000',
        search: 'consultation',
        sort_by: 'created_at',
        order: 'desc'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid invoice_id in query', () => {
      const result = listInvoiceItemsQuerySchema.safeParse({
        invoice_id: 'bad-id'
      });
      expect(result.success).toBe(false);
    });
  });
});

