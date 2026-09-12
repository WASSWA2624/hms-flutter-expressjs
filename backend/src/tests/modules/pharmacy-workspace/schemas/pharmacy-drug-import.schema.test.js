const {
  previewDrugImportSchema,
  commitDrugImportSchema} = require('@validations/pharmacy-workspace/pharmacy-workspace.schema');

const planHash = 'b'.repeat(64);

describe('pharmacy drug import schemas', () => {
  it('normalizes the import source and rejects unsupported sources', () => {
    expect(previewDrugImportSchema.parse({ source: ' medic_erp ' })).toEqual({ source: 'MEDIC_ERP' });
    expect(previewDrugImportSchema.safeParse({ source: 'OTHER_APP' }).success).toBe(false);
  });

  it('coerces multipart commit fields', () => {
    const parsed = commitDrugImportSchema.parse({
      source: 'MEDIC_ERP',
      plan_hash: planHash,
      decisions: JSON.stringify([{ key: 'azithromycin|zaha', action: 'MERGE', target_drug_id: 'DRG0000001' }]),
      stock_mode: 'REPLACE',
      clear_missing_stock: 'false',
      confirm_review: 'true',
      currency: 'UGX'});

    expect(parsed).toEqual({
      source: 'MEDIC_ERP',
      plan_hash: planHash,
      decisions: [{ key: 'azithromycin|zaha', action: 'MERGE', target_drug_id: 'DRG0000001' }],
      stock_mode: 'REPLACE',
      clear_missing_stock: false,
      confirm_review: true,
      currency: 'UGX'});
  });

  it('defaults missing decisions and optional flags', () => {
    expect(commitDrugImportSchema.parse({ source: 'MEDIC_ERP', plan_hash: planHash })).toEqual({
      source: 'MEDIC_ERP',
      plan_hash: planHash,
      decisions: []});
  });

  it('rejects malformed hashes, decisions, and flags', () => {
    const base = { source: 'MEDIC_ERP', plan_hash: planHash };
    expect(commitDrugImportSchema.safeParse({ ...base, plan_hash: 'abc' }).success).toBe(false);
    expect(commitDrugImportSchema.safeParse({ ...base, decisions: '{not json' }).success).toBe(false);
    expect(
      commitDrugImportSchema.safeParse({ ...base, decisions: [{ key: 'k', action: 'DELETE' }] }).success
    ).toBe(false);
    expect(commitDrugImportSchema.safeParse({ ...base, confirm_review: 'maybe' }).success).toBe(false);
    expect(commitDrugImportSchema.safeParse({ ...base, stock_mode: 'SET' }).success).toBe(false);
  });
});
