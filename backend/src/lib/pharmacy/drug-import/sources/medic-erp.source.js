/**
 * Medic-ERP stock export ("Stock" sheet).
 *
 * Each row is one stock entry — a batch of a product. Rows sharing a product
 * name and brand are grouped into one catalog drug by the import analyzer.
 * `available_quantity` is the on-hand balance; `quantity` is what was received.
 */

const {
  collapseWhitespace,
  parseNumber,
  parseDate,
  toIsoDate,
  startOfUtcDay,
} = require('@lib/pharmacy/drug-import/drug-import-values');
const {
  inferDosageForm,
  inferStrength,
} = require('@lib/pharmacy/drug-import/drug-product-attributes');

const MAX_NAME_LENGTH = 255;
const MAX_BATCH_NUMBER_LENGTH = 80;

const COLUMNS = Object.freeze([
  'product_name',
  'product_brand',
  'quantity',
  'available_quantity',
  'internal_quantity',
  'retail_price',
  'retail_price_max',
  'wholesale_price',
  'wholesale_price_max',
  'batch_number',
  'expiry_date',
  'cost',
  'invoice_number',
  'employee',
  'created_on',
  'updated_on',
  'supplier',
]);

const buildIssue = (rowNumber, severity, code, field, params = {}) => ({
  row_number: rowNumber,
  severity,
  code,
  field,
  params,
});

const readText = (values, field, maxLength, rowNumber, issues) => {
  const text = collapseWhitespace(values[field]);
  if (text && text.length > maxLength) {
    issues.push(buildIssue(rowNumber, 'warning', 'VALUE_TRUNCATED', field, { max: maxLength }));
    return text.slice(0, maxLength);
  }
  return text;
};

const readPrice = (values, field, rowNumber, issues) => {
  const parsed = parseNumber(values[field]);
  if (parsed.invalid) {
    issues.push(
      buildIssue(rowNumber, 'warning', 'INVALID_NUMBER', field, { value: String(values[field]) })
    );
    return null;
  }
  if (parsed.value != null && parsed.value < 0) {
    issues.push(buildIssue(rowNumber, 'warning', 'NEGATIVE_PRICE', field, { value: parsed.value }));
    return null;
  }
  return parsed.value;
};

/**
 * Map one Medic-ERP row to a normalized import record.
 *
 * @param {Object} values - Cell values keyed by normalized header
 * @param {number} rowNumber - Spreadsheet row number
 * @param {Object} [options]
 * @param {Date} [options.today]
 * @returns {{ record: Object|null, issues: Array<Object> }}
 */
const mapRow = (values = {}, rowNumber, { today = new Date() } = {}) => {
  const issues = [];

  const name = collapseWhitespace(values.product_name);
  if (!name) {
    issues.push(buildIssue(rowNumber, 'error', 'MISSING_PRODUCT_NAME', 'product_name'));
    return { record: null, issues };
  }
  if (name.length > MAX_NAME_LENGTH) {
    issues.push(
      buildIssue(rowNumber, 'error', 'VALUE_TOO_LONG', 'product_name', { max: MAX_NAME_LENGTH })
    );
    return { record: null, issues };
  }

  const available = parseNumber(values.available_quantity);
  if (available.invalid) {
    issues.push(
      buildIssue(rowNumber, 'error', 'INVALID_NUMBER', 'available_quantity', {
        value: String(values.available_quantity),
      })
    );
    return { record: null, issues };
  }

  const received = parseNumber(values.quantity);
  if (received.invalid) {
    issues.push(
      buildIssue(rowNumber, 'warning', 'INVALID_NUMBER', 'quantity', {
        value: String(values.quantity),
      })
    );
  }

  let quantity = available.value;
  if (quantity == null) {
    issues.push(buildIssue(rowNumber, 'warning', 'MISSING_QUANTITY', 'available_quantity'));
    quantity = 0;
  }
  if (quantity < 0) {
    issues.push(
      buildIssue(rowNumber, 'warning', 'NEGATIVE_QUANTITY', 'available_quantity', {
        value: quantity,
      })
    );
    quantity = 0;
  }
  if (!Number.isInteger(quantity)) {
    issues.push(
      buildIssue(rowNumber, 'warning', 'FRACTIONAL_QUANTITY', 'available_quantity', {
        value: quantity,
      })
    );
    quantity = Math.floor(quantity);
  }
  if (received.value != null && available.value != null && available.value > received.value) {
    issues.push(
      buildIssue(rowNumber, 'warning', 'QUANTITY_EXCEEDS_RECEIVED', 'available_quantity', {
        available_quantity: available.value,
        quantity: received.value,
      })
    );
  }

  const unitPrice = readPrice(values, 'retail_price', rowNumber, issues);
  const unitPriceMax = readPrice(values, 'retail_price_max', rowNumber, issues);
  const buyUnitPrice = readPrice(values, 'cost', rowNumber, issues);
  if (unitPrice != null && buyUnitPrice != null && unitPrice > 0 && buyUnitPrice > unitPrice) {
    issues.push(
      buildIssue(rowNumber, 'warning', 'PRICE_BELOW_COST', 'retail_price', {
        retail_price: unitPrice,
        cost: buyUnitPrice,
      })
    );
  }
  if (unitPrice != null && unitPriceMax != null && unitPriceMax > 0 && unitPriceMax < unitPrice) {
    issues.push(
      buildIssue(rowNumber, 'warning', 'MAX_PRICE_BELOW_PRICE', 'retail_price_max', {
        retail_price: unitPrice,
        retail_price_max: unitPriceMax,
      })
    );
  }

  const brandName = readText(values, 'product_brand', MAX_NAME_LENGTH, rowNumber, issues);
  const batchNumber = readText(values, 'batch_number', MAX_BATCH_NUMBER_LENGTH, rowNumber, issues);
  if (!batchNumber && quantity > 0) {
    issues.push(buildIssue(rowNumber, 'info', 'MISSING_BATCH_NUMBER', 'batch_number'));
  }

  const expiry = parseDate(values.expiry_date);
  if (expiry.invalid) {
    issues.push(
      buildIssue(rowNumber, 'warning', 'INVALID_DATE', 'expiry_date', {
        value: String(values.expiry_date),
      })
    );
  } else if (!expiry.value && quantity > 0) {
    issues.push(buildIssue(rowNumber, 'info', 'MISSING_EXPIRY_DATE', 'expiry_date'));
  } else if (expiry.value && quantity > 0 && expiry.value < startOfUtcDay(today)) {
    issues.push(
      buildIssue(rowNumber, 'warning', 'EXPIRED_BATCH', 'expiry_date', {
        expiry_date: toIsoDate(expiry.value),
      })
    );
  }

  const supplierName = readText(values, 'supplier', MAX_NAME_LENGTH, rowNumber, issues);
  const sourceUpdatedAt =
    parseDate(values.updated_on, { dateOnly: false }).value ||
    parseDate(values.created_on, { dateOnly: false }).value ||
    null;

  return {
    record: {
      row_number: rowNumber,
      name,
      brand_name: brandName,
      form: inferDosageForm(name, brandName),
      strength: inferStrength(name, brandName),
      quantity,
      received_quantity: received.value,
      unit_price: unitPrice,
      unit_price_max: unitPriceMax,
      buy_unit_price: buyUnitPrice,
      batch_number: batchNumber,
      expiry_date: expiry.value,
      supplier_name: supplierName,
      source_updated_at: sourceUpdatedAt,
    },
    issues,
  };
};

module.exports = {
  id: 'MEDIC_ERP',
  label: 'Medic-ERP',
  preferredSheetName: 'Stock',
  columns: COLUMNS,
  mapRow,
};
