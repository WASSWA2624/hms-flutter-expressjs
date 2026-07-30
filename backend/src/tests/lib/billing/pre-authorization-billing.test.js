/**
 * @module tests/lib/billing/pre-authorization-billing
 */

const {
  remainingAmount,
  findActivePreAuthorizationLimit,
  adjustPreAuthorizationConsumedTx,
  consumePreAuthorizationForBillingTx,
  sumInsurerShareFromItems,
} = require('@lib/billing/pre-authorization-billing');

describe('pre-authorization-billing', () => {
  it('computes remaining as approved − consumed (clamped)', () => {
    expect(
      remainingAmount({ approved_amount: '100.00', consumed_amount: '30.00' })
    ).toBe(70);
    expect(
      remainingAmount({ approved_amount: '50.00', consumed_amount: '80.00' })
    ).toBe(0);
    expect(remainingAmount({ approved_amount: null })).toBeNull();
  });

  it('sums insurer share from invoice items', () => {
    expect(
      sumInsurerShareFromItems([
        { insurer_share: '40.00' },
        { insurer_share: '10.00', deleted_at: new Date() },
        { insurer_share: '5.50' },
      ])
    ).toBe(45.5);
  });

  it('findActivePreAuthorizationLimit prefers encounter match', async () => {
    const rows = [
      {
        id: 'auth-patient',
        status: 'APPROVED',
        approved_amount: '200.00',
        consumed_amount: '0',
        patient_id: 'p1',
        encounter_id: null,
        admission_id: null,
      },
      {
        id: 'auth-enc',
        status: 'APPROVED',
        approved_amount: '100.00',
        consumed_amount: '0',
        patient_id: 'p1',
        encounter_id: 'e1',
        admission_id: null,
      },
    ];
    const db = {
      pre_authorization: {
        findMany: jest.fn().mockResolvedValue(rows),
      },
    };

    const found = await findActivePreAuthorizationLimit(db, {
      patientId: 'p1',
      encounterId: 'e1',
      coveragePlanId: 'plan-1',
    });
    expect(found.id).toBe('auth-enc');
  });

  it('adjustPreAuthorizationConsumedTx clamps and is no-op for zero delta', async () => {
    const current = {
      id: 'auth-1',
      approved_amount: '100.00',
      consumed_amount: '20.00',
    };
    const tx = {
      pre_authorization: {
        findFirst: jest.fn().mockResolvedValue(current),
        update: jest.fn().mockImplementation(async ({ data }) => ({
          ...current,
          ...data,
        })),
      },
    };

    expect(
      await adjustPreAuthorizationConsumedTx(tx, {
        preAuthorizationId: 'auth-1',
        deltaAmount: 0,
      })
    ).toBeNull();
    expect(tx.pre_authorization.update).not.toHaveBeenCalled();

    const updated = await adjustPreAuthorizationConsumedTx(tx, {
      preAuthorizationId: 'auth-1',
      deltaAmount: 50,
    });
    expect(updated.consumed_amount).toBe('70.00');

    const capped = await adjustPreAuthorizationConsumedTx(tx, {
      preAuthorizationId: 'auth-1',
      deltaAmount: 500,
    });
    expect(capped.consumed_amount).toBe('100.00');
  });

  it('consumePreAuthorizationForBillingTx adjusts by delta (idempotent replay)', async () => {
    const current = {
      id: 'auth-1',
      approved_amount: '100.00',
      consumed_amount: '40.00',
      status: 'APPROVED',
      patient_id: 'p1',
      encounter_id: 'e1',
      coverage_plan_id: 'plan-1',
    };
    const tx = {
      pre_authorization: {
        findMany: jest.fn().mockResolvedValue([current]),
        findFirst: jest.fn().mockResolvedValue(current),
        update: jest.fn().mockImplementation(async ({ data }) => ({
          ...current,
          ...data,
        })),
      },
    };

    // Replay same insurer share as previous → delta 0 → no write.
    const replay = await consumePreAuthorizationForBillingTx(tx, {
      patientId: 'p1',
      encounterId: 'e1',
      coveragePlanId: 'plan-1',
      insurerShare: 40,
      previousInsurerShare: 40,
    });
    expect(replay).toBeNull();
    expect(tx.pre_authorization.update).not.toHaveBeenCalled();

    const firstPost = await consumePreAuthorizationForBillingTx(tx, {
      patientId: 'p1',
      encounterId: 'e1',
      coveragePlanId: 'plan-1',
      insurerShare: 40,
      previousInsurerShare: 0,
    });
    expect(firstPost.consumed_amount).toBe('80.00');
  });
});
