/**
 * @module tests/lib/insurer/adapter
 */

const {
  createStubAdapter,
  getInsurerAdapter,
} = require('@lib/insurer/adapter');

describe('insurer adapter', () => {
  it('stub eligibility succeeds with member id', async () => {
    const adapter = createStubAdapter();
    const result = await adapter.checkEligibility({
      memberId: 'MEM-1',
      coveragePlan: { id: 'plan-1', coverage_percentage: 80 },
    });
    expect(result.eligible).toBe(true);
    expect(result.status).toBe('ACTIVE');
  });

  it('stub claim submit returns payer reference', async () => {
    const adapter = getInsurerAdapter({ adapter_type: 'STUB' });
    const result = await adapter.submitClaim({
      claim: { id: 'c1' },
      invoice: { id: 'inv-1' },
    });
    expect(result.accepted).toBe(true);
    expect(result.status).toBe('SUBMITTED');
    expect(result.payerReference).toMatch(/^STUB-CLM-/);
  });

  it('generic rest adapter wraps stub', async () => {
    const adapter = getInsurerAdapter({
      adapter_type: 'GENERIC_REST',
      base_url: 'https://payer.example',
    });
    expect(adapter.name).toBe('GENERIC_REST');
    const eligibility = await adapter.checkEligibility({ memberId: 'X' });
    expect(eligibility.eligible).toBe(true);
  });
});
