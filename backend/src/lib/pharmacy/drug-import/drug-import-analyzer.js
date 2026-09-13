/**
 * Pharmacy drug import analyzer.
 *
 * Pure planning step shared by preview and commit. It maps source rows, drops
 * exact duplicate rows, groups rows into catalog products (name + brand),
 * reconciles contradictory values inside the file, matches products against
 * the tenant catalog, and proposes an action per product.
 *
 * Commit re-runs the analysis against fresh catalog data and compares the plan
 * hash with the reviewed preview, so nothing is written from a stale review.
 */

const crypto = require('crypto');
const { HttpError } = require('@lib/errors');
const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  textSimilarityScore,
} = require('@lib/tenant/tenant-similarity');
const { checkPharmacyDrugDuplicates } = require('@lib/pharmacy/pharmacy-drug-similarity');
const {
  collapseWhitespace,
  parseDate,
  toIsoDate,
} = require('@lib/pharmacy/drug-import/drug-import-values');

const DRUG_IMPORT_ACTIONS = Object.freeze({
  CREATE: 'CREATE',
  MERGE: 'MERGE',
  UPDATE: 'UPDATE',
  SKIP: 'SKIP',
});

const DRUG_IMPORT_STATUSES = Object.freeze({
  NEW: 'NEW',
  EXISTING: 'EXISTING',
  SIMILAR: 'SIMILAR',
});

const DRUG_IMPORT_STOCK_MODES = Object.freeze({
  REPLACE: 'REPLACE',
  ADD: 'ADD',
});

const UNLABELED_BATCH_NUMBER = 'UNLABELED';
const MAX_CANDIDATES = 5;
const AUTO_MERGE_SCORE = 90;
const MAX_IN_FILE_BUCKET = 60;
const PLAN_HASH_VERSION = 1;

const ALLOWED_ACTIONS = Object.freeze({
  [DRUG_IMPORT_STATUSES.NEW]: [DRUG_IMPORT_ACTIONS.CREATE, DRUG_IMPORT_ACTIONS.SKIP],
  // Creating a second record for an exact catalog match would duplicate it.
  [DRUG_IMPORT_STATUSES.EXISTING]: [
    DRUG_IMPORT_ACTIONS.MERGE,
    DRUG_IMPORT_ACTIONS.UPDATE,
    DRUG_IMPORT_ACTIONS.SKIP,
  ],
  [DRUG_IMPORT_STATUSES.SIMILAR]: [
    DRUG_IMPORT_ACTIONS.CREATE,
    DRUG_IMPORT_ACTIONS.MERGE,
    DRUG_IMPORT_ACTIONS.UPDATE,
    DRUG_IMPORT_ACTIONS.SKIP,
  ],
});

const buildProductKey = (name, brandName) =>
  `${normalizeText(name)}|${normalizeText(brandName)}`;

const compactText = (value) => normalizeText(value).replace(/\s+/g, '');

const normalizeBatchKey = (batchNumber) =>
  String(batchNumber || UNLABELED_BATCH_NUMBER).trim().toUpperCase();

const toMoney = (value) =>
  value == null || value === '' || !Number.isFinite(Number(value))
    ? null
    : Math.round(Number(value) * 100) / 100;

const moneyEquals = (left, right) => toMoney(left) === toMoney(right);

const toTime = (value) => (value instanceof Date ? value.getTime() : 0);

const compareRowsChronologically = (left, right) =>
  toTime(left.source_updated_at) - toTime(right.source_updated_at) ||
  left.row_number - right.row_number;

const productIssue = (key, severity, code, field, params = {}) => ({
  row_number: null,
  product_key: key,
  severity,
  code,
  field,
  params,
});

const buildRowSignature = (record) =>
  JSON.stringify([
    buildProductKey(record.name, record.brand_name),
    normalizeBatchKey(record.batch_number),
    record.quantity,
    record.received_quantity,
    toMoney(record.unit_price),
    toMoney(record.buy_unit_price),
    toIsoDate(record.expiry_date),
    normalizeText(record.supplier_name),
    record.source_updated_at ? record.source_updated_at.toISOString() : null,
  ]);

/**
 * Latest non-empty value across chronologically ordered rows, plus whether rows disagree.
 */
const pickLatest = (rows, field, { equals = (a, b) => a === b, format = (v) => v } = {}) => {
  const distinct = [];
  let latest = null;
  for (const row of rows) {
    const value = row[field];
    if (value == null || value === '') continue;
    latest = value;
    if (!distinct.some((entry) => equals(entry, value))) distinct.push(value);
  }
  return {
    value: latest,
    conflicting: distinct.length > 1,
    values: distinct.map(format),
  };
};

const summarizeBatches = (key, rows, issues) => {
  const byBatch = new Map();
  for (const row of rows) {
    const batchKey = normalizeBatchKey(row.batch_number);
    if (!byBatch.has(batchKey)) byBatch.set(batchKey, []);
    byBatch.get(batchKey).push(row);
  }

  return [...byBatch.entries()]
    .map(([batchKey, batchRows]) => {
      const batchNumber = batchRows[batchRows.length - 1].batch_number || null;
      const label = batchNumber || UNLABELED_BATCH_NUMBER;
      const expiry = pickLatest(batchRows, 'expiry_date', {
        equals: (left, right) => toIsoDate(left) === toIsoDate(right),
        format: toIsoDate,
      });
      if (expiry.conflicting) {
        issues.push(
          productIssue(key, 'warning', 'CONFLICTING_BATCH_EXPIRY', 'expiry_date', {
            batch_number: label,
            values: expiry.values.join(', '),
            chosen: toIsoDate(expiry.value),
          })
        );
      }
      if (batchRows.length > 1) {
        issues.push(
          productIssue(key, 'info', 'BATCH_ROWS_MERGED', 'batch_number', {
            batch_number: label,
            rows: batchRows.length,
          })
        );
      }
      return {
        batch_key: batchKey,
        batch_number: batchNumber,
        expiry_date: expiry.value,
        quantity: batchRows.reduce((total, row) => total + row.quantity, 0),
        row_numbers: batchRows.map((row) => row.row_number).sort((a, b) => a - b),
      };
    })
    .sort((left, right) => left.batch_key.localeCompare(right.batch_key));
};

const summarizeProduct = (key, rows) => {
  const ordered = [...rows].sort(compareRowsChronologically);
  const latest = ordered[ordered.length - 1];
  const issues = [];

  const unitPrice = pickLatest(ordered, 'unit_price', { equals: moneyEquals });
  const buyUnitPrice = pickLatest(ordered, 'buy_unit_price', { equals: moneyEquals });
  const supplier = pickLatest(ordered, 'supplier_name', {
    equals: (left, right) => normalizeText(left) === normalizeText(right),
  });
  const form = pickLatest(ordered, 'form');
  const strength = pickLatest(ordered, 'strength');

  if (unitPrice.conflicting) {
    issues.push(
      productIssue(key, 'warning', 'CONFLICTING_RETAIL_PRICE', 'retail_price', {
        values: unitPrice.values.join(', '),
        chosen: unitPrice.value,
      })
    );
  }
  if (buyUnitPrice.conflicting) {
    issues.push(
      productIssue(key, 'warning', 'CONFLICTING_COST', 'cost', {
        values: buyUnitPrice.values.join(', '),
        chosen: buyUnitPrice.value,
      })
    );
  }
  if (supplier.conflicting) {
    issues.push(
      productIssue(key, 'warning', 'CONFLICTING_SUPPLIER', 'supplier', {
        values: supplier.values.join(', '),
        chosen: supplier.value,
      })
    );
  }

  const batches = summarizeBatches(key, ordered, issues);

  return {
    key,
    name: latest.name,
    generic_name: latest.name,
    brand_name: latest.brand_name || null,
    form: form.value || null,
    strength: strength.value || null,
    unit_price: toMoney(unitPrice.value),
    buy_unit_price: toMoney(buyUnitPrice.value),
    supplier_name: supplier.value || null,
    row_numbers: ordered.map((row) => row.row_number).sort((a, b) => a - b),
    batches,
    total_quantity: batches.reduce((total, batch) => total + batch.quantity, 0),
    issues,
  };
};

const indexTokens = (value) =>
  normalizeText(value)
    .split(' ')
    .filter((token) => token.length >= 3)
    .map((token) => token.slice(0, 4));

const addToList = (map, key, value) => {
  if (!map.has(key)) map.set(key, []);
  map.get(key).push(value);
};

const buildCatalogIndex = (existingDrugs) => {
  const exact = new Map();
  const tokens = new Map();
  const byId = new Map();

  for (const drug of existingDrugs) {
    byId.set(drug.id, drug);
    const brand = normalizeText(drug.brand_name);
    const names = new Set([normalizeText(drug.generic_name), normalizeText(drug.name)]);
    for (const name of names) {
      if (name) addToList(exact, `${name}|${brand}`, drug);
    }
    const drugTokens = new Set([
      ...indexTokens(drug.generic_name),
      ...indexTokens(drug.name),
      ...indexTokens(drug.brand_name),
    ]);
    for (const token of drugTokens) addToList(tokens, token, drug);
  }

  return { exact, tokens, byId };
};

const uniqueById = (drugs) => [...new Map(drugs.map((drug) => [drug.id, drug])).values()];

const buildDrugChanges = (product, drug, { canWritePricing }) => {
  const changes = [];

  const compareText = (field, incoming, current, normalize = normalizeText) => {
    if (!incoming || normalize(incoming) === normalize(current)) return;
    changes.push({
      field,
      current_value: current || null,
      incoming_value: incoming,
      fills_blank: !normalize(current),
    });
  };

  const comparePrice = (field, incoming, current) => {
    if (incoming == null || moneyEquals(incoming, current)) return;
    changes.push({
      field,
      current_value: toMoney(current),
      incoming_value: toMoney(incoming),
      fills_blank: toMoney(current) == null,
    });
  };

  compareText('brand_name', product.brand_name, drug.brand_name);
  compareText('form', product.form, drug.form, compactText);
  compareText('strength', product.strength, drug.strength, compactText);
  if (canWritePricing) {
    comparePrice('unit_price', product.unit_price, drug.unit_price);
    comparePrice('buy_unit_price', product.buy_unit_price, drug.buy_unit_price);
  }
  compareText('supplier_name', product.supplier_name, drug.supplier_name);

  return changes;
};

/**
 * Catalog field updates for linking an imported product to an existing drug.
 *
 * Merge only fills blank fields; update overwrites differing values. Prices and
 * currency are left untouched when the user cannot write pharmacy pricing.
 *
 * @param {Object} product - Analyzed product
 * @param {Object} drug - Existing catalog drug (analyzer shape)
 * @param {Object} options
 * @param {boolean} options.overwrite
 * @param {boolean} options.canWritePricing
 * @param {string|null} [options.currency]
 * @param {string|null} [options.supplierId]
 * @param {string[]} [options.explicitFields] - Reviewer-edited fields; these are applied as
 *   typed (including empty values) whether merging or updating
 * @returns {Object} Prisma update data (empty when nothing changes)
 */
const buildDrugImportPatch = (
  product,
  drug,
  { overwrite, canWritePricing, currency = null, supplierId = null, explicitFields = [] }
) => {
  const explicit = new Set(explicitFields);
  const patch = {};

  const setText = (field, normalize = normalizeText) => {
    const incoming = product[field] || null;
    if (normalize(incoming) === normalize(drug[field])) return;
    if (explicit.has(field)) {
      patch[field] = incoming;
      return;
    }
    if (!incoming) return;
    if (overwrite || !normalize(drug[field])) patch[field] = incoming;
  };
  setText('brand_name');
  setText('form', compactText);
  setText('strength', compactText);

  if (canWritePricing) {
    for (const field of ['unit_price', 'buy_unit_price']) {
      const incoming = toMoney(product[field]);
      if (moneyEquals(incoming, drug[field])) continue;
      if (explicit.has(field)) {
        patch[field] = incoming;
        continue;
      }
      if (incoming == null) continue;
      if (overwrite || toMoney(drug[field]) == null) patch[field] = incoming;
    }
    const setsPrice = patch.unit_price != null || patch.buy_unit_price != null;
    if (currency && setsPrice && currency !== drug.currency && (overwrite || !drug.currency)) {
      patch.currency = currency;
    }
  }

  const setsSupplier = explicit.has('supplier_name')
    ? (supplierId || null) !== (drug.supplier_id || null)
    : Boolean(supplierId) && supplierId !== drug.supplier_id && (overwrite || !drug.supplier_id);
  if (setsSupplier) {
    patch.supplier_id = supplierId || null;
  }

  return patch;
};

const matchProduct = (product, index) => {
  const exactMatches = uniqueById(index.exact.get(product.key) || []);
  if (exactMatches.length === 1) {
    return { status: DRUG_IMPORT_STATUSES.EXISTING, match: exactMatches[0], candidates: [] };
  }
  if (exactMatches.length > 1) {
    product.issues.push(
      productIssue(product.key, 'warning', 'AMBIGUOUS_EXISTING_MATCH', null, {
        count: exactMatches.length,
      })
    );
    return {
      status: DRUG_IMPORT_STATUSES.SIMILAR,
      match: null,
      candidates: exactMatches.slice(0, MAX_CANDIDATES).map((drug) => ({
        drug,
        score: 100,
        brand_score: 100,
        reasons: ['generic_name', 'brand_name'],
      })),
    };
  }

  // Only score catalog drugs sharing a name/brand token prefix; comparing every
  // product with the whole catalog is quadratic and rarely adds real matches.
  const pool = new Map();
  for (const token of new Set([...indexTokens(product.name), ...indexTokens(product.brand_name)])) {
    for (const drug of index.tokens.get(token) || []) pool.set(drug.id, drug);
  }
  if (!pool.size) {
    return { status: DRUG_IMPORT_STATUSES.NEW, match: null, candidates: [] };
  }

  const duplicateCheck = checkPharmacyDrugDuplicates({
    name: product.name,
    genericName: product.generic_name,
    brandName: product.brand_name,
    form: product.form,
    strength: product.strength,
    existing: [...pool.values()],
  });
  const candidates = duplicateCheck.similarMatches
    .slice(0, MAX_CANDIDATES)
    .map((match) => ({
      drug: index.byId.get(match.drug.id),
      score: match.score,
      brand_score: match.brand_score,
      reasons: match.reasons,
    }))
    .filter((candidate) => candidate.drug);

  if (!candidates.length) {
    return { status: DRUG_IMPORT_STATUSES.NEW, match: null, candidates: [] };
  }
  return { status: DRUG_IMPORT_STATUSES.SIMILAR, match: null, candidates };
};

const suggestDefaults = (product) => {
  if (product.status === DRUG_IMPORT_STATUSES.NEW) {
    return { action: DRUG_IMPORT_ACTIONS.CREATE, target: null };
  }
  if (product.status === DRUG_IMPORT_STATUSES.EXISTING) {
    return { action: DRUG_IMPORT_ACTIONS.MERGE, target: product.match };
  }
  const best = product.candidates[0];
  const sameBrand =
    normalizeText(product.brand_name) === normalizeText(best.drug.brand_name) ||
    (best.brand_score != null && best.brand_score >= SIMILARITY_THRESHOLD);
  if (best.score >= AUTO_MERGE_SCORE && sameBrand) {
    return { action: DRUG_IMPORT_ACTIONS.MERGE, target: best.drug };
  }
  return { action: DRUG_IMPORT_ACTIONS.CREATE, target: null };
};

const attributesDiffer = (left, right) =>
  ['form', 'strength'].some(
    (field) =>
      compactText(left[field]) &&
      compactText(right[field]) &&
      compactText(left[field]) !== compactText(right[field])
  );

const flagSimilarProductsInFile = (products) => {
  const flagged = new Set();
  const flagPair = (left, right) => {
    const pairKey = [left.key, right.key].sort().join(' ');
    if (flagged.has(pairKey)) return;
    flagged.add(pairKey);
    for (const [product, other] of [
      [left, right],
      [right, left],
    ]) {
      product.issues.push(
        productIssue(product.key, 'warning', 'SIMILAR_PRODUCT_IN_FILE', null, {
          name: other.name,
          brand_name: other.brand_name || '',
          rows: other.row_numbers.slice(0, 5).join(', '),
        })
      );
    }
  };

  const scanBuckets = (bucketKeyOf, compareField) => {
    const buckets = new Map();
    for (const product of products) {
      const bucketKey = bucketKeyOf(product);
      if (bucketKey) addToList(buckets, bucketKey, product);
    }
    for (const bucket of buckets.values()) {
      if (bucket.length < 2 || bucket.length > MAX_IN_FILE_BUCKET) continue;
      for (let i = 0; i < bucket.length; i += 1) {
        for (let j = i + 1; j < bucket.length; j += 1) {
          const left = bucket[i];
          const right = bucket[j];
          const leftValue = normalizeText(left[compareField]);
          const rightValue = normalizeText(right[compareField]);
          if (!leftValue || !rightValue || attributesDiffer(left, right)) continue;
          if (textSimilarityScore(leftValue, rightValue) >= SIMILARITY_THRESHOLD) {
            flagPair(left, right);
          }
        }
      }
    }
  };

  scanBuckets((product) => normalizeText(product.name), 'brand_name');
  scanBuckets((product) => normalizeText(product.brand_name), 'name');
};

const hashPlan = ({ products, stockedDrugs, canWritePricing }) =>
  crypto
    .createHash('sha256')
    .update(
      JSON.stringify({
        version: PLAN_HASH_VERSION,
        can_write_pricing: canWritePricing,
        products: products.map((product) => [
          product.key,
          product.status,
          product.match?.id || null,
          product.candidates.map((candidate) => candidate.drug.id),
          product.unit_price,
          product.buy_unit_price,
          product.supplier_name,
          product.batches.map((batch) => [
            batch.batch_key,
            batch.quantity,
            toIsoDate(batch.expiry_date),
          ]),
        ]),
        stocked_drug_ids: stockedDrugs.map((drug) => drug.id),
      })
    )
    .digest('hex');

/**
 * Analyze mapped import rows against the tenant catalog.
 *
 * @param {Object} params
 * @param {Object} params.source - Import source definition (see drug-import-sources)
 * @param {Array<{ row_number: number, values: Object }>} params.rows - Workbook rows
 * @param {Array<Object>} params.existingDrugs - Tenant drugs: id, human_friendly_id, name,
 *   generic_name, brand_name, form, strength, unit_price, buy_unit_price, supplier_name,
 *   facility_quantity
 * @param {boolean} params.canWritePricing - Whether prices may be imported
 * @param {Date} [params.today]
 * @returns {Object} Import plan
 */
const analyzeDrugImport = ({
  source,
  rows = [],
  existingDrugs = [],
  canWritePricing = false,
  today = new Date(),
}) => {
  const issues = [];
  const records = [];
  let errorRows = 0;

  for (const row of rows) {
    const mapped = source.mapRow(row.values, row.row_number, { today });
    const productKey = mapped.record
      ? buildProductKey(mapped.record.name, mapped.record.brand_name)
      : null;
    mapped.issues.forEach((issue) => issues.push({ ...issue, product_key: productKey }));
    if (mapped.record) {
      records.push(mapped.record);
    } else {
      errorRows += 1;
    }
  }

  const firstRowBySignature = new Map();
  const groups = new Map();
  let duplicateRows = 0;
  for (const record of records) {
    const signature = buildRowSignature(record);
    const key = buildProductKey(record.name, record.brand_name);
    if (firstRowBySignature.has(signature)) {
      duplicateRows += 1;
      issues.push({
        row_number: record.row_number,
        product_key: key,
        severity: 'warning',
        code: 'DUPLICATE_ROW',
        field: null,
        params: { duplicate_of_row: firstRowBySignature.get(signature) },
      });
      continue;
    }
    firstRowBySignature.set(signature, record.row_number);
    addToList(groups, key, record);
  }

  const index = buildCatalogIndex(existingDrugs);
  const products = [...groups.entries()].map(([key, groupRows]) => {
    const product = summarizeProduct(key, groupRows);
    const { status, match, candidates } = matchProduct(product, index);
    product.status = status;
    product.match = match;
    product.candidates = candidates;
    if (match) {
      product.changes = buildDrugChanges(product, match, { canWritePricing });
    }
    for (const candidate of candidates) {
      candidate.changes = buildDrugChanges(product, candidate.drug, { canWritePricing });
    }
    const defaults = suggestDefaults(product);
    product.allowed_actions = ALLOWED_ACTIONS[status];
    product.default_action = defaults.action;
    product.default_target = defaults.target;
    product.requires_review = status === DRUG_IMPORT_STATUSES.SIMILAR;
    return product;
  });

  flagSimilarProductsInFile(products);
  products.sort(
    (left, right) =>
      left.name.localeCompare(right.name) ||
      String(left.brand_name || '').localeCompare(String(right.brand_name || ''))
  );

  const exactlyMatchedIds = new Set(
    products.filter((product) => product.match).map((product) => product.match.id)
  );
  const stockedDrugs = existingDrugs
    .filter((drug) => Number(drug.facility_quantity || 0) > 0 && !exactlyMatchedIds.has(drug.id))
    .sort((left, right) => String(left.name || '').localeCompare(String(right.name || '')));

  const allIssues = [...issues, ...products.flatMap((product) => product.issues)];
  const countStatus = (status) => products.filter((product) => product.status === status).length;

  return {
    plan_hash: hashPlan({ products, stockedDrugs, canWritePricing }),
    can_write_pricing: canWritePricing,
    summary: {
      total_rows: rows.length,
      valid_rows: records.length - duplicateRows,
      error_rows: errorRows,
      duplicate_rows: duplicateRows,
      products: products.length,
      new_products: countStatus(DRUG_IMPORT_STATUSES.NEW),
      existing_products: countStatus(DRUG_IMPORT_STATUSES.EXISTING),
      similar_products: countStatus(DRUG_IMPORT_STATUSES.SIMILAR),
      batches: products.reduce((total, product) => total + product.batches.length, 0),
      total_quantity: products.reduce((total, product) => total + product.total_quantity, 0),
      errors: allIssues.filter((issue) => issue.severity === 'error').length,
      warnings: allIssues.filter((issue) => issue.severity === 'warning').length,
      stocked_not_in_file: stockedDrugs.length,
    },
    products,
    issues,
    stocked_drugs: stockedDrugs,
  };
};

const matchesDrugIdentifier = (drug, identifier) => {
  const normalized = String(identifier || '').trim().toUpperCase();
  return (
    Boolean(normalized) &&
    [drug?.id, drug?.human_friendly_id].some(
      (value) => String(value || '').trim().toUpperCase() === normalized
    )
  );
};

const invalidDecision = (key) =>
  new HttpError('errors.pharmacy_drug_import.invalid_decision', 400, [
    { field: 'decisions', key },
  ]);

const EDITABLE_TEXT_FIELDS = Object.freeze(['brand_name', 'form', 'strength', 'supplier_name']);
const EDITABLE_PRICE_FIELDS = Object.freeze(['unit_price', 'buy_unit_price']);

const hasOwn = (object, field) => Object.prototype.hasOwnProperty.call(object, field);

/**
 * Apply reviewer edits from a decision to a copy of the analyzed product.
 *
 * A present value is the final value for that field, including an empty one.
 * The name only changes for new drugs, so linking never renames a catalog drug.
 * Edited batches carry their full final values and are matched by batch key.
 *
 * @param {Object} product - Analyzed product
 * @param {Object|undefined} decision - Client decision with optional `values` and `batches`
 * @param {string} action - Resolved action
 * @returns {{ product: Object, editedFields: string[] }}
 * @throws {HttpError} 400 for unknown or repeated batch keys, invalid dates, or clashing batches
 */
const applyDrugImportEdits = (product, decision, action) => {
  const values = decision?.values || {};
  const batchEdits = decision?.batches || [];
  const editedFields = [];
  if (
    action === DRUG_IMPORT_ACTIONS.SKIP ||
    (!Object.keys(values).length && !batchEdits.length)
  ) {
    return { product, editedFields };
  }

  const edited = { ...product };
  if (action === DRUG_IMPORT_ACTIONS.CREATE && hasOwn(values, 'name')) {
    const name = collapseWhitespace(values.name);
    if (!name) throw invalidDecision(product.key);
    edited.name = name;
    edited.generic_name = name;
    editedFields.push('name');
  }
  for (const field of EDITABLE_TEXT_FIELDS) {
    if (!hasOwn(values, field)) continue;
    edited[field] = collapseWhitespace(values[field]);
    editedFields.push(field);
  }
  for (const field of EDITABLE_PRICE_FIELDS) {
    if (!hasOwn(values, field)) continue;
    edited[field] = toMoney(values[field]);
    editedFields.push(field);
  }

  if (batchEdits.length) {
    const batchKeys = new Set(product.batches.map((batch) => batch.batch_key));
    const editsByKey = new Map();
    for (const edit of batchEdits) {
      const key = normalizeBatchKey(edit.key);
      if (!batchKeys.has(key) || editsByKey.has(key)) throw invalidDecision(product.key);
      editsByKey.set(key, edit);
    }

    edited.batches = product.batches.map((batch) => {
      const edit = editsByKey.get(batch.batch_key);
      if (!edit) return batch;
      const expiry = parseDate(edit.expiry_date);
      if (expiry.invalid) throw invalidDecision(product.key);
      const batchNumber = collapseWhitespace(edit.batch_number);
      return {
        ...batch,
        batch_key: normalizeBatchKey(batchNumber),
        batch_number: batchNumber,
        expiry_date: expiry.value,
        quantity: edit.quantity,
      };
    });
    const finalKeys = new Set(edited.batches.map((batch) => batch.batch_key));
    if (finalKeys.size !== edited.batches.length) throw invalidDecision(product.key);
    edited.total_quantity = edited.batches.reduce((total, batch) => total + batch.quantity, 0);
    editedFields.push('batches');
  }

  return { product: edited, editedFields };
};

/**
 * Apply client decisions to an analyzed plan, falling back to defaults.
 *
 * Merge/update targets must be the exact match or one of the reviewed
 * candidates, so a decision can never link to an arbitrary catalog drug.
 * Reviewer edits are applied to copies of the products (see applyDrugImportEdits).
 *
 * @param {Array<Object>} products - Analyzed products
 * @param {Array<{ key: string, action: string, target_drug_id?: string|null,
 *   values?: Object, batches?: Array<Object> }>} decisions
 * @returns {Array<{ product: Object, action: string, target: Object|null, edited_fields: string[] }>}
 * @throws {HttpError} 400 for unknown keys, duplicate keys, disallowed actions/targets, or bad edits
 */
const resolveDrugImportDecisions = (products, decisions = []) => {
  const byKey = new Map();
  for (const decision of decisions || []) {
    if (byKey.has(decision.key)) throw invalidDecision(decision.key);
    byKey.set(decision.key, decision);
  }
  const productKeys = new Set(products.map((product) => product.key));
  for (const key of byKey.keys()) {
    if (!productKeys.has(key)) throw invalidDecision(key);
  }

  return products.map((product) => {
    const decision = byKey.get(product.key);
    const action = decision?.action || product.default_action;
    if (!product.allowed_actions.includes(action)) throw invalidDecision(product.key);
    const { product: edited, editedFields } = applyDrugImportEdits(product, decision, action);

    if (action !== DRUG_IMPORT_ACTIONS.MERGE && action !== DRUG_IMPORT_ACTIONS.UPDATE) {
      return { product: edited, action, target: null, edited_fields: editedFields };
    }

    const options = product.match
      ? [product.match]
      : product.candidates.map((candidate) => candidate.drug);
    const target = decision?.target_drug_id
      ? options.find((drug) => matchesDrugIdentifier(drug, decision.target_drug_id))
      : product.default_target || options[0] || null;
    if (!target) throw invalidDecision(product.key);
    return { product: edited, action, target, edited_fields: editedFields };
  });
};

/**
 * Reject reviewer renames that would create a drug the catalog or this import already has.
 *
 * Unedited new products cannot clash: the analyzer groups rows by name and
 * brand and matches each group against the catalog first.
 *
 * @param {Array<{ product: Object, action: string, edited_fields?: string[] }>} resolvedDecisions
 * @param {Array<Object>} existingDrugs - Tenant drugs (analyzer shape)
 * @throws {HttpError} 400 when an edited new product duplicates another drug
 */
const assertUniqueCreatedProducts = (resolvedDecisions, existingDrugs = []) => {
  const creates = resolvedDecisions.filter((entry) => entry.action === DRUG_IMPORT_ACTIONS.CREATE);
  const renamed = creates.filter((entry) =>
    (entry.edited_fields || []).some((field) => field === 'name' || field === 'brand_name')
  );
  if (!renamed.length) return;

  const { exact } = buildCatalogIndex(existingDrugs);
  const createsByKey = new Map();
  for (const entry of creates) {
    addToList(createsByKey, buildProductKey(entry.product.name, entry.product.brand_name), entry);
  }
  for (const entry of renamed) {
    const key = buildProductKey(entry.product.name, entry.product.brand_name);
    if (exact.has(key) || createsByKey.get(key).length > 1) {
      throw new HttpError('errors.pharmacy_drug_import.duplicate_product', 400, [
        {
          field: 'decisions',
          key: entry.product.key,
          name: entry.product.name,
          brand_name: entry.product.brand_name,
        },
      ]);
    }
  }
};

/**
 * Drugs stocked at the facility that no import decision links to.
 *
 * @param {Array<Object>} stockedDrugs - `plan.stocked_drugs`
 * @param {Array<{ action: string, target: Object|null }>} resolvedDecisions
 * @returns {Array<Object>}
 */
const resolveMissingStockDrugs = (stockedDrugs, resolvedDecisions) => {
  const linkedIds = new Set(
    resolvedDecisions.filter((entry) => entry.target).map((entry) => entry.target.id)
  );
  return stockedDrugs.filter((drug) => !linkedIds.has(drug.id));
};

module.exports = {
  DRUG_IMPORT_ACTIONS,
  DRUG_IMPORT_STATUSES,
  DRUG_IMPORT_STOCK_MODES,
  UNLABELED_BATCH_NUMBER,
  buildProductKey,
  buildDrugImportPatch,
  analyzeDrugImport,
  assertUniqueCreatedProducts,
  resolveDrugImportDecisions,
  resolveMissingStockDrugs,
};
