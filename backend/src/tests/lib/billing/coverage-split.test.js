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

  it('applies offer exclusion as full patient share', () => {
    const lines = applyCoverageSplitToLineItems(
      [
        {
          label: 'CBC',
          quantity: 1,
          unit_price: '25000.00',
          line_total: '25000.00',
          is_excluded: true,
          scheme_offer_id: 'offer-1',
          insurance_company_id: 'company-1',
        },
      ],
      {
        insured: true,
        coveragePercentage: 90,
        coveragePlanId: 'scheme-gold',
        insuranceCompanyId: 'company-1',
      }
    );
    expect(lines[0]).toMatchObject({
      patient_share: '25000.00',
      insurer_share: '0.00',
      is_excluded: true,
      scheme_offer_id: 'offer-1',
      insurance_company_id: 'company-1',
    });
  });

  it('lets per-line offer coverage override scheme defaults', () => {
    const lines = applyCoverageSplitToLineItems(
      [
        {
          label: 'CBC Gold',
          quantity: 1,
          unit_price: '25000.00',
          line_total: '25000.00',
          coverage_percentage: 90,
          copay_type: 'PERCENT',
          copay_value: 10,
          scheme_offer_id: 'offer-gold',
        },
        {
          label: 'CBC Silver',
          quantity: 1,
          unit_price: '30000.00',
          line_total: '30000.00',
          coverage_percentage: 70,
          copay_type: 'FIXED',
          copay_value: 5000,
          scheme_offer_id: 'offer-silver',
        },
      ],
      {
        insured: true,
        coveragePercentage: 50,
        paymentMode: 'INSURANCE',
      }
    );
    expect(lines[0].insurer_share).toBe('20250.00');
    expect(lines[0].patient_share).toBe('4750.00');
    expect(lines[1].insurer_share).toBe('16000.00');
    expect(lines[1].patient_share).toBe('14000.00');
  });
});
