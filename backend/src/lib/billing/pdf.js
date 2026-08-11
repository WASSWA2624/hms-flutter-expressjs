const PDFDocument = require('pdfkit');

const toDecimalNumber = (value) => {
  if (value === null || value === undefined || value === '') return 0;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const money = (value, currency = '') =>
  `${String(currency || '').trim()} ${toDecimalNumber(value).toFixed(2)}`.trim();

const resolvePatientName = (patient = {}) => {
  const firstName = String(patient.first_name || '').trim();
  const lastName = String(patient.last_name || '').trim();
  return `${firstName} ${lastName}`.trim() || 'N/A';
};

const resolveDisplayId = (record = {}) =>
  String(record.display_id || record.human_friendly_id || '').trim() || 'N/A';

const formatDate = (value) => {
  if (!value) return 'N/A';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'N/A';
  return date.toISOString().slice(0, 10);
};

const formatDateTime = (value) => {
  if (!value) return 'N/A';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'N/A';
  return date.toISOString().replace('T', ' ').slice(0, 16);
};

const formatLabel = (value) => {
  const normalized = String(value || '').trim();
  if (!normalized) return 'N/A';
  return normalized
    .split('_')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(' ');
};

const computeAge = (dateOfBirth) => {
  if (!dateOfBirth) return null;
  const dob = new Date(dateOfBirth);
  if (Number.isNaN(dob.getTime())) return null;
  const today = new Date();
  let age = today.getFullYear() - dob.getFullYear();
  const monthDelta = today.getMonth() - dob.getMonth();
  if (monthDelta < 0 || (monthDelta === 0 && today.getDate() < dob.getDate())) {
    age -= 1;
  }
  return age >= 0 ? `${age} yrs` : null;
};

const derivePaymentStatus = (invoice = {}, financials = {}) => {
  const billingStatus = String(invoice?.billing_status || invoice?.status || '')
    .trim()
    .toUpperCase();
  const balanceDue = toDecimalNumber(financials.balance_due ?? invoice?.total_amount);
  const netPaid = toDecimalNumber(financials.net_paid_total);

  if (billingStatus === 'DRAFT') return 'Deferred';
  if (billingStatus === 'PAID' || balanceDue <= 0) return 'Cleared';
  if (billingStatus === 'PARTIAL' || netPaid > 0) return 'Partially paid';
  if (String(invoice?.status || '').trim().toUpperCase() === 'OVERDUE' && balanceDue > 0) {
    return 'Overdue';
  }
  if (balanceDue > 0) return 'Awaiting payment';
  return 'Blocked';
};

const PAGE_BOTTOM = 760;
const ROW_PADDING = 4;
const HEADER_FILL = '#f3f4f6';
const BORDER_COLOR = '#d1d5db';

const ensureSpace = (doc, height) => {
  if (doc.y + height > PAGE_BOTTOM) {
    doc.addPage();
    doc.y = doc.page.margins.top;
  }
};

const drawTable = (doc, { title, columns, rows, emptyText = 'No records.', footerRow = null }) => {
  if (title) {
    ensureSpace(doc, 28);
    doc.font('Helvetica-Bold').fontSize(12).fillColor('#111').text(title);
    doc.moveDown(0.4);
  }

  const startX = doc.page.margins.left;
  const tableWidth = doc.page.width - doc.page.margins.left - doc.page.margins.right;
  const normalizedColumns = columns.map((column) => ({
    label: column.label,
    width: column.width,
    align: column.align || 'left',
  }));
  const widthTotal = normalizedColumns.reduce((sum, column) => sum + column.width, 0);
  const scale = tableWidth / widthTotal;
  const scaledColumns = normalizedColumns.map((column) => ({
    ...column,
    width: column.width * scale,
  }));

  const drawRow = (cells, { bold = false, fill = false } = {}) => {
    const fontName = bold ? 'Helvetica-Bold' : 'Helvetica';
    doc.font(fontName).fontSize(9);
    const heights = cells.map((cell, index) => {
      return doc.heightOfString(String(cell ?? ''), {
        width: scaledColumns[index].width - ROW_PADDING * 2,
        align: scaledColumns[index].align,
      });
    });
    const rowHeight = Math.max(...heights, 12) + ROW_PADDING * 2;
    ensureSpace(doc, rowHeight + 2);

    const y = doc.y;
    if (fill) {
      doc.save();
      doc.rect(startX, y, tableWidth, rowHeight).fill(HEADER_FILL);
      doc.restore();
    }

    let x = startX;
    cells.forEach((cell, index) => {
      const column = scaledColumns[index];
      doc
        .font(fontName)
        .fontSize(9)
        .fillColor('#111')
        .text(String(cell ?? ''), x + ROW_PADDING, y + ROW_PADDING, {
          width: column.width - ROW_PADDING * 2,
          align: column.align,
        });
      x += column.width;
    });

    doc
      .moveTo(startX, y + rowHeight)
      .lineTo(startX + tableWidth, y + rowHeight)
      .strokeColor(BORDER_COLOR)
      .lineWidth(0.5)
      .stroke();

    // Keep the cursor on the left margin — cell writes leave doc.x on the right
    // edge, which would squeeze any following block into a narrow strip.
    doc.x = startX;
    doc.y = y + rowHeight;
  };

  drawRow(
    scaledColumns.map((column) => column.label),
    { bold: true, fill: true },
  );

  if (!rows.length) {
    drawRow([emptyText, ...Array(Math.max(scaledColumns.length - 1, 0)).fill('')]);
    doc.x = doc.page.margins.left;
    doc.moveDown(0.5);
    return;
  }

  rows.forEach((row) => drawRow(row));
  if (footerRow) {
    drawRow(footerRow, { bold: true });
  }
  doc.x = doc.page.margins.left;
  doc.moveDown(0.5);
};

/** Right-aligned totals block with label + amount on one line. */
const drawFinancialSummary = (doc, items) => {
  const pairs = (items || []).filter(
    ([label, value]) => String(label || '').trim() && String(value || '').trim(),
  );
  if (!pairs.length) return;

  const summaryWidth = 280;
  const labelWidth = 150;
  const valueWidth = summaryWidth - labelWidth;
  const rowGap = 4;
  const titleHeight = 18;
  const rowHeight = 14;
  const boxPadding = 10;
  const contentHeight =
    titleHeight + rowGap + pairs.length * (rowHeight + 2) + boxPadding * 2;
  ensureSpace(doc, contentHeight + 8);

  const pageRight = doc.page.width - doc.page.margins.right;
  const startX = pageRight - summaryWidth;
  const startY = doc.y;

  doc.save();
  doc
    .roundedRect(startX, startY, summaryWidth, contentHeight, 4)
    .fillAndStroke(HEADER_FILL, BORDER_COLOR);
  doc.restore();

  let y = startY + boxPadding;
  doc
    .font('Helvetica-Bold')
    .fontSize(12)
    .fillColor('#111')
    .text('Financial summary', startX + boxPadding, y, {
      width: summaryWidth - boxPadding * 2,
      align: 'left',
      lineBreak: false,
    });
  y += titleHeight;

  pairs.forEach(([label, value], index) => {
    const isLast = index === pairs.length - 1;
    const fontName = isLast ? 'Helvetica-Bold' : 'Helvetica';
    doc.font(fontName).fontSize(10).fillColor('#111');
    doc.text(`${label}:`, startX + boxPadding, y, {
      width: labelWidth - boxPadding,
      align: 'left',
      lineBreak: false,
    });
    doc.text(String(value), startX + labelWidth, y, {
      width: valueWidth - boxPadding,
      align: 'right',
      lineBreak: false,
    });
    y += rowHeight + 2;
  });

  doc.x = doc.page.margins.left;
  doc.y = startY + contentHeight + 8;
};

const generateInvoicePdfBuffer = async ({ invoice, financials = {} }) =>
  new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const chunks = [];

    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    const invoiceCurrency = String(invoice?.currency || '').trim() || 'USD';
    const patient = invoice?.patient || {};
    const patientName = resolvePatientName(patient);
    const invoiceDisplayId = resolveDisplayId(invoice || {});
    const patientDisplayId = resolveDisplayId(patient);
    const facilityName = String(invoice?.facility?.name || invoice?.tenant?.name || '').trim();
    const paymentStatus = derivePaymentStatus(invoice, financials);
    const patientAge = computeAge(patient.date_of_birth);
    const patientGender = formatLabel(patient.gender);

    if (facilityName) {
      doc.font('Helvetica-Bold').fontSize(14).fillColor('#111').text(facilityName);
      doc.moveDown(0.2);
    }

    doc.font('Helvetica-Bold').fontSize(20).fillColor('#111').text('Invoice');
    doc.moveDown(0.3);
    doc.font('Helvetica').fontSize(11).fillColor('#111');
    doc.text(`Invoice: ${invoiceDisplayId}`);
    doc.text(`Patient: ${patientName} (${patientDisplayId})`);
    doc.text(`Issued: ${formatDate(invoice?.issued_at || invoice?.created_at)}`);
    doc.text(`Payment status: ${paymentStatus}`);
    doc.text(`Invoice status: ${formatLabel(invoice?.billing_status || invoice?.status)}`);
    if (patientGender !== 'N/A') {
      doc.text(`Gender: ${patientGender}`);
    }
    if (patientAge) {
      doc.text(`Age: ${patientAge}`);
    }
    const encounterId = String(invoice?.encounter_display_id || invoice?.encounter_id || '').trim();
    if (encounterId) {
      doc.text(`Encounter: ${encounterId}`);
    }
    doc.moveDown();

    const items = Array.isArray(invoice?.items) ? invoice.items : [];
    const lineItemRows = items.map((item, index) => {
      const description = String(item?.description || '').trim() || `Item ${index + 1}`;
      const quantity = Number.isFinite(Number(item?.quantity)) ? Number(item.quantity) : 1;
      return [
        `${index + 1}`,
        description,
        `${quantity}`,
        money(item?.unit_price, invoiceCurrency),
        formatLabel(item?.source_module),
        String(item?.encounter_display_id || '').trim() || 'N/A',
        money(item?.total_price, invoiceCurrency),
      ];
    });

    drawTable(doc, {
      title: 'Line items',
      columns: [
        { label: '#', width: 24, align: 'right' },
        { label: 'Description', width: 150 },
        { label: 'Qty', width: 36, align: 'right' },
        { label: 'Unit price', width: 72, align: 'right' },
        { label: 'Department', width: 72 },
        { label: 'Encounter', width: 72 },
        { label: 'Amount', width: 72, align: 'right' },
      ],
      rows: lineItemRows,
      emptyText: 'No line items.',
      footerRow: lineItemRows.length
        ? ['', '', '', '', '', 'Invoice total', money(financials.invoice_total ?? invoice?.total_amount, invoiceCurrency)]
        : null,
    });

    const payments = Array.isArray(invoice?.payments) ? invoice.payments : [];
    const paymentRows = payments.map((payment) => [
      resolveDisplayId(payment),
      formatLabel(payment?.method),
      formatLabel(payment?.status),
      String(payment?.transaction_ref || '').trim() || 'N/A',
      formatDateTime(payment?.paid_at || payment?.created_at),
      money(payment?.amount, invoiceCurrency),
    ]);

    drawTable(doc, {
      title: 'Payments',
      columns: [
        { label: 'Payment', width: 70 },
        { label: 'Method', width: 70 },
        { label: 'Status', width: 70 },
        { label: 'Reference', width: 90 },
        { label: 'Date', width: 80 },
        { label: 'Amount', width: 70, align: 'right' },
      ],
      rows: paymentRows,
      emptyText: 'No payments recorded.',
    });

    ensureSpace(doc, 24);
    drawFinancialSummary(doc, [
      ['Invoice total', money(financials.invoice_total ?? invoice?.total_amount, invoiceCurrency)],
      ['Adjustments', money(financials.adjustment_total ?? 0, invoiceCurrency)],
      ['Effective total', money(financials.effective_total ?? invoice?.total_amount, invoiceCurrency)],
      ['Payments received', money(financials.gross_paid_total ?? 0, invoiceCurrency)],
      ['Refunds', money(financials.refunded_total ?? 0, invoiceCurrency)],
      ['Net paid', money(financials.net_paid_total ?? 0, invoiceCurrency)],
      ['Balance due', money(financials.balance_due ?? invoice?.total_amount, invoiceCurrency)],
    ]);

    doc.moveDown();
    doc.x = doc.page.margins.left;
    doc.fontSize(9).fillColor('#666').text('Generated by HMS Billing Workspace');
    doc.end();
  });

module.exports = {
  generateInvoicePdfBuffer,
};
