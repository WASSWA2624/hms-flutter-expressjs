/**
 * @module tests/lib/billing/coverage-split-pre-auth
 * @description Pre-authorization remaining caps must constrain insurer share.
 */

const {
  splitLineCoverage,
  applyCoverageSplitToLineItems,
  summarizeCoverageShares,
} = require('@lib/billing/coverage-split');

describe('coverage-split pre-authorization caps', () => {
  it('caps insurer share at pre-auth remaining and shifts excess to patient', () => {
    expect(
      splitLineCoverage({
        lineTotal: 100,
        insured: true,
        coveragePercentage: 80,
        copayType: 'NONE',
        preAuthRemainingAmount: 50,
      })
    ).toEqual({
      lineTotal: '100.00',
      patientShare: '50.00',
      insurerShare: '50.00',
      copayAmount: '0.00',
    });
  });

  it('does not raise insurer share when remaining exceeds uncapped share', () => {
    expect(
      splitLineCoverage({
        lineTotal: 100,
        insured: true,
        coveragePercentage: 80,
        copayType: 'NONE',
        preAuthRemainingAmount: 500,
      })
    ).toEqual({
      lineTotal: '100.00',
      patientShare: '20.00',
      insurerShare: '80.00',
      copayAmount: '0.00',
    });
  });

  it('applies remaining sequentially across line items (no double spend)', () => {
    const lines = applyCoverageSplitToLineItems(
      [
        { label: 'A', quantity: 1, unit_price: '100.00', line_total: '100.00' },
        { label: 'B', quantity: 1, unit_price: '100.00', line_total: '100.00' },
      ],
      {
        insured: true,
        coveragePercentage: 100,
        copayType: 'NONE',
        preAuthRemainingAmount: 120,
      }
    );

    expect(lines[0].insurer_share).toBe('100.00');
    expect(lines[0].patient_share).toBe('0.00');
    expect(lines[1].insurer_share).toBe('20.00');
    expect(lines[1].patient_share).toBe('80.00');
    expect(summarizeCoverageShares(lines)).toEqual({
      total: '200.00',
      patientShare: '80.00',
      insurerShare: '120.00',
      copayAmount: '0.00',
    });
  });

  it('zero remaining forces full patient responsibility', () => {
    const lines = applyCoverageSplitToLineItems(
      [{ label: 'A', quantity: 1, unit_price: '50.00', line_total: '50.00' }],
      {
        insured: true,
        coveragePercentage: 90,
        preAuthRemainingAmount: 0,
      }
    );
    expect(lines[0].insurer_share).toBe('0.00');
    expect(lines[0].patient_share).toBe('50.00');
  });
});
