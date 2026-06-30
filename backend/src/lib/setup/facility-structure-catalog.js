/**
 * Default hospital department catalog for facility bootstrap and HR reference data.
 *
 * @module lib/setup/facility-structure-catalog
 */

const DEFAULT_FACILITY_DEPARTMENT_NAMES = Object.freeze([
  'Outpatient',
  'Inpatient',
  'Emergency',
  'Laboratory',
  'Radiology',
  'Pharmacy',
  'Billing',
  'Operations',
  'Biomedical',
  'Front Office',
  'Compliance',
  'Support Services',
  'Human Resources',
  'Nursing',
  'ICU',
  'Theatre',
  'Housekeeping',
  'Ambulance',
  'IT',
  'Mortuary',
]);

const inferDepartmentType = (name = '') => {
  const normalized = String(name).trim().toLowerCase();
  if (/billing|executive|compliance|it|front office|operations|hr|human resources/i.test(normalized)) {
    return 'ADMINISTRATIVE';
  }
  if (/lab|radiology|diagnostics|research/i.test(normalized)) {
    return 'DIAGNOSTICS';
  }
  if (/housekeeping|support|mortuary|ambulance/i.test(normalized)) {
    return 'SUPPORT';
  }
  return 'CLINICAL';
};

module.exports = {
  DEFAULT_FACILITY_DEPARTMENT_NAMES,
  inferDepartmentType,
};
