/**
 * Registry of external systems whose drug/stock exports can be imported.
 *
 * A source declares its template columns, preferred sheet, and a `mapRow`
 * that turns one spreadsheet row into a normalized import record.
 */

const { HttpError } = require('@lib/errors');
const medicErpSource = require('@lib/pharmacy/drug-import/sources/medic-erp.source');

const DRUG_IMPORT_SOURCES = Object.freeze({
  [medicErpSource.id]: medicErpSource,
});

const DRUG_IMPORT_SOURCE_IDS = Object.freeze(Object.keys(DRUG_IMPORT_SOURCES));

/**
 * @param {string} sourceId
 * @returns {Object} Import source definition
 * @throws {HttpError} 400 when the source is unknown
 */
const resolveDrugImportSource = (sourceId) => {
  const source = DRUG_IMPORT_SOURCES[String(sourceId || '').trim().toUpperCase()];
  if (!source) {
    throw new HttpError('errors.pharmacy_drug_import.unsupported_source', 400, [
      { field: 'source' },
    ]);
  }
  return source;
};

/**
 * Compare workbook headers with the source template.
 *
 * Extra columns are allowed; only missing template columns block an import.
 *
 * @param {Object} source
 * @param {Array<string>} headers - Normalized header names
 * @returns {{ missing_columns: string[], unexpected_columns: string[] }}
 */
const checkTemplateColumns = (source, headers = []) => {
  const present = new Set(headers.filter(Boolean));
  return {
    missing_columns: source.columns.filter((column) => !present.has(column)),
    unexpected_columns: [...present].filter((column) => !source.columns.includes(column)),
  };
};

module.exports = {
  DRUG_IMPORT_SOURCES,
  DRUG_IMPORT_SOURCE_IDS,
  resolveDrugImportSource,
  checkTemplateColumns,
};
