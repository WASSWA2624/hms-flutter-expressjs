/**
 * Feature flag configuration
 */

const FALSE_VALUES = new Set(['0', 'false', 'off', 'no']);

const parseFlag = (value, defaultValue = true) => {
  if (value == null || value === '') return Boolean(defaultValue);
  return !FALSE_VALUES.has(String(value).trim().toLowerCase());
};

const defaultWorkspaceFlag = (defaultValue = false) => {
  const appEnvironment = String(process.env.NODE_ENV || '').trim().toLowerCase();
  if (appEnvironment && appEnvironment !== 'production') return true;
  return Boolean(defaultValue);
};

const FEATURE_FLAGS = Object.freeze({
  clinical_workbench_v2: parseFlag(process.env.FEATURE_CLINICAL_WORKBENCH_V2, true),
  clinical_alert_auto_rules: parseFlag(process.env.FEATURE_CLINICAL_ALERT_AUTO_RULES, true),
  follow_up_reminder_dispatch: parseFlag(process.env.FEATURE_FOLLOW_UP_REMINDER_DISPATCH, true),
  ipd_workbench_v1: parseFlag(process.env.FEATURE_IPD_WORKBENCH_V1, false),
  billing_workspace_v1: parseFlag(process.env.FEATURE_BILLING_WORKSPACE_V1, false),
  pharmacy_workspace_v1: parseFlag(process.env.PHARMACY_WORKSPACE_V1, false),
  communications_workspace_v1: parseFlag(
    process.env.FEATURE_COMMUNICATIONS_WORKSPACE_V1,
    defaultWorkspaceFlag(false)
  ),
  subscriptions_workspace_v1: parseFlag(
    process.env.FEATURE_SUBSCRIPTIONS_WORKSPACE_V1,
    defaultWorkspaceFlag(false)
  ),
  dashboard_workspace_v1: parseFlag(
    process.env.FEATURE_DASHBOARD_WORKSPACE_V1,
    true
  ),
  settings_workspace_v1: parseFlag(
    process.env.FEATURE_SETTINGS_WORKSPACE_V1,
    defaultWorkspaceFlag(false)
  ),
  hr_workspace_v1: parseFlag(process.env.FEATURE_HR_WORKSPACE_V1, true),
  housekeeping_workspace_v1: parseFlag(process.env.FEATURE_HOUSEKEEPING_WORKSPACE_V1, true),
  biomedical_workspace_v1: parseFlag(process.env.FEATURE_BIOMEDICAL_WORKSPACE_V1, true),
  mortuary_workspace_v1: parseFlag(process.env.FEATURE_MORTUARY_WORKSPACE_V1, true),
  reports_workspace_v1: parseFlag(process.env.FEATURE_REPORTS_WORKSPACE_V1, true),
  radiology_attestation_v2: parseFlag(process.env.RADIOLOGY_ATTESTATION_V2, false),
});

const isFeatureEnabled = (flagName) => Boolean(FEATURE_FLAGS[flagName]);

module.exports = {
  FEATURE_FLAGS,
  isFeatureEnabled,
};
