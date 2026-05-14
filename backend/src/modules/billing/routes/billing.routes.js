const express = require('express');
const router = express.Router();
const billingController = require('@controllers/billing/billing.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const {
  workspaceQuerySchema,
  workItemsQuerySchema,
  patientLedgerParamsSchema,
  patientLedgerQuerySchema,
  invoiceIdentifierParamsSchema,
  paymentIdentifierParamsSchema,
  approvalIdentifierParamsSchema,
  issueInvoiceSchema,
  sendInvoiceSchema,
  voidRequestSchema,
  reconcilePaymentSchema,
  refundRequestSchema,
  adjustmentRequestSchema,
  approveApprovalSchema,
  rejectApprovalSchema,
} = require('@validations/billing/billing.schema');

const BILLING_READ_SCOPES = [PERMISSIONS.BILLING_READ];
const BILLING_WRITE_SCOPES = [PERMISSIONS.BILLING_WRITE];
const BILLING_PORTAL_READ_SCOPES = [PERMISSIONS.BILLING_READ, PERMISSIONS.PATIENT_READ];
const BILLING_APPROVER_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

const requireBillingWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('billing_workspace_v1')) {
    return next(new HttpError('errors.billing.workspace_not_enabled', 404));
  }
  return next();
};

router.use(authenticate());
router.use(requireBillingWorkspaceV1);

router.get(
  '/workspace',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(BILLING_READ_SCOPES, 'permission'),
  billingController.getWorkspace
);

router.get(
  '/work-items',
  validateRequest({ query: workItemsQuerySchema }),
  authorize(BILLING_READ_SCOPES, 'permission'),
  billingController.getWorkItems
);

router.get(
  '/patients/:patientIdentifier/ledger',
  validateRequest({ params: patientLedgerParamsSchema, query: patientLedgerQuerySchema }),
  authorize(BILLING_PORTAL_READ_SCOPES, 'permission'),
  billingController.getPatientLedger
);

router.post(
  '/invoices/:invoiceIdentifier/issue',
  validateRequest({ params: invoiceIdentifierParamsSchema, body: issueInvoiceSchema }),
  authorize(BILLING_WRITE_SCOPES, 'permission'),
  billingController.issueInvoice
);

router.post(
  '/invoices/:invoiceIdentifier/send',
  validateRequest({ params: invoiceIdentifierParamsSchema, body: sendInvoiceSchema }),
  authorize(BILLING_WRITE_SCOPES, 'permission'),
  billingController.sendInvoice
);

router.post(
  '/invoices/:invoiceIdentifier/void-request',
  validateRequest({ params: invoiceIdentifierParamsSchema, body: voidRequestSchema }),
  authorize(BILLING_WRITE_SCOPES, 'permission'),
  billingController.requestInvoiceVoid
);

router.post(
  '/payments/:paymentIdentifier/reconcile',
  validateRequest({ params: paymentIdentifierParamsSchema, body: reconcilePaymentSchema }),
  authorize(BILLING_WRITE_SCOPES, 'permission'),
  billingController.reconcilePayment
);

router.post(
  '/payments/:paymentIdentifier/refund-request',
  validateRequest({ params: paymentIdentifierParamsSchema, body: refundRequestSchema }),
  authorize(BILLING_WRITE_SCOPES, 'permission'),
  billingController.requestPaymentRefund
);

router.post(
  '/adjustments/request',
  validateRequest({ body: adjustmentRequestSchema }),
  authorize(BILLING_WRITE_SCOPES, 'permission'),
  billingController.requestAdjustment
);

router.post(
  '/approvals/:approvalIdentifier/approve',
  validateRequest({ params: approvalIdentifierParamsSchema, body: approveApprovalSchema }),
  authorize(BILLING_APPROVER_SCOPES, 'permission'),
  billingController.approveApproval
);

router.post(
  '/approvals/:approvalIdentifier/reject',
  validateRequest({ params: approvalIdentifierParamsSchema, body: rejectApprovalSchema }),
  authorize(BILLING_APPROVER_SCOPES, 'permission'),
  billingController.rejectApproval
);

router.get(
  '/invoices/:invoiceIdentifier/document',
  validateRequest({ params: invoiceIdentifierParamsSchema }),
  authorize(BILLING_PORTAL_READ_SCOPES, 'permission'),
  billingController.getInvoiceDocument
);

module.exports = router;
