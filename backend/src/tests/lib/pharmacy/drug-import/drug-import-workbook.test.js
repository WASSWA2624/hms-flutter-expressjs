const ExcelJS = require('exceljs');
const { readDrugImportWorkbook } = require('@lib/pharmacy/drug-import/drug-import-workbook');
const { HttpError } = require('@lib/errors');
const { buildMedicErpRow, buildMedicErpWorkbookBuffer } = require('./medic-erp-workbook.fixture');

const toBuffer = async (workbook) => Buffer.from(await workbook.xlsx.writeBuffer());

const expectHttpError = async (promise, messageKey) => {
  await expect(promise).rejects.toBeInstanceOf(HttpError);
  await expect(promise).rejects.toMatchObject({ message: messageKey, statusCode: 400 });
};

describe('readDrugImportWorkbook', () => {
  it('reads header-keyed rows from the preferred sheet', async () => {
    const buffer = await buildMedicErpWorkbookBuffer([
      buildMedicErpRow(),
      buildMedicErpRow({ product_brand: 'SWAZI' }),
    ]);

    const result = await readDrugImportWorkbook(buffer, { preferredSheetName: 'stock' });

    expect(result.sheet_name).toBe('Stock');
    expect(result.headers).toContain('available_quantity');
    expect(result.rows).toHaveLength(2);
    expect(result.rows[1]).toMatchObject({
      row_number: 3,
      values: expect.objectContaining({ product_brand: 'SWAZI', available_quantity: 4 }),
    });
  });

  it('finds a header below blank rows, normalizes header text, and skips blank rows', async () => {
    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Export');
    sheet.addRow([]);
    sheet.addRow(['Product Name', 'Available Quantity', 'Batch-Number']);
    sheet.addRow([{ richText: [{ text: 'PARA' }, { text: 'CETAMOL' }] }, { formula: '2*5', result: 10 }, 'B1']);
    sheet.addRow([null, null, null]);
    sheet.addRow(['IBUPROFEN', 3, '']);

    const result = await readDrugImportWorkbook(await toBuffer(workbook));

    expect(result.headers).toEqual(['product_name', 'available_quantity', 'batch_number']);
    expect(result.rows.map((row) => row.row_number)).toEqual([3, 5]);
    expect(result.rows[0].values).toEqual({
      product_name: 'PARACETAMOL',
      available_quantity: 10,
      batch_number: 'B1',
    });
  });

  it('rejects unreadable and empty files', async () => {
    await expectHttpError(
      readDrugImportWorkbook(Buffer.from('not a spreadsheet')),
      'errors.pharmacy_drug_import.invalid_file'
    );
    await expectHttpError(readDrugImportWorkbook(Buffer.alloc(0)), 'errors.pharmacy_drug_import.file_required');

    const headerOnly = await buildMedicErpWorkbookBuffer([]);
    await expectHttpError(readDrugImportWorkbook(headerOnly), 'errors.pharmacy_drug_import.empty_file');
  });

  it('reads files of any row count', async () => {
    const rows = Array.from({ length: 6000 }, (_, index) =>
      buildMedicErpRow({ product_brand: `BRAND ${index}` })
    );
    const result = await readDrugImportWorkbook(await buildMedicErpWorkbookBuffer(rows));

    expect(result.rows).toHaveLength(6000);
    expect(result.rows[5999].values.product_brand).toBe('BRAND 5999');
  });
});
