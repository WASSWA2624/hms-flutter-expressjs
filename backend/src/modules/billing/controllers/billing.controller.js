const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const billingService = require('@services/billing/billing.service');

const getWorkspace = asyncHandler(async (req, res) => {
  const {
    facility_id,
    patient_id,
    from,
    to,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
  } = req.query;

  const data = await billingService.getWorkspace(
    {
      facility_id,
      patient_id,
      from,
      to,
      search,
    },
    Number(page),
    Number(limit),
    req.user
  );

  return sendSuccess(res, 200, 'messages.billing.workspace.success', data);
});

const getWorkItems = asyncHandler(async (req, res) => {
  const {
    queue,
    facility_id,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
  } = req.query;

  const data = await billingService.getWorkItems(
    {
      queue,
      facility_id,
      search,
    },
    Number(page),
    Number(limit),
    req.user
  );

  return sendSuccess(res, 200, 'messages.billing.work_items.success', data);
});

const getPatientLedger = asyncHandler(async (req, res) => {
  const { patientIdentifier } = req.params;
  const {
    from,
    to,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
  } = req.query;

  const data = await billingService.getPatientLedger(
    patientIdentifier,
    {
      from,
      to,
    },
    Number(page),
    Number(limit),
    req.user
  );

  return sendSuccess(res, 200, 'messages.billing.ledger.success', data);
});

const issueInvoice = asyncHandler(async (req, res) => {
  const data = await billingService.issueInvoice(
    req.params.invoiceIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.billing.invoice.issue.success', data);
});

const sendInvoice = asyncHandler(async (req, res) => {
  const data = await billingService.sendInvoice(
    req.params.invoiceIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.billing.invoice.send.success', data);
});

const requestInvoiceVoid = asyncHandler(async (req, res) => {
  const data = await billingService.requestInvoiceVoid(
    req.params.invoiceIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.billing.invoice.void_request.success', data);
});

const reconcilePayment = asyncHandler(async (req, res) => {
  const data = await billingService.reconcilePayment(
    req.params.paymentIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.billing.payment.reconcile.success', data);
});

const requestPaymentRefund = asyncHandler(async (req, res) => {
  const data = await billingService.requestPaymentRefund(
    req.params.paymentIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.billing.payment.refund_request.success', data);
});

const requestAdjustment = asyncHandler(async (req, res) => {
  const data = await billingService.requestAdjustment(req.body, req.user, req.ip);
  return sendSuccess(res, 200, 'messages.billing.adjustment.request.success', data);
});

const approveApproval = asyncHandler(async (req, res) => {
  const data = await billingService.approveApproval(
    req.params.approvalIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.billing.approval.approve.success', data);
});

const rejectApproval = asyncHandler(async (req, res) => {
  const data = await billingService.rejectApproval(
    req.params.approvalIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.billing.approval.reject.success', data);
});

const getInvoiceDocument = asyncHandler(async (req, res) => {
  const document = await billingService.getInvoiceDocument(
    req.params.invoiceIdentifier,
    req.user
  );

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="${document.file_name}"`
  );
  res.setHeader('Content-Length', String(document.buffer.length));

  return res.status(200).send(document.buffer);
});

module.exports = {
  getWorkspace,
  getWorkItems,
  getPatientLedger,
  issueInvoice,
  sendInvoice,
  requestInvoiceVoid,
  reconcilePayment,
  requestPaymentRefund,
  requestAdjustment,
  approveApproval,
  rejectApproval,
  getInvoiceDocument,
};
