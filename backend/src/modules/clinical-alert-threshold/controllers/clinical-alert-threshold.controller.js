/**
 * Clinical alert threshold controller
 */

const clinicalAlertThresholdService = require('@services/clinical-alert-threshold/clinical-alert-threshold.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');

const buildAuditContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  ip_address: req.ip,
});

const listClinicalAlertThresholds = asyncHandler(async (req, res) => {
  const payload = {
    ...req.query,
    tenant_id: req.query?.tenant_id || req.user?.tenant_id,
  };
  const result = await clinicalAlertThresholdService.listClinicalAlertThresholds(
    payload,
    buildAuditContext(req)
  );

  return sendSuccess(res, 200, 'messages.clinical_alert_threshold.list.success', result);
});

const updateClinicalAlertThresholds = asyncHandler(async (req, res) => {
  const payload = {
    ...req.body,
    tenant_id: req.body?.tenant_id || req.user?.tenant_id,
  };
  const result = await clinicalAlertThresholdService.updateClinicalAlertThresholds(
    payload,
    buildAuditContext(req)
  );

  return sendSuccess(res, 200, 'messages.clinical_alert_threshold.update.success', result);
});

module.exports = {
  listClinicalAlertThresholds,
  updateClinicalAlertThresholds,
};

