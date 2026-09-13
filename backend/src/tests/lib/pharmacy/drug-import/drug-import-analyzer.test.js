const medicErpSource = require('@lib/pharmacy/drug-import/sources/medic-erp.source');
const { HttpError } = require('@lib/errors');
const { toIsoDate } = require('@lib/pharmacy/drug-import/drug-import-values');
const {
  analyzeDrugImport,
  assertUniqueCreatedProducts,
  buildDrugImportPatch,
  buildProductKey,
  resolveDrugImportDecisions,
  resolveMissingStockDrugs,
} = require('@lib/pharmacy/drug-import/drug-import-analyzer');
const { buildMedicErpRow } = require('./medic-erp-workbook.fixture');

const today = new Date('2026-09-13T00:00:00.000Z');

const analyze = (rowOverrides, options = {}) =>
  analyzeDrugImport({
    source: medicErpSource,
    rows: rowOverrides.map((overrides, index) => ({
      row_number: index + 2,
      values: buildMedicErpRow(overrides),
    })),
    existingDrugs: [],
    canWritePricing: true,
    today,
    ...options,
  });

const findProduct = (plan, name, brand) =>
  plan.products.find((product) => product.key === buildProductKey(name, brand));

const codesOf = (issues) => issues.map((issue) => issue.code);

const zahaDrug = {
  id: 'drug-uuid-1',
  human_friendly_id: 'DRG0000001',
  name: 'AZITHROMYCIN 500MG TABLET',
  generic_name: 'Azithromycin 500mg Tablet',
  brand_name: 'Zaha',
  form: null,
  strength: '500 mg',
  unit_price: 6000,
  buy_unit_price: null,
  supplier_name: null,
  facility_quantity: 12,
};

describe('drug-import-analyzer', () => {
  describe('analyzeDrugImport', () => {
    it('groups rows into products by name and brand, keeping the latest values', () => {
      const plan = analyze([
        { batch_number: 'PA09025', available_quantity: 4 },
        {
          product_name: 'azithromycin 500mg tablet',
          batch_number: 'PAD31015',
          available_quantity: 5,
          retail_price: 7500,
          updated_on: '2026-07-11T00:00:00.000Z',
        },
        { product_brand: 'SWAZI', batch_number: 'BG10425', available_quantity: 8 },
      ]);

      expect(plan.summary).toMatchObject({
        total_rows: 3,
        valid_rows: 3,
        products: 2,
        new_products: 2,
        batches: 3,
        total_quantity: 17,
      });

      const zaha = findProduct(plan, 'AZITHROMYCIN 500MG TABLET', 'ZAHA');
      expect(zaha).toMatchObject({
        name: 'azithromycin 500mg tablet',
        unit_price: 7500,
        total_quantity: 9,
        status: 'NEW',
        default_action: 'CREATE',
        allowed_actions: ['CREATE', 'SKIP'],
        requires_review: false,
      });
      expect(zaha.batches.map((batch) => [batch.batch_number, batch.quantity])).toEqual([
        ['PA09025', 4],
        ['PAD31015', 5],
      ]);
      expect(zaha.issues).toEqual([
        expect.objectContaining({
          code: 'CONFLICTING_RETAIL_PRICE',
          params: { values: '7000, 7500', chosen: 7500 },
        }),
      ]);
    });

    it('drops exact duplicate rows and merges repeated batches', () => {
      const plan = analyze([
        { batch_number: 'PA09025', available_quantity: 4 },
        { batch_number: 'PA09025', available_quantity: 4 },
        {
          batch_number: 'pa09025',
          available_quantity: 3,
          expiry_date: '2028-06-30',
          updated_on: '2026-08-01T00:00:00.000Z',
        },
      ]);

      expect(plan.summary).toMatchObject({ duplicate_rows: 1, valid_rows: 2, batches: 1 });
      expect(plan.issues).toContainEqual(
        expect.objectContaining({
          row_number: 3,
          code: 'DUPLICATE_ROW',
          params: { duplicate_of_row: 2 },
        })
      );

      const [product] = plan.products;
      expect(product.batches).toHaveLength(1);
      expect(product.batches[0]).toMatchObject({
        batch_number: 'pa09025',
        quantity: 7,
        row_numbers: [2, 4],
      });
      expect(toIsoDate(product.batches[0].expiry_date)).toBe('2028-06-30');
      expect(codesOf(product.issues)).toEqual(['CONFLICTING_BATCH_EXPIRY', 'BATCH_ROWS_MERGED']);
    });

    it('links exact catalog matches and lists the edits they would bring', () => {
      const plan = analyze([{}], { existingDrugs: [zahaDrug] });
      const [product] = plan.products;

      expect(product).toMatchObject({
        status: 'EXISTING',
        default_action: 'MERGE',
        allowed_actions: ['MERGE', 'UPDATE', 'SKIP'],
        requires_review: false,
      });
      expect(product.match.id).toBe('drug-uuid-1');
      expect(product.changes).toEqual([
        { field: 'form', current_value: null, incoming_value: 'Tablet', fills_blank: true },
        { field: 'unit_price', current_value: 6000, incoming_value: 7000, fills_blank: false },
        { field: 'buy_unit_price', current_value: null, incoming_value: 4300, fills_blank: true },
      ]);
      expect(plan.stocked_drugs).toEqual([]);
    });

    it('hides price edits when the user cannot write pharmacy pricing', () => {
      const plan = analyze([{}], { existingDrugs: [zahaDrug], canWritePricing: false });
      expect(plan.products[0].changes.map((change) => change.field)).toEqual(['form']);
    });

    it('asks for review when a product resembles catalog drugs', () => {
      const amoxil = {
        id: 'drug-amox',
        human_friendly_id: 'DRG0000002',
        name: 'Amoxicillin',
        generic_name: 'Amoxicillin',
        brand_name: 'Amoxil',
        form: 'Capsule',
        strength: '500 mg',
        facility_quantity: 0,
      };
      const plan = analyze(
        [
          { product_name: 'AMOXICILLIN 500MG CAPSULE', product_brand: 'AMOXIL' },
          { product_name: 'AMOXICILLIN 500MG CAPSULE', product_brand: 'MOXACIL', batch_number: 'X1' },
        ],
        { existingDrugs: [amoxil] }
      );

      const sameBrand = findProduct(plan, 'AMOXICILLIN 500MG CAPSULE', 'AMOXIL');
      expect(sameBrand).toMatchObject({
        status: 'SIMILAR',
        requires_review: true,
        default_action: 'MERGE',
        allowed_actions: ['CREATE', 'MERGE', 'UPDATE', 'SKIP'],
      });
      expect(sameBrand.default_target.id).toBe('drug-amox');
      expect(sameBrand.candidates[0].drug.id).toBe('drug-amox');

      const otherBrand = findProduct(plan, 'AMOXICILLIN 500MG CAPSULE', 'MOXACIL');
      expect(otherBrand.default_action).toBe('CREATE');
    });

    it('treats duplicate catalog records as an ambiguous match needing review', () => {
      const plan = analyze([{}], {
        existingDrugs: [zahaDrug, { ...zahaDrug, id: 'drug-uuid-2', human_friendly_id: 'DRG0000009' }],
      });
      const [product] = plan.products;

      expect(product.status).toBe('SIMILAR');
      expect(product.candidates.map((candidate) => candidate.drug.id)).toEqual([
        'drug-uuid-1',
        'drug-uuid-2',
      ]);
      expect(codesOf(product.issues)).toContain('AMBIGUOUS_EXISTING_MATCH');
    });

    it('flags near-duplicate products inside the file unless strengths differ', () => {
      const plan = analyze([
        { product_brand: 'ZAHA' },
        { product_brand: 'ZAHA - 500', batch_number: 'PAD31015' },
        { product_name: 'RELCER GEL SYRUP 100ML', product_brand: 'RELCER SYP', batch_number: 'R1' },
        { product_name: 'RELCER GEL SYRUP 180ML', product_brand: 'RELCER SYP', batch_number: 'R2' },
      ]);

      const zaha = findProduct(plan, 'AZITHROMYCIN 500MG TABLET', 'ZAHA');
      expect(zaha.issues).toContainEqual(
        expect.objectContaining({
          code: 'SIMILAR_PRODUCT_IN_FILE',
          params: expect.objectContaining({ brand_name: 'ZAHA - 500' }),
        })
      );
      const relcer = findProduct(plan, 'RELCER GEL SYRUP 100ML', 'RELCER SYP');
      expect(codesOf(relcer.issues)).not.toContain('SIMILAR_PRODUCT_IN_FILE');
    });

    it('lists stocked catalog drugs that the file does not mention', () => {
      const plan = analyze([{}], {
        existingDrugs: [
          { ...zahaDrug, facility_quantity: 3 },
          { id: 'drug-old', human_friendly_id: 'DRG0000003', name: 'Old Syrup', facility_quantity: 9 },
          { id: 'drug-empty', human_friendly_id: 'DRG0000004', name: 'Empty Cream', facility_quantity: 0 },
        ],
      });

      expect(plan.stocked_drugs.map((drug) => drug.id)).toEqual(['drug-old']);
      expect(plan.summary.stocked_not_in_file).toBe(1);

      const resolved = resolveDrugImportDecisions(plan.products, []);
      expect(resolveMissingStockDrugs(plan.stocked_drugs, resolved).map((drug) => drug.id)).toEqual([
        'drug-old',
      ]);
    });

    it('produces a stable plan hash that changes with the file or the catalog', () => {
      const first = analyze([{}], { existingDrugs: [zahaDrug] });

      expect(first.plan_hash).toMatch(/^[a-f0-9]{64}$/);
      expect(analyze([{}], { existingDrugs: [zahaDrug] }).plan_hash).toBe(first.plan_hash);
      expect(analyze([{ available_quantity: 5 }], { existingDrugs: [zahaDrug] }).plan_hash).not.toBe(
        first.plan_hash
      );
      expect(analyze([{}], { existingDrugs: [] }).plan_hash).not.toBe(first.plan_hash);
    });
  });

  describe('resolveDrugImportDecisions', () => {
    const plan = analyze([{}, { product_brand: 'NEW BRAND', batch_number: 'N1' }], {
      existingDrugs: [{ ...zahaDrug, strength: null }],
    });
    const existingKey = buildProductKey('AZITHROMYCIN 500MG TABLET', 'ZAHA');
    const newKey = buildProductKey('AZITHROMYCIN 500MG TABLET', 'NEW BRAND');

    it('rejects unknown keys, duplicate keys, disallowed actions, and unreviewed targets', () => {
      const attempts = [
        [{ key: 'unknown|key', action: 'CREATE' }],
        [{ key: existingKey, action: 'CREATE' }],
        [{ key: existingKey, action: 'UPDATE', target_drug_id: 'DRG9999999' }],
        [
          { key: newKey, action: 'SKIP' },
          { key: newKey, action: 'CREATE' },
        ],
      ];
      for (const decisions of attempts) {
        expect(() => resolveDrugImportDecisions(plan.products, decisions)).toThrow(HttpError);
      }
    });

    it('applies decisions by key and falls back to defaults', () => {
      const resolved = resolveDrugImportDecisions(plan.products, [
        { key: existingKey, action: 'UPDATE', target_drug_id: 'drg0000001' },
      ]);

      expect(
        resolved.map((entry) => [entry.product.key, entry.action, entry.target?.id ?? null])
      ).toEqual(
        expect.arrayContaining([
          [existingKey, 'UPDATE', 'drug-uuid-1'],
          [newKey, plan.products.find((product) => product.key === newKey).default_action, null],
        ])
      );
    });
  });

  describe('buildDrugImportPatch', () => {
    const product = {
      brand_name: 'ZAHA',
      form: 'Tablet',
      strength: '500 mg',
      unit_price: 7000,
      buy_unit_price: 4300,
    };
    const drug = {
      brand_name: 'Zaha',
      form: null,
      strength: '250 mg',
      unit_price: 6000,
      buy_unit_price: null,
      currency: null,
      supplier_id: 'supplier-1',
    };

    it('merge fills blank fields only', () => {
      expect(
        buildDrugImportPatch(product, drug, {
          overwrite: false,
          canWritePricing: true,
          currency: 'UGX',
          supplierId: 'supplier-2',
        })
      ).toEqual({ form: 'Tablet', buy_unit_price: 4300, currency: 'UGX' });
    });

    it('update overwrites differing values', () => {
      expect(
        buildDrugImportPatch(product, drug, {
          overwrite: true,
          canWritePricing: true,
          currency: 'UGX',
          supplierId: 'supplier-2',
        })
      ).toEqual({
        form: 'Tablet',
        strength: '500 mg',
        unit_price: 7000,
        buy_unit_price: 4300,
        currency: 'UGX',
        supplier_id: 'supplier-2',
      });
    });

    it('never touches prices without pricing permission', () => {
      expect(
        buildDrugImportPatch(product, drug, { overwrite: true, canWritePricing: false, currency: 'UGX' })
      ).toEqual({ form: 'Tablet', strength: '500 mg' });
    });

    it('applies reviewer-edited fields as typed, even when merging or clearing', () => {
      expect(
        buildDrugImportPatch({ ...product, brand_name: null, unit_price: null }, drug, {
          overwrite: false,
          canWritePricing: true,
          supplierId: null,
          explicitFields: ['brand_name', 'strength', 'unit_price', 'supplier_name'],
        })
      ).toEqual({
        brand_name: null,
        form: 'Tablet',
        strength: '500 mg',
        unit_price: null,
        buy_unit_price: 4300,
        supplier_id: null,
      });
    });
  });

  describe('reviewer edits', () => {
    const plan = analyze([
      { product_name: 'CIPROFLOXACIN 500MG', product_brand: 'CIPRO', batch_number: 'A1' },
      { product_name: 'CIPROFLOXACIN 500MG', product_brand: 'CIPRO', batch_number: 'B1' },
      { product_name: 'CIPROFLOXACIN 500MG', product_brand: 'CIPRONEX', batch_number: 'N1' },
    ]);
    const ciproKey = buildProductKey('CIPROFLOXACIN 500MG', 'CIPRO');
    const cipronexKey = buildProductKey('CIPROFLOXACIN 500MG', 'CIPRONEX');
    const editCiprox = (edits, others = []) =>
      resolveDrugImportDecisions(plan.products, [
        { key: cipronexKey, action: 'CREATE', ...edits },
        ...others,
      ]);

    it('applies edits to copies of the products', () => {
      const [cipro, ciprox] = resolveDrugImportDecisions(plan.products, [
        {
          key: cipronexKey,
          action: 'CREATE',
          values: { name: '  Ciprofloxacin 500 mg ', brand_name: 'Ciproflox', unit_price: 8000 },
          batches: [{ key: 'n1', batch_number: 'N1-A', expiry_date: '2029-01-31', quantity: 12 }],
        },
        { key: ciproKey, action: 'SKIP', values: { form: 'Capsule' } },
      ]);

      expect(ciprox.product).toMatchObject({
        name: 'Ciprofloxacin 500 mg',
        generic_name: 'Ciprofloxacin 500 mg',
        brand_name: 'Ciproflox',
        unit_price: 8000,
        total_quantity: 12,
      });
      expect(ciprox.product.batches).toEqual([
        expect.objectContaining({ batch_key: 'N1-A', batch_number: 'N1-A', quantity: 12 }),
      ]);
      expect(toIsoDate(ciprox.product.batches[0].expiry_date)).toBe('2029-01-31');
      expect(ciprox.edited_fields).toEqual(['name', 'brand_name', 'unit_price', 'batches']);
      expect(cipro.edited_fields).toEqual([]);
      expect(findProduct(plan, 'CIPROFLOXACIN 500MG', 'CIPRONEX').brand_name).toBe('CIPRONEX');
    });

    it('never renames a catalog drug that a product links to', () => {
      const linkedPlan = analyze([{}], { existingDrugs: [zahaDrug] });
      const [entry] = resolveDrugImportDecisions(linkedPlan.products, [
        { key: linkedPlan.products[0].key, action: 'UPDATE', values: { name: 'Renamed', form: 'Capsule' } },
      ]);

      expect(entry.product).toMatchObject({ name: 'AZITHROMYCIN 500MG TABLET', form: 'Capsule' });
      expect(entry.edited_fields).toEqual(['form']);
    });

    it('rejects unknown, repeated, or clashing batch edits and invalid values', () => {
      const attempts = [
        { batches: [{ key: 'MISSING', batch_number: 'X', expiry_date: null, quantity: 1 }] },
        {
          batches: [
            { key: 'N1', batch_number: 'X', expiry_date: null, quantity: 1 },
            { key: 'n1', batch_number: 'Y', expiry_date: null, quantity: 1 },
          ],
        },
        { batches: [{ key: 'N1', batch_number: 'N1', expiry_date: '2029-02-30', quantity: 1 }] },
        { values: { name: '   ' } },
      ];
      for (const edits of attempts) {
        expect(() => editCiprox(edits)).toThrow(HttpError);
      }
      expect(() =>
        resolveDrugImportDecisions(plan.products, [
          {
            key: ciproKey,
            action: 'CREATE',
            batches: [{ key: 'B1', batch_number: 'a1', expiry_date: null, quantity: 3 }],
          },
        ])
      ).toThrow(HttpError);
    });

    it('rejects renamed new products that duplicate the catalog or another new product', () => {
      const duplicate = 'errors.pharmacy_drug_import.duplicate_product';
      const catalogCipro = { id: 'drug-cipro', name: 'Ciprofloxacin 500mg', brand_name: 'Ciproflox' };

      expect(() => assertUniqueCreatedProducts(editCiprox({ values: { brand_name: 'cipro' } }), [])).toThrow(
        duplicate
      );
      expect(() =>
        assertUniqueCreatedProducts(editCiprox({ values: { brand_name: 'Ciproflox' } }), [catalogCipro])
      ).toThrow(duplicate);
      expect(() =>
        assertUniqueCreatedProducts(editCiprox({ values: { brand_name: 'Ciproflox' } }), [])
      ).not.toThrow();
      expect(() =>
        assertUniqueCreatedProducts(
          editCiprox({ values: { brand_name: 'CIPRO' } }, [{ key: ciproKey, action: 'SKIP' }]),
          []
        )
      ).not.toThrow();
    });
  });
});
