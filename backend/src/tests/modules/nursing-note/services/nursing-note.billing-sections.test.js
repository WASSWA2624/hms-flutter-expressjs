/**
 * Nursing-note module billing-sections guard for Nursing All / Assigned ward.
 *
 * Direct nursing-note CRUD must never invent a cash ledger — billable notes
 * post only via ipd-flow addNursingNote → persistNursingServiceBilling.
 */

jest.mock('@repositories/nursing-note/nursing-note.repository');
jest.mock('@lib/audit');

const nursingNoteService = require('@services/nursing-note/nursing-note.service');
const {
  createNursingNoteSchema} = require('@validations/nursing-note/nursing-note.schema');

describe('nursing-note All / Assigned ward billing-sections guard', () => {
  it('AC2: create schema strips / rejects billing payloads (no parallel ledger)', () => {
    const parsed = createNursingNoteSchema.safeParse({
      admission_id: 'ADM-1',
      nurse_user_id: 'USR-1',
      note: 'Plain note',
      billing: {
        payment_status: 'PENDING',
        total_amount: '15000.00'}});

    expect(parsed.success).toBe(true);
    expect(parsed.data.billing).toBeUndefined();
    expect(parsed.data).toEqual({
      admission_id: 'ADM-1',
      nurse_user_id: 'USR-1',
      note: 'Plain note'});
  });

  it('AC4: nursing-note service exports no Billing settle/adjust APIs', () => {
    expect(nursingNoteService.receivePayment).toBeUndefined();
    expect(nursingNoteService.refundPayment).toBeUndefined();
    expect(nursingNoteService.adjustInvoice).toBeUndefined();
    expect(nursingNoteService.persistNursingServiceBilling).toBeUndefined();
  });
});
