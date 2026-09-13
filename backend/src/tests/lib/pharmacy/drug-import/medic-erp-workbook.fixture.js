/**
 * Builds in-memory Medic-ERP "Stock" workbooks for drug import tests.
 */

const ExcelJS = require('exceljs');
const medicErpSource = require('@lib/pharmacy/drug-import/sources/medic-erp.source');

const buildMedicErpRow = (overrides = {}) => ({
  product_name: 'AZITHROMYCIN 500MG TABLET',
  product_brand: 'ZAHA',
  quantity: 20,
  available_quantity: 4,
  internal_quantity: 0,
  retail_price: 7000,
  wholesale_price: null,
  wholesale_price_max: null,
  batch_number: 'PA09025',
  expiry_date: '2028-05-31',
  cost: 4300,
  invoice_number: '',
  employee: 'None',
  created_on: '2026-07-03T13:36:29.706Z',
  updated_on: '2026-07-10T07:14:58.532Z',
  supplier: null,
  ...overrides,
});

const buildMedicErpWorkbookBuffer = async (
  rows = [],
  { columns = medicErpSource.columns, sheetName = 'Stock' } = {}
) => {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet(sheetName);
  sheet.addRow(columns);
  rows.forEach((row) => sheet.addRow(columns.map((column) => row[column] ?? null)));
  return Buffer.from(await workbook.xlsx.writeBuffer());
};

module.exports = {
  buildMedicErpRow,
  buildMedicErpWorkbookBuffer,
};
