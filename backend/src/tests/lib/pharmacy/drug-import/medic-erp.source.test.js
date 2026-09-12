const medicErpSource = require('@lib/pharmacy/drug-import/sources/medic-erp.source');
const {
  checkTemplateColumns,
  resolveDrugImportSource,
} = require('@lib/pharmacy/drug-import/drug-import-sources');
const { HttpError } = require('@lib/errors');
const { buildMedicErpRow } = require('./medic-erp-workbook.fixture');

const today = new Date('2026-09-13T00:00:00.000Z');
const codesOf = (issues) => issues.map((issue) => issue.code);

describe('medic-erp source', () => {
  it('is registered and resolves case-insensitively', () => {
    expect(resolveDrugImportSource('medic_erp')).toBe(medicErpSource);
    expect(() => resolveDrugImportSource('OTHER_APP')).toThrow(HttpError);
  });

  it('reports missing and unexpected template columns', () => {
    const headers = medicErpSource.columns.filter((column) => column !== 'cost').concat('notes');
    expect(checkTemplateColumns(medicErpSource, headers)).toEqual({
      missing_columns: ['cost'],
      unexpected_columns: ['notes'],
    });
  });

  it('maps a stock row using the on-hand quantity and inferred attributes', () => {
    const { record, issues } = medicErpSource.mapRow(buildMedicErpRow(), 10, { today });

    expect(issues).toEqual([]);
    expect(record).toMatchObject({
      row_number: 10,
      name: 'AZITHROMYCIN 500MG TABLET',
      brand_name: 'ZAHA',
      form: 'Tablet',
      strength: '500 mg',
      quantity: 4,
      received_quantity: 20,
      unit_price: 7000,
      buy_unit_price: 4300,
      batch_number: 'PA09025',
      supplier_name: null,
    });
    expect(record.expiry_date.toISOString()).toBe('2028-05-31T00:00:00.000Z');
    expect(record.source_updated_at.toISOString()).toBe('2026-07-10T07:14:58.532Z');
  });

  it('excludes rows without a product name or with an unreadable on-hand quantity', () => {
    expect(medicErpSource.mapRow(buildMedicErpRow({ product_name: '  ' }), 2, { today })).toEqual({
      record: null,
      issues: [expect.objectContaining({ severity: 'error', code: 'MISSING_PRODUCT_NAME' })],
    });
    const invalid = medicErpSource.mapRow(buildMedicErpRow({ available_quantity: 'lots' }), 3, {
      today,
    });
    expect(invalid.record).toBeNull();
    expect(codesOf(invalid.issues)).toEqual(['INVALID_NUMBER']);
  });

  it('clamps negative stock and flags contradictory quantities and prices', () => {
    const negative = medicErpSource.mapRow(
      buildMedicErpRow({ available_quantity: -2, quantity: 15 }),
      4,
      { today }
    );
    expect(negative.record.quantity).toBe(0);
    expect(codesOf(negative.issues)).toContain('NEGATIVE_QUANTITY');

    const contradictory = medicErpSource.mapRow(
      buildMedicErpRow({
        available_quantity: 83,
        quantity: 19,
        retail_price: 5000,
        cost: 6000,
        retail_price_max: 100,
      }),
      5,
      { today }
    );
    expect(codesOf(contradictory.issues)).toEqual(
      expect.arrayContaining(['QUANTITY_EXCEEDS_RECEIVED', 'PRICE_BELOW_COST', 'MAX_PRICE_BELOW_PRICE'])
    );
  });

  it('flags expired, invalid, and missing batch metadata', () => {
    const expired = medicErpSource.mapRow(buildMedicErpRow({ expiry_date: '2026-06-30' }), 6, {
      today,
    });
    expect(codesOf(expired.issues)).toEqual(['EXPIRED_BATCH']);

    const invalid = medicErpSource.mapRow(buildMedicErpRow({ expiry_date: '0028-05-05' }), 7, {
      today,
    });
    expect(invalid.record.expiry_date).toBeNull();
    expect(codesOf(invalid.issues)).toEqual(['INVALID_DATE']);

    const unlabeled = medicErpSource.mapRow(
      buildMedicErpRow({ batch_number: '', expiry_date: null }),
      8,
      { today }
    );
    expect(codesOf(unlabeled.issues)).toEqual(['MISSING_BATCH_NUMBER', 'MISSING_EXPIRY_DATE']);
  });
});
