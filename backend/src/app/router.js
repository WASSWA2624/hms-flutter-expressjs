/**
 * Root Router
 *
 * Health endpoints are at root level (not under /api/v1/)
 * Per health-checks.md: Health endpoints are public at root level
 * Per api-versioning.md: All API endpoints must be versioned under /api/v1/
 */

const express = require('express');
const router = express.Router();

// Health check utilities
const { healthCheck, readinessCheck, livenessCheck } = require('@lib/health');
const { asyncHandler } = require('@lib/async');
const { authenticate } = require('@middlewares/auth.middleware');
const { hydrateRequestScope, enforceTenantScope } = require('@middlewares/tenant-scope.middleware');
const { hydrateRequestContext } = require('@middlewares/request-context.middleware');
const { enforceModuleEntitlement } = require('@middlewares/module-entitlement.middleware');
const { enforceAbacAccess } = require('@middlewares/abac.middleware');

/**
 * @description Health check endpoint (public)
 * @method GET
 * @route /health
 * @authentication None
 * @permissions Public
 * @urlParams None
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Health status payload
 * @throws 503 Service unavailable
 */
router.get('/health', (req, res) => {
  const health = healthCheck();
  const statusCode = health.status === 'healthy' ? 200 : 503;
  return res.status(statusCode).json(health);
});

/**
 * @description Readiness check endpoint (public)
 * @method GET
 * @route /ready
 * @authentication None
 * @permissions Public
 * @urlParams None
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Readiness status payload
 * @throws 503 Service unavailable
 */
router.get('/ready', asyncHandler(async (req, res) => {
  const readiness = await readinessCheck();
  const statusCode = readiness.status === 'ready' ? 200 : 503;
  return res.status(statusCode).json(readiness);
}));

/**
 * @description Liveness check endpoint (public)
 * @method GET
 * @route /live
 * @authentication None
 * @permissions Public
 * @urlParams None
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Liveness status payload
 */
router.get('/live', (req, res) => {
  const liveness = livenessCheck();
  return res.status(200).json(liveness);
});

/**
 * API v1 Router
 * Per api-versioning.mdc: All API endpoints must be versioned
 * Per module-creation.mdc: Modules are mounted under /api/v1/<module>
 */
const apiV1Router = express.Router();

// Mount module routes under /api/v1/
// Per module-creation.mdc step 7: Use relative paths to mount modules
apiV1Router.use('/auth', require('../modules/auth/routes/auth.routes'));
apiV1Router.use('/public', require('../modules/public/routes/public.routes'));

// Global protection for all non-auth API v1 routes.
apiV1Router.use(authenticate());
apiV1Router.use(hydrateRequestScope());
apiV1Router.use(enforceTenantScope());
apiV1Router.use(hydrateRequestContext());
apiV1Router.use(enforceModuleEntitlement());
apiV1Router.use(enforceAbacAccess());

apiV1Router.use('/user-sessions', require('../modules/user-session/routes/user-session.routes'));
apiV1Router.use('/tenants', require('../modules/tenant/routes/tenant.routes'));
apiV1Router.use('/facilities', require('../modules/facility/routes/facility.routes'));
apiV1Router.use('/branches', require('../modules/branch/routes/branch.routes'));
apiV1Router.use('/departments', require('../modules/department/routes/department.routes'));
apiV1Router.use('/units', require('../modules/unit/routes/unit.routes'));
apiV1Router.use('/rooms', require('../modules/room/routes/room.routes'));
apiV1Router.use('/wards', require('../modules/ward/routes/ward.routes'));
apiV1Router.use('/beds', require('../modules/bed/routes/bed.routes'));
apiV1Router.use('/addresses', require('../modules/address/routes/address.routes'));
apiV1Router.use('/contacts', require('../modules/contact/routes/contact.routes'));
apiV1Router.use('/users', require('../modules/user/routes/user.routes'));
apiV1Router.use('/user-profiles', require('../modules/user-profile/routes/user-profile.routes'));
apiV1Router.use('/roles', require('../modules/role/routes/role.routes'));
apiV1Router.use('/permissions', require('../modules/permission/routes/permission.routes'));
apiV1Router.use('/role-permissions', require('../modules/role-permission/routes/role-permission.routes'));
apiV1Router.use('/user-roles', require('../modules/user-role/routes/user-role.routes'));
apiV1Router.use('/user-mfas', require('../modules/user-mfa/routes/user-mfa.routes'));
apiV1Router.use('/oauth-accounts', require('../modules/oauth-account/routes/oauth-account.routes'));
apiV1Router.use('/api-keys', require('../modules/api-key/routes/api-key.routes'));
apiV1Router.use('/api-key-permissions', require('../modules/api-key-permission/routes/api-key-permission.routes'));
apiV1Router.use('/abac-policies', require('../modules/abac-policy/routes/abac-policy.routes'));
apiV1Router.use('/patients', require('../modules/patient/routes/patient.routes'));
apiV1Router.use('/patient-identifiers', require('../modules/patient-identifier/routes/patient-identifier.routes'));
apiV1Router.use('/patient-contacts', require('../modules/patient-contact/routes/patient-contact.routes'));
apiV1Router.use('/patient-guardians', require('../modules/patient-guardian/routes/patient-guardian.routes'));
apiV1Router.use('/patient-allergies', require('../modules/patient-allergy/routes/patient-allergy.routes'));
apiV1Router.use('/patient-medical-histories', require('../modules/patient-medical-history/routes/patient-medical-history.routes'));
apiV1Router.use('/patient-documents', require('../modules/patient-document/routes/patient-document.routes'));
apiV1Router.use('/consents', require('../modules/consent/routes/consent.routes'));
apiV1Router.use('/terms-acceptances', require('../modules/terms-acceptance/routes/terms-acceptance.routes'));
apiV1Router.use('/appointments', require('../modules/appointment/routes/appointment.routes'));
apiV1Router.use('/appointment-participants', require('../modules/appointment-participant/routes/appointment-participant.routes'));
apiV1Router.use('/appointment-reminders', require('../modules/appointment-reminder/routes/appointment-reminder.routes'));
apiV1Router.use('/provider-schedules', require('../modules/provider-schedule/routes/provider-schedule.routes'));
apiV1Router.use('/availability-slots', require('../modules/availability-slot/routes/availability-slot.routes'));
apiV1Router.use('/scheduling', require('../modules/scheduling-workspace/routes/scheduling-workspace.routes'));
apiV1Router.use('/doctors', require('../modules/doctor/routes/doctor.routes'));
apiV1Router.use('/admissions', require('../modules/admission/routes/admission.routes'));
apiV1Router.use('/bed-assignments', require('../modules/bed-assignment/routes/bed-assignment.routes'));
apiV1Router.use('/ward-rounds', require('../modules/ward-round/routes/ward-round.routes'));
apiV1Router.use('/visit-queues', require('../modules/visit-queue/routes/visit-queue.routes'));
apiV1Router.use('/triage', require('../modules/triage/routes/triage.routes'));
apiV1Router.use('/opd-flows', require('../modules/opd-flow/routes/opd-flow.routes'));
apiV1Router.use('/ipd-flows', require('../modules/ipd-flow/routes/ipd-flow.routes'));
apiV1Router.use('/referrals', require('../modules/referral/routes/referral.routes'));
apiV1Router.use('/campaigns', require('../modules/campaign/routes/campaign.routes'));
apiV1Router.use('/feedback', require('../modules/feedback/routes/feedback.routes'));
apiV1Router.use('/follow-ups', require('../modules/follow-up/routes/follow-up.routes'));
apiV1Router.use('/vital-signs', require('../modules/vital-sign/routes/vital-sign.routes'));
apiV1Router.use('/care-plans', require('../modules/care-plan/routes/care-plan.routes'));
apiV1Router.use('/clinical-alerts', require('../modules/clinical-alert/routes/clinical-alert.routes'));
apiV1Router.use('/clinical-alert-thresholds', require('../modules/clinical-alert-threshold/routes/clinical-alert-threshold.routes'));
apiV1Router.use('/clinical-terms', require('../modules/clinical-term/routes/clinical-term.routes'));
apiV1Router.use('/clinical-term-favorites', require('../modules/clinical-term/routes/clinical-term-favorite.routes'));
apiV1Router.use('/encounters', require('../modules/encounter/routes/encounter.routes'));
apiV1Router.use('/clinical-notes', require('../modules/clinical-note/routes/clinical-note.routes'));
apiV1Router.use('/diagnoses', require('../modules/diagnosis/routes/diagnosis.routes'));
apiV1Router.use('/procedures', require('../modules/procedure/routes/procedure.routes'));
apiV1Router.use('/nursing-notes', require('../modules/nursing-note/routes/nursing-note.routes'));
apiV1Router.use('/medication-administrations', require('../modules/medication-administration/routes/medication-administration.routes'));
apiV1Router.use('/discharge-summaries', require('../modules/discharge-summary/routes/discharge-summary.routes'));
apiV1Router.use('/transfer-requests', require('../modules/transfer-request/routes/transfer-request.routes'));
apiV1Router.use('/icu-stays', require('../modules/icu-stay/routes/icu-stay.routes'));
apiV1Router.use('/icu-observations', require('../modules/icu-observation/routes/icu-observation.routes'));
apiV1Router.use('/critical-alerts', require('../modules/critical-alert/routes/critical-alert.routes'));
apiV1Router.use('/theatre-cases', require('../modules/theatre-case/routes/theatre-case.routes'));
apiV1Router.use('/anesthesia-records', require('../modules/anesthesia-record/routes/anesthesia-record.routes'));
apiV1Router.use('/post-op-notes', require('../modules/post-op-note/routes/post-op-note.routes'));
apiV1Router.use('/theatre-flows', require('../modules/theatre-flow/routes/theatre-flow.routes'));
apiV1Router.use('/drugs', require('../modules/drug/routes/drug.routes'));
apiV1Router.use('/drug-batches', require('../modules/drug-batch/routes/drug-batch.routes'));
apiV1Router.use('/formulary-items', require('../modules/formulary-item/routes/formulary-item.routes'));
apiV1Router.use('/pharmacy-orders', require('../modules/pharmacy-order/routes/pharmacy-order.routes'));
apiV1Router.use('/pharmacy-order-items', require('../modules/pharmacy-order-item/routes/pharmacy-order-item.routes'));
apiV1Router.use('/radiology-tests', require('../modules/radiology-test/routes/radiology-test.routes'));
apiV1Router.use('/radiology-orders', require('../modules/radiology-order/routes/radiology-order.routes'));
apiV1Router.use('/radiology-results', require('../modules/radiology-result/routes/radiology-result.routes'));
apiV1Router.use('/dispense-logs', require('../modules/dispense-log/routes/dispense-log.routes'));
apiV1Router.use('/adverse-events', require('../modules/adverse-event/routes/adverse-event.routes'));
apiV1Router.use('/inventory-items', require('../modules/inventory-item/routes/inventory-item.routes'));
apiV1Router.use('/inventory-stocks', require('../modules/inventory-stock/routes/inventory-stock.routes'));
apiV1Router.use('/stock-movements', require('../modules/stock-movement/routes/stock-movement.routes'));
apiV1Router.use('/suppliers', require('../modules/supplier/routes/supplier.routes'));
apiV1Router.use('/purchase-requests', require('../modules/purchase-request/routes/purchase-request.routes'));
apiV1Router.use('/purchase-orders', require('../modules/purchase-order/routes/purchase-order.routes'));
apiV1Router.use('/goods-receipts', require('../modules/goods-receipt/routes/goods-receipt.routes'));
apiV1Router.use('/stock-adjustments', require('../modules/stock-adjustment/routes/stock-adjustment.routes'));
apiV1Router.use('/lab-tests', require('../modules/lab-test/routes/lab-test.routes'));
apiV1Router.use('/lab-panels', require('../modules/lab-panel/routes/lab-panel.routes'));
apiV1Router.use('/lab-orders', require('../modules/lab-order/routes/lab-order.routes'));
apiV1Router.use('/lab-order-items', require('../modules/lab-order-item/routes/lab-order-item.routes'));
apiV1Router.use('/lab-samples', require('../modules/lab-sample/routes/lab-sample.routes'));
apiV1Router.use('/lab-results', require('../modules/lab-result/routes/lab-result.routes'));
apiV1Router.use('/lab-qc-logs', require('../modules/lab-qc-log/routes/lab-qc-log.routes'));
apiV1Router.use('/lab', require('../modules/lab-workspace/routes/lab-workspace.routes'));
apiV1Router.use('/radiology', require('../modules/radiology-workspace/routes/radiology-workspace.routes'));
apiV1Router.use('/pharmacy', require('../modules/pharmacy-workspace/routes/pharmacy-workspace.routes'));
apiV1Router.use('/imaging-studies', require('../modules/imaging-study/routes/imaging-study.routes'));
apiV1Router.use('/imaging-assets', require('../modules/imaging-asset/routes/imaging-asset.routes'));
apiV1Router.use('/pacs-links', require('../modules/pacs-link/routes/pacs-link.routes'));
apiV1Router.use('/emergency-cases', require('../modules/emergency-case/routes/emergency-case.routes'));
apiV1Router.use('/triage-assessments', require('../modules/triage-assessment/routes/triage-assessment.routes'));
apiV1Router.use('/emergency-responses', require('../modules/emergency-response/routes/emergency-response.routes'));
apiV1Router.use('/ambulances', require('../modules/ambulance/routes/ambulance.routes'));
apiV1Router.use('/ambulance-dispatches', require('../modules/ambulance-dispatch/routes/ambulance-dispatch.routes'));
apiV1Router.use('/ambulance-trips', require('../modules/ambulance-trip/routes/ambulance-trip.routes'));
apiV1Router.use('/invoices', require('../modules/invoice/routes/invoice.routes'));
apiV1Router.use('/invoice-items', require('../modules/invoice-item/routes/invoice-item.routes'));
apiV1Router.use('/payments', require('../modules/payment/routes/payment.routes'));
apiV1Router.use('/refunds', require('../modules/refund/routes/refund.routes'));
apiV1Router.use('/billing', require('../modules/billing/routes/billing.routes'));
apiV1Router.use('/pricing-rules', require('../modules/pricing-rule/routes/pricing-rule.routes'));
apiV1Router.use('/coverage-plans', require('../modules/coverage-plan/routes/coverage-plan.routes'));
apiV1Router.use('/insurance-claims', require('../modules/insurance-claim/routes/insurance-claim.routes'));
apiV1Router.use('/pre-authorizations', require('../modules/pre-authorization/routes/pre-authorization.routes'));
apiV1Router.use('/billing-adjustments', require('../modules/billing-adjustment/routes/billing-adjustment.routes'));
apiV1Router.use('/payroll-runs', require('../modules/payroll-run/routes/payroll-run.routes'));
apiV1Router.use('/payroll-items', require('../modules/payroll-item/routes/payroll-item.routes'));
apiV1Router.use('/hr', require('../modules/hr-workspace/routes/hr-workspace.routes'));
apiV1Router.use('/housekeeping', require('../modules/housekeeping-workspace/routes/housekeeping-workspace.routes'));
apiV1Router.use('/biomedical', require('../modules/biomedical-workspace/routes/biomedical-workspace.routes'));
apiV1Router.use('/mortuary', require('../modules/mortuary-workspace/routes/mortuary-workspace.routes'));
apiV1Router.use('/staff-positions', require('../modules/staff-position/routes/staff-position.routes'));
apiV1Router.use('/staff-profiles', require('../modules/staff-profile/routes/staff-profile.routes'));
apiV1Router.use('/staff-assignments', require('../modules/staff-assignment/routes/staff-assignment.routes'));
apiV1Router.use('/staff-leaves', require('../modules/staff-leave/routes/staff-leave.routes'));
apiV1Router.use('/housekeeping-tasks', require('../modules/housekeeping-task/routes/housekeeping-task.routes'));
apiV1Router.use('/housekeeping-schedules', require('../modules/housekeeping-schedule/routes/housekeeping-schedule.routes'));
apiV1Router.use('/maintenance-requests', require('../modules/maintenance-request/routes/maintenance-request.routes'));
apiV1Router.use('/assets', require('../modules/asset/routes/asset.routes'));
apiV1Router.use('/asset-service-logs', require('../modules/asset-service-log/routes/asset-service-log.routes'));
apiV1Router.use('/equipment-categories', require('../modules/equipment-category/routes/equipment-category.routes'));
apiV1Router.use('/equipment-registries', require('../modules/equipment-registry/routes/equipment-registry.routes'));
apiV1Router.use('/equipment-location-histories', require('../modules/equipment-location-history/routes/equipment-location-history.routes'));
apiV1Router.use('/equipment-maintenance-plans', require('../modules/equipment-maintenance-plan/routes/equipment-maintenance-plan.routes'));
apiV1Router.use('/equipment-work-orders', require('../modules/equipment-work-order/routes/equipment-work-order.routes'));
apiV1Router.use('/equipment-calibration-logs', require('../modules/equipment-calibration-log/routes/equipment-calibration-log.routes'));
apiV1Router.use('/equipment-safety-test-logs', require('../modules/equipment-safety-test-log/routes/equipment-safety-test-log.routes'));
apiV1Router.use('/equipment-downtime-logs', require('../modules/equipment-downtime-log/routes/equipment-downtime-log.routes'));
apiV1Router.use('/equipment-spare-parts', require('../modules/equipment-spare-part/routes/equipment-spare-part.routes'));
apiV1Router.use('/equipment-warranty-contracts', require('../modules/equipment-warranty-contract/routes/equipment-warranty-contract.routes'));
apiV1Router.use('/equipment-service-providers', require('../modules/equipment-service-provider/routes/equipment-service-provider.routes'));
apiV1Router.use('/equipment-incident-reports', require('../modules/equipment-incident-report/routes/equipment-incident-report.routes'));
apiV1Router.use('/equipment-recall-notices', require('../modules/equipment-recall-notice/routes/equipment-recall-notice.routes'));
apiV1Router.use('/equipment-utilization-snapshots', require('../modules/equipment-utilization-snapshot/routes/equipment-utilization-snapshot.routes'));
apiV1Router.use('/equipment-disposal-transfers', require('../modules/equipment-disposal-transfer/routes/equipment-disposal-transfer.routes'));
apiV1Router.use('/shifts', require('../modules/shift/routes/shift.routes'));
apiV1Router.use('/shift-assignments', require('../modules/shift-assignment/routes/shift-assignment.routes'));
apiV1Router.use('/shift-swap-requests', require('../modules/shift-swap-request/routes/shift-swap-request.routes'));
apiV1Router.use('/office-contexts', require('../modules/office-context/routes/office-context.routes'));
apiV1Router.use('/shift-closes', require('../modules/shift-close/routes/shift-close.routes'));
apiV1Router.use('/day-closes', require('../modules/day-close/routes/day-close.routes'));
apiV1Router.use('/handovers', require('../modules/handover/routes/handover.routes'));
apiV1Router.use('/custody-snapshots', require('../modules/custody-snapshot/routes/custody-snapshot.routes'));
apiV1Router.use('/closeout-packs', require('../modules/closeout-pack/routes/closeout-pack.routes'));
apiV1Router.use('/nurse-rosters', require('../modules/nurse-roster/routes/nurse-roster.routes'));
apiV1Router.use('/shift-templates', require('../modules/shift-template/routes/shift-template.routes'));
apiV1Router.use('/roster-day-offs', require('../modules/roster-day-off/routes/roster-day-off.routes'));
apiV1Router.use('/staff-availabilities', require('../modules/staff-availability/routes/staff-availability.routes'));
apiV1Router.use('/notifications', require('../modules/notification/routes/notification.routes'));
apiV1Router.use('/notification-deliveries', require('../modules/notification-delivery/routes/notification-delivery.routes'));
apiV1Router.use('/conversations', require('../modules/conversation/routes/conversation.routes'));
apiV1Router.use('/messages', require('../modules/message/routes/message.routes'));
apiV1Router.use('/communications-workspace', require('../modules/communications-workspace/routes/communications-workspace.routes'));
apiV1Router.use('/report-definitions', require('../modules/report-definition/routes/report-definition.routes'));
apiV1Router.use('/report-runs', require('../modules/report-run/routes/report-run.routes'));
apiV1Router.use('/report-schedules', require('../modules/report-schedule/routes/report-schedule.routes'));
apiV1Router.use('/dashboard-widgets', require('../modules/dashboard-widget/routes/dashboard-widget.routes'));
apiV1Router.use('/dashboard-workspace', require('../modules/dashboard-workspace/routes/dashboard-workspace.routes'));
apiV1Router.use('/settings-workspace', require('../modules/settings-workspace/routes/settings-workspace.routes'));
apiV1Router.use('/kpi-snapshots', require('../modules/kpi-snapshot/routes/kpi-snapshot.routes'));
apiV1Router.use('/analytics-events', require('../modules/analytics-event/routes/analytics-event.routes'));
apiV1Router.use('/reports-workspace', require('../modules/reports-workspace/routes/reports-workspace.routes'));
apiV1Router.use('/audit-logs', require('../modules/audit-log/routes/audit-log.routes'));
apiV1Router.use('/phi-access-logs', require('../modules/phi-access-log/routes/phi-access-log.routes'));
apiV1Router.use('/data-processing-logs', require('../modules/data-processing-log/routes/data-processing-log.routes'));
apiV1Router.use('/break-glass-access', require('../modules/break-glass-access/routes/break-glass-access.routes'));
apiV1Router.use('/break-glass-reviews', require('../modules/break-glass-review/routes/break-glass-review.routes'));
apiV1Router.use('/templates', require('../modules/template/routes/template.routes'));
apiV1Router.use('/template-variables', require('../modules/template-variable/routes/template-variable.routes'));
apiV1Router.use('/subscriptions-workspace', require('../modules/subscriptions-workspace/routes/subscriptions-workspace.routes'));
apiV1Router.use('/subscription-plans', require('../modules/subscription-plan/routes/subscription-plan.routes'));
apiV1Router.use('/subscriptions', require('../modules/subscription/routes/subscription.routes'));
apiV1Router.use('/subscription-invoices', require('../modules/subscription-invoice/routes/subscription-invoice.routes'));
apiV1Router.use('/modules', require('../modules/module/routes/module.routes'));
apiV1Router.use('/module-subscriptions', require('../modules/module-subscription/routes/module-subscription.routes'));
apiV1Router.use('/licenses', require('../modules/license/routes/license.routes'));
apiV1Router.use('/breach-notifications', require('../modules/breach-notification/routes/breach-notification.routes'));
apiV1Router.use('/system-change-logs', require('../modules/system-change-log/routes/system-change-log.routes'));
apiV1Router.use('/integrations', require('../modules/integration/routes/integration.routes'));
apiV1Router.use('/integration-logs', require('../modules/integration-log/routes/integration-log.routes'));
apiV1Router.use('/webhook-subscriptions', require('../modules/webhook-subscription/routes/webhook-subscription.routes'));
apiV1Router.use('/interop', require('../modules/interop/routes/interop.routes'));

// Mount API v1 router
router.use('/api/v1', apiV1Router);

module.exports = router;
