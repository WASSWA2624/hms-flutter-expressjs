const path = require('path');
const PDFDocument = require('pdfkit');
const ExcelJS = require('exceljs');

const MIME_BY_FORMAT = Object.freeze({
  PDF: 'application/pdf',
  CSV: 'text/csv',
  JSON: 'application/json',
  XLSX: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
});

const EXTENSION_BY_FORMAT = Object.freeze({
  PDF: 'pdf',
  CSV: 'csv',
  JSON: 'json',
  XLSX: 'xlsx',
});

const sanitizeFileStem = (value) =>
  String(value || 'report')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'report';

const buildFileName = (title, format) => {
  const extension = EXTENSION_BY_FORMAT[String(format || 'PDF').toUpperCase()] || 'dat';
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  return `${sanitizeFileStem(title)}-${stamp}.${extension}`;
};

const normalizeColumns = (columns = [], rows = []) => {
  if (Array.isArray(columns) && columns.length > 0) {
    return columns.map((column) => ({
      key: String(column || '').trim(),
      label: String(column || '')
        .trim()
        .replace(/_/g, ' ')
        .replace(/\b\w/g, (char) => char.toUpperCase()),
    }));
  }

  const firstRow = rows.find((entry) => entry && typeof entry === 'object') || {};
  return Object.keys(firstRow).map((key) => ({
    key,
    label: key.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase()),
  }));
};

const normalizeCell = (value) => {
  if (value === null || value === undefined) return '';
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
};

const renderPdfBuffer = ({ title, subtitle, columns, rows }) =>
  new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    const chunks = [];

    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('error', reject);
    doc.on('end', () => resolve(Buffer.concat(chunks)));

    doc.fontSize(18).text(title || 'Report', { align: 'left' });
    if (subtitle) {
      doc.moveDown(0.5);
      doc.fontSize(10).fillColor('#555').text(subtitle);
      doc.fillColor('#000');
    }

    doc.moveDown();
    doc.fontSize(11);

    if (!rows.length) {
      doc.text('No rows available for the selected filters.');
      doc.end();
      return;
    }

    const header = columns.map((entry) => entry.label).join(' | ');
    doc.font('Helvetica-Bold').text(header);
    doc.moveDown(0.4);
    doc.font('Helvetica');

    rows.forEach((row) => {
      const line = columns.map((entry) => normalizeCell(row?.[entry.key])).join(' | ');
      doc.text(line || '-');
    });

    doc.end();
  });

const renderCsvBuffer = ({ columns, rows }) => {
  const header = columns.map((entry) => `"${String(entry.label).replace(/"/g, '""')}"`).join(',');
  const body = rows.map((row) =>
    columns
      .map((entry) => `"${normalizeCell(row?.[entry.key]).replace(/"/g, '""')}"`)
      .join(',')
  );
  return Buffer.from([header, ...body].join('\n'), 'utf8');
};

const renderJsonBuffer = ({ rows }) => Buffer.from(JSON.stringify(rows, null, 2), 'utf8');

const renderXlsxBuffer = async ({ title, columns, rows }) => {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Report');

  sheet.columns = columns.map((entry) => ({
    header: entry.label,
    key: entry.key,
    width: Math.max(16, entry.label.length + 4),
  }));

  rows.forEach((row) => {
    const payload = {};
    columns.forEach((entry) => {
      payload[entry.key] = row?.[entry.key] ?? '';
    });
    sheet.addRow(payload);
  });

  sheet.views = [{ state: 'frozen', ySplit: 1 }];
  sheet.getRow(1).font = { bold: true };
  workbook.creator = 'HMS Reports';
  workbook.lastModifiedBy = 'HMS Reports';
  workbook.created = new Date();
  workbook.modified = new Date();
  workbook.subject = title || 'Report export';

  return workbook.xlsx.writeBuffer();
};

const generateReportFile = async ({ title, subtitle, columns, rows, format }) => {
  const upperFormat = String(format || 'PDF').trim().toUpperCase();
  const normalizedColumns = normalizeColumns(columns, rows);
  const fileName = buildFileName(title, upperFormat);

  let buffer;
  if (upperFormat === 'CSV') {
    buffer = renderCsvBuffer({ columns: normalizedColumns, rows });
  } else if (upperFormat === 'JSON') {
    buffer = renderJsonBuffer({ rows });
  } else if (upperFormat === 'XLSX') {
    buffer = Buffer.from(await renderXlsxBuffer({ title, columns: normalizedColumns, rows }));
  } else {
    buffer = await renderPdfBuffer({ title, subtitle, columns: normalizedColumns, rows });
  }

  return {
    buffer,
    file_name: path.basename(fileName),
    mime_type: MIME_BY_FORMAT[upperFormat] || MIME_BY_FORMAT.PDF,
    format: upperFormat,
    size_bytes: buffer.length,
  };
};

module.exports = {
  generateReportFile,
};
