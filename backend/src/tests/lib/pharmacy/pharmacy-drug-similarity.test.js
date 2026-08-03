/**
 * Pharmacy drug similarity helper tests
 */

const {
  checkPharmacyDrugDuplicates,
  SIMILARITY_THRESHOLD} = require('@lib/pharmacy/pharmacy-drug-similarity');

describe('pharmacy-drug-similarity', () => {
  const existing = [
    {
      id: 'drug-1',
      name: 'Amoxicillin',
      generic_name: 'Amoxicillin',
      brand_name: 'Amoxil',
      code: 'AMX-500',
      form: 'Capsule',
      strength: '500mg'},
    {
      id: 'drug-2',
      name: 'Paracetamol',
      generic_name: 'Paracetamol',
      brand_name: 'Panadol',
      code: 'PCM-500',
      form: 'Tablet',
      strength: '500mg'}];

  it('detects exact code conflicts as hard matches', () => {
    const result = checkPharmacyDrugDuplicates({
      name: 'Something Else',
      genericName: 'Different',
      brandName: 'Other',
      code: 'AMX-500',
      form: 'Syrup',
      strength: '250mg',
      existing});

    expect(result.exactCodeConflict).toBe(true);
    expect(result.similarMatches[0].is_exact).toBe(true);
    expect(result.similarMatches[0].exact_code_conflict).toBe(true);
    // Overall score stays weighted — only code matches among scored fields.
    expect(result.similarMatches[0].score).toBeLessThan(100);
    expect(result.similarMatches[0].code_score).toBe(100);
  });

  it('detects exact clinical identity (generic + form + strength)', () => {
    const result = checkPharmacyDrugDuplicates({
      name: 'Amoxicillin',
      genericName: 'Amoxicillin',
      brandName: 'GenericBrand',
      code: 'OTHER-1',
      form: 'Capsule',
      strength: '500mg',
      existing});

    expect(result.exactIdentityConflict).toBe(true);
    expect(result.similarMatches[0].is_exact).toBe(true);
    expect(result.similarMatches[0].exact_identity_conflict).toBe(true);
    // Differing brand/code pull the composite below a full-field 100.
    expect(result.similarMatches[0].score).toBeLessThan(100);
    expect(result.similarMatches[0].generic_score).toBe(100);
    expect(result.similarMatches[0].form_score).toBe(100);
    expect(result.similarMatches[0].strength_score).toBe(100);
  });

  it('keeps overall score at 100 when every weighted field matches', () => {
    const result = checkPharmacyDrugDuplicates({
      name: 'Amoxicillin',
      genericName: 'Amoxicillin',
      brandName: 'Amoxil',
      code: 'AMX-500',
      form: 'Capsule',
      strength: '500mg',
      existing});

    expect(result.exactIdentityConflict).toBe(true);
    expect(result.exactCodeConflict).toBe(true);
    expect(result.similarMatches[0].score).toBe(100);
  });

  it('returns near matches above the similarity threshold', () => {
    const result = checkPharmacyDrugDuplicates({
      name: 'Amoxicilin',
      genericName: 'Amoxicilin',
      brandName: 'Amoxyl',
      code: 'AMX-501',
      form: 'Capsule',
      strength: '500mg',
      existing});

    expect(result.exactCodeConflict).toBe(false);
    expect(result.exactIdentityConflict).toBe(false);
    expect(result.similarMatches.length).toBeGreaterThan(0);
    expect(result.similarMatches[0].is_exact).toBe(false);
    expect(result.similarMatches[0].score).toBeGreaterThanOrEqual(
      SIMILARITY_THRESHOLD
    );
    expect(result.closestScore).toBe(result.similarMatches[0].score);
  });

  it('ignores excluded drug ids and unrelated catalog entries', () => {
    const result = checkPharmacyDrugDuplicates({
      name: 'Amoxicillin',
      genericName: 'Amoxicillin',
      brandName: 'Amoxil',
      code: 'AMX-500',
      form: 'Capsule',
      strength: '500mg',
      existing,
      excludeDrugId: 'drug-1'});

    expect(result.exactCodeConflict).toBe(false);
    expect(result.exactIdentityConflict).toBe(false);
    expect(
      result.similarMatches.every((match) => match.drug.id !== 'drug-1')
    ).toBe(true);
  });

  it('filters below-threshold candidates', () => {
    const result = checkPharmacyDrugDuplicates({
      name: 'Ibuprofen',
      genericName: 'Ibuprofen',
      brandName: 'Brufen',
      code: 'IBU-400',
      form: 'Tablet',
      strength: '400mg',
      existing});

    expect(result.similarMatches).toEqual([]);
    expect(result.closestScore).toBe(0);
  });
});
