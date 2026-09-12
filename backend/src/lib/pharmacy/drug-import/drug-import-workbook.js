/**
 * Read an uploaded .xlsx drug import file into header-keyed rows.
 */

const ExcelJS = require('exceljs');
const { HttpError } = require('@lib/errors');

const HEADER_SCAN_ROWS = 10;

const normalizeHeader = (value) =>
  String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_');

const isBlankValue = (value) =>
  value == null || (typeof value === 'string' && !value.trim());

const normalizeCellValue = (value) => {
  if (value == null || value instanceof Date) return value ?? null;
  if (typeof value !== 'object') return value;
  if (Array.isArray(value.richText)) {
    return value.richText.map((part) => part?.text || '').join('');
  }
  if (Object.prototype.hasOwnProperty.call(value, 'result')) {
    return normalizeCellValue(value.result);
  }
  if (typeof value.text === 'string') return value.text;
  return null;
};

const readRowValues = (row) => {
  const values = [];
  row.eachCell({ includeEmpty: true }, (cell, columnNumber) => {
    values[columnNumber] = normalizeCellValue(cell.value);
  });
  return values;
};

const invalidFile = (messageKey) => new HttpError(messageKey, 400, [{ field: 'file' }]);

const pickWorksheet = (workbook, preferredSheetName) => {
  const preferred = String(preferredSheetName || '').trim().toLowerCase();
  const byName = preferred
    ? workbook.worksheets.find((sheet) => String(sheet.name).trim().toLowerCase() === preferred)
    : null;
  return byName || workbook.worksheets.find((sheet) => sheet.actualRowCount > 0) || null;
};

/**
 * Load workbook rows keyed by normalized header name.
 *
 * The header row is the first non-empty row in the first ten rows; fully blank
 * data rows are skipped and do not count toward the row limit.
 *
 * @param {Buffer} buffer - Uploaded file bytes
 * @param {Object} [options]
 * @param {string|null} [options.preferredSheetName]
 * @param {number} [options.maxRows=5000]
 * @returns {Promise<{ sheet_name: string, headers: string[], rows: Array<{ row_number: number, values: Object }> }>}
 * @throws {HttpError} 400 for unreadable, empty, or oversized files
 */
const readDrugImportWorkbook = async (
  buffer,
  { preferredSheetName = null, maxRows = 5000 } = {}
) => {
  if (!buffer || !buffer.length) {
    throw invalidFile('errors.pharmacy_drug_import.file_required');
  }

  const workbook = new ExcelJS.Workbook();
  try {
    await workbook.xlsx.load(buffer);
  } catch (_error) {
    throw invalidFile('errors.pharmacy_drug_import.invalid_file');
  }

  const worksheet = pickWorksheet(workbook, preferredSheetName);
  if (!worksheet) {
    throw invalidFile('errors.pharmacy_drug_import.empty_file');
  }

  const lastRowNumber = worksheet.rowCount;
  let headerRowNumber = null;
  let headerCells = [];
  for (let rowNumber = 1; rowNumber <= Math.min(lastRowNumber, HEADER_SCAN_ROWS); rowNumber += 1) {
    const cells = readRowValues(worksheet.getRow(rowNumber));
    if (cells.some((value) => !isBlankValue(value))) {
      headerRowNumber = rowNumber;
      headerCells = cells;
      break;
    }
  }
  if (!headerRowNumber) {
    throw invalidFile('errors.pharmacy_drug_import.empty_file');
  }

  const columns = new Map();
  headerCells.forEach((value, columnNumber) => {
    if (isBlankValue(value)) return;
    const header = normalizeHeader(value);
    if (!columns.has(header)) columns.set(header, columnNumber);
  });

  const rows = [];
  for (let rowNumber = headerRowNumber + 1; rowNumber <= lastRowNumber; rowNumber += 1) {
    const cells = readRowValues(worksheet.getRow(rowNumber));
    const values = {};
    let hasValue = false;
    for (const [header, columnNumber] of columns) {
      const value = cells[columnNumber] ?? null;
      values[header] = value;
      if (!isBlankValue(value)) hasValue = true;
    }
    if (!hasValue) continue;
    if (rows.length >= maxRows) {
      throw new HttpError('errors.pharmacy_drug_import.too_many_rows', 400, [
        { field: 'file', max_rows: maxRows },
      ]);
    }
    rows.push({ row_number: rowNumber, values });
  }

  if (!rows.length) {
    throw invalidFile('errors.pharmacy_drug_import.empty_file');
  }

  return {
    sheet_name: worksheet.name,
    headers: [...columns.keys()],
    rows,
  };
};

module.exports = {
  normalizeHeader,
  readDrugImportWorkbook,
};
