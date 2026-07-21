jest.mock('@lib/logging', () => ({
  logger: { error: jest.fn(), warn: jest.fn(), info: jest.fn() },
}));

jest.mock('@lib/realtime/recipients', () => ({
  findRealtimeRecipientUserIds: jest.fn(async () => ['billing-1', 'reception-1']),
}));

jest.mock('@lib/websocket', () => ({
  publishDomainEvent: jest.fn(),
  BILLING_EVENTS: {
    BILLING_INVOICE_ISSUED: 'billing.invoice_issued',
    INVOICE_UPDATED: 'invoice.updated',
    BILLING_BALANCE_UPDATED: 'billing.balance_updated',
  },
}));

const { findRealtimeRecipientUserIds } = require('@lib/realtime/recipients');
const { publishDomainEvent, BILLING_EVENTS } = require('@lib/websocket');
const {
  publishIssuedInvoiceBillingEvents,
  publishUpdatedInvoiceBillingEvents,
} = require('@lib/billing/realtime');

describe('billing realtime helpers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('publishes issued invoice events to billing recipients', async () => {
    await publishIssuedInvoiceBillingEvents({
      invoice: {
        id: 'inv-1',
        human_friendly_id: 'INV0001',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        patient_id: 'patient-1',
        encounter_id: 'encounter-1',
        billing_status: 'ISSUED',
        status: 'SENT',
        total_amount: '25000.00',
      },
      actorUserId: 'usr-1',
    });

    expect(findRealtimeRecipientUserIds).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: expect.arrayContaining(['BILLING', 'RECEPTIONIST']),
      })
    );
    expect(publishDomainEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        event: BILLING_EVENTS.BILLING_INVOICE_ISSUED,
        recipient_user_ids: ['billing-1', 'reception-1'],
      })
    );
    expect(publishDomainEvent).toHaveBeenCalledWith(
      expect.objectContaining({ event: BILLING_EVENTS.INVOICE_UPDATED })
    );
    expect(publishDomainEvent).toHaveBeenCalledWith(
      expect.objectContaining({ event: BILLING_EVENTS.BILLING_BALANCE_UPDATED })
    );
  });

  it('publishes cancel updates without an issued event', async () => {
    await publishUpdatedInvoiceBillingEvents({
      invoice: {
        id: 'inv-2',
        tenant_id: 'tenant-1',
        billing_status: 'CANCELLED',
        status: 'CANCELLED',
      },
      action: 'CANCELLED',
      actorUserId: 'usr-1',
    });

    expect(publishDomainEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        event: BILLING_EVENTS.INVOICE_UPDATED,
        payload: expect.objectContaining({ action: 'CANCELLED' }),
      })
    );
    expect(publishDomainEvent).not.toHaveBeenCalledWith(
      expect.objectContaining({ event: BILLING_EVENTS.BILLING_INVOICE_ISSUED })
    );
  });
});
