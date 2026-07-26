const {
  checkTenantDuplicates,
  compositeSimilarityScore,
  normalizeEmail,
  normalizePhone,
  normalizeSlug,
  normalizeText
} = require('@lib/tenant/tenant-similarity');

describe('tenant-similarity', () => {
  const existing = [
    {
      id: 'tenant-1',
      human_friendly_id: 'TEN0001',
      name: 'DemoCare General Hospital',
      slug: 'democare-general-hospital',
      is_active: true,
      extension_json: {
        currency: 'UGX',
        contact: {
          name: 'Jane Doe',
          email: 'jane@example.com',
          phone: '+256 700 000 000'
        },
        billing: {
          standard_consultation_fee: '50000'
        }
      }
    }
  ];

  it('normalizes identity and contact values', () => {
    expect(normalizeText('  Demo-Care!! ')).toBe('democare');
    expect(normalizeSlug('Demo Care!!')).toBe('demo-care');
    expect(normalizeEmail(' Jane@Example.COM ')).toBe('jane@example.com');
    expect(normalizePhone('+256 700-000-000')).toBe('256700000000');
  });

  it('weights identity fields more heavily than configuration fields', () => {
    const identityHeavy = compositeSimilarityScore({
      nameScore: 100,
      slugScore: 100,
      currencyScore: 0,
      feeScore: 0
    });
    const configHeavy = compositeSimilarityScore({
      nameScore: 0,
      slugScore: 0,
      currencyScore: 100,
      feeScore: 100
    });
    expect(identityHeavy).toBeGreaterThan(configHeavy);
  });

  it('detects multi-field similar tenants with field comparisons', () => {
    const result = checkTenantDuplicates({
      name: 'Democare General Hospitl',
      slug: 'new-slug',
      contactName: 'Jane Doe',
      contactEmail: 'jane@example.com',
      contactPhone: '256700000000',
      currency: 'UGX',
      standardConsultationFee: 50000,
      existing
    });

    expect(result.exactSlugConflict).toBe(false);
    expect(result.nonExactSimilarMatches.length).toBeGreaterThan(0);
    expect(result.nonExactSimilarMatches[0].score).toBeGreaterThanOrEqual(70);
    expect(result.nonExactSimilarMatches[0].nameScore).toBeGreaterThanOrEqual(80);
    expect(result.nonExactSimilarMatches[0].field_comparisons).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'name' }),
        expect.objectContaining({ field: 'contact_email', status: 'MATCH' }),
        expect.objectContaining({ field: 'contact_phone', status: 'MATCH' })
      ])
    );
  });

  it('marks exact slug conflicts as non-overridable', () => {
    const result = checkTenantDuplicates({
      name: 'Completely Different',
      slug: 'democare-general-hospital',
      existing
    });

    expect(result.exactSlugConflict).toBe(true);
    expect(result.overridableMatches).toHaveLength(0);
    expect(result.similarMatches[0].exactSlugConflict).toBe(true);
  });
});
