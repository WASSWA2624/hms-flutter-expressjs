const {
  calculateCompensationAmount,
  computeEligibleWorkdays,
  daysBetweenInclusive,
  overlapDaysInclusive,
  sumCompensationAmounts,
} = require('../../../../modules/hr-workspace/services/payroll-calculation');

describe('payroll-calculation', () => {
  const periodStart = new Date('2026-01-01T00:00:00.000Z');
  const periodEnd = new Date('2026-01-31T23:59:59.999Z');

  it('calculates PER_HOUR from shift hours', () => {
    const result = calculateCompensationAmount({
      compensation: { pay_type: 'PER_HOUR', rate: 50, currency: 'USD' },
      totalHours: 40,
      periodStart,
      periodEnd,
      eligibleWorkdays: { eligibleDays: 20, eligibleDayKeys: [] },
    });

    expect(result.amount).toBe(2000);
    expect(result.calculation.quantity).toBe(40);
    expect(result.calculation.unit).toBe('hours');
  });

  it('calculates PER_DAY from eligible workdays', () => {
    const eligibleWorkdays = computeEligibleWorkdays({
      periodStart,
      periodEnd,
      availabilityRecords: [
        {
          day_of_week: 1,
          preference: 'AVAILABLE',
          effective_from: periodStart,
          effective_to: null,
        },
      ],
      assignments: [],
      leaves: [],
    });

    const result = calculateCompensationAmount({
      compensation: { pay_type: 'PER_DAY', rate: 100, currency: 'USD' },
      periodStart,
      periodEnd,
      eligibleWorkdays,
    });

    expect(result.calculation.unit).toBe('days');
    expect(result.amount).toBeGreaterThan(0);
  });

  it('excludes approved leave from eligible workdays', () => {
    const withLeave = computeEligibleWorkdays({
      periodStart,
      periodEnd,
      availabilityRecords: [],
      assignments: [
        {
          shift: {
            start_time: new Date('2026-01-10T08:00:00.000Z'),
            end_time: new Date('2026-01-10T16:00:00.000Z'),
          },
        },
      ],
      leaves: [
        {
          start_date: new Date('2026-01-10T00:00:00.000Z'),
          end_date: new Date('2026-01-10T23:59:59.999Z'),
        },
      ],
    });
    const withoutLeave = computeEligibleWorkdays({
      periodStart,
      periodEnd,
      availabilityRecords: [],
      assignments: [
        {
          shift: {
            start_time: new Date('2026-01-10T08:00:00.000Z'),
            end_time: new Date('2026-01-10T16:00:00.000Z'),
          },
        },
      ],
      leaves: [],
    });

    expect(withLeave.eligibleDays).toBe(0);
    expect(withoutLeave.eligibleDays).toBe(1);
  });

  it('calculates PER_MONTH with calendar proration', () => {
    const result = calculateCompensationAmount({
      compensation: {
        pay_type: 'PER_MONTH',
        rate: 3100,
        currency: 'USD',
        effective_from: periodStart,
        effective_to: null,
        metadata_json: { pay_frequency: 'MONTHLY' },
      },
      periodStart,
      periodEnd,
      eligibleWorkdays: { eligibleDays: 10, eligibleDayKeys: [] },
    });

    expect(result.amount).toBe(3100);
    expect(result.calculation.formula).toBe('rate * eligible_days / period_days');
  });

  it('calculates PER_CONSULTATION and PER_PROCEDURE counts', () => {
    const consultation = calculateCompensationAmount({
      compensation: { pay_type: 'PER_CONSULTATION', rate: 75, currency: 'USD' },
      periodStart,
      periodEnd,
      consultationCount: 4,
      eligibleWorkdays: { eligibleDays: 0, eligibleDayKeys: [] },
    });
    const procedure = calculateCompensationAmount({
      compensation: { pay_type: 'PER_PROCEDURE', rate: 500, currency: 'USD' },
      periodStart,
      periodEnd,
      procedureCount: 2,
      eligibleWorkdays: { eligibleDays: 0, eligibleDayKeys: [] },
    });

    expect(consultation.amount).toBe(300);
    expect(procedure.amount).toBe(1000);
    expect(consultation.warning).toBeNull();
    expect(procedure.warning).toBeNull();
  });

  it('flags zero quantity warnings', () => {
    const result = calculateCompensationAmount({
      compensation: { pay_type: 'PER_PROCEDURE', rate: 500, currency: 'USD' },
      periodStart,
      periodEnd,
      procedureCount: 0,
      eligibleWorkdays: { eligibleDays: 0, eligibleDayKeys: [] },
    });

    expect(result.amount).toBe(0);
    expect(result.warning).toBe('zero_quantity');
  });

  it('sums multi-line compensation amounts', () => {
    const calculations = [
      calculateCompensationAmount({
        compensation: { pay_type: 'PER_MONTH', rate: 3000, currency: 'USD', effective_from: periodStart },
        periodStart,
        periodEnd,
        eligibleWorkdays: { eligibleDays: 20, eligibleDayKeys: [] },
      }),
      calculateCompensationAmount({
        compensation: { pay_type: 'PER_CONSULTATION', rate: 50, currency: 'USD' },
        periodStart,
        periodEnd,
        consultationCount: 10,
        eligibleWorkdays: { eligibleDays: 0, eligibleDayKeys: [] },
      }),
      calculateCompensationAmount({
        compensation: { pay_type: 'PER_PROCEDURE', rate: 200, currency: 'USD' },
        periodStart,
        periodEnd,
        procedureCount: 3,
        eligibleWorkdays: { eligibleDays: 0, eligibleDayKeys: [] },
      }),
    ];

    const summary = sumCompensationAmounts(calculations);
    expect(summary.amount).toBe(4100);
    expect(calculations).toHaveLength(3);
  });

  it('computes inclusive day helpers', () => {
    expect(daysBetweenInclusive(periodStart, periodEnd)).toBe(31);
    expect(
      overlapDaysInclusive(
        new Date('2026-01-15'),
        new Date('2026-01-20'),
        periodStart,
        periodEnd
      )
    ).toBe(6);
  });
});
