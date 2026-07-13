/**
 * @module tests/lib/billing/coverage-split
 */

const {
  splitLineCoverage,
  applyCoverageSplitToLineItems,
  summarizeCoverageShares,
} = require('@lib/billing/coverage-split');

describe('coverage-split', () => {
  it('keeps full amount as patient share for self-pay', () => {
    expect(splitLineCoverage({ lineTotal: 100, insured: false })).toEqual({
      lineTotal: '100.00',
      patientShare: '100.00',
      insurerShare: '0.00',
      copayAmount: '0.00',
    });
  });

  it('applies coverage percentage without copay', () => {
    expect(
      splitLineCoverage({
        lineTotal: 100,
        insured: true,
        coveragePercentage: 80,
        copayType: 'NONE',
      })
    ).toEqual({
      lineTotal: '100.00',
      patientShare: '20.00',
      insurerShare: '80.00',
      copayAmount: '0.00',
    });
  });

  it('applies percent copay on covered base', () => {
    expect(
      splitLineCoverage({
        lineTotal: 100,
        insured: true,
        coveragePercentage: 80,
        copayType: 'PERCENT',
        copayValue: 10,
      })
    ).toEqual({
      lineTotal: '100.00',
      patientShare: '28.00',
      insurerShare: '72.00',
      copayAmount: '8.00',
    });
  });

  it('summarizes shares across line items', () => {
    const lines = applyCoverageSplitToLineItems(
      [
        { label: 'CBC', quantity: 1, unit_price: '50.00', line_total: '50.00' },
        { label: 'XRAY', quantity: 1, unit_price: '50.00', line_total: '50.00' },
      ],
      {
        insured: true,
        coveragePercentage: 100,
        copayType: 'FIXED',
        copayValue: 5,
      }
    );
    expect(summarizeCoverageShares(lines)).toEqual({
      total: '100.00',
      patientShare: '10.00',
      insurerShare: '90.00',
      copayAmount: '10.00',
    });
  });
});
