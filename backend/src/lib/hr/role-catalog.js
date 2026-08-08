/**
 * Hospital access-role catalog for HR assignment and display.
 * Labels use labels.hr.reference.role.{slug} keys for localization.
 *
 * @module lib/hr/role-catalog
 */

const { translate } = require('@lib/i18n');
const { DEFAULT_LOCALE } = require('@config/constants');
const { ROLES } = require('@config/roles');

const slugify = (value) =>
  String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');

const roleLabelKey = (code) => `labels.hr.reference.role.${slugify(code)}`;

/** @type {ReadonlyArray<{ code: string, defaultLabel: string, labelKey: string, category: string }>} */
const HR_ROLE_CATALOG = Object.freeze(
  [
  // Administration
    ['TENANT_ADMIN', 'Organization Administrator', 'administration'],
    ['FACILITY_ADMIN', 'Facility Administrator', 'administration'],
    ['HR', 'HR / Workforce Manager', 'administration'],
    ['OPERATIONS', 'Operations Manager', 'administration'],
    ['IT_SUPPORT', 'IT Support Specialist', 'administration'],
  // Clinical — physicians
    ['DOCTOR', 'Doctor / Clinician', 'clinical_physician'],
    ['ATTENDING_PHYSICIAN', 'Attending Physician', 'clinical_physician'],
    ['RESIDENT_PHYSICIAN', 'Resident Physician', 'clinical_physician'],
    ['SURGEON', 'Surgeon', 'clinical_physician'],
    ['ANESTHESIOLOGIST', 'Anesthesiologist', 'clinical_physician'],
    ['PHYSICIAN_ASSISTANT', 'Physician Assistant (PA)', 'clinical_physician'],
    ['EMERGENCY_PHYSICIAN', 'Emergency Medicine Physician', 'clinical_physician'],
  // Clinical — nursing
    ['NURSE', 'Registered Nurse (RN)', 'clinical_nursing'],
    ['LICENSED_PRACTICAL_NURSE', 'Licensed Practical Nurse (LPN)', 'clinical_nursing'],
    ['NURSE_PRACTITIONER', 'Nurse Practitioner (NP)', 'clinical_nursing'],
    ['TRIAGE_NURSE', 'Triage Nurse', 'clinical_nursing'],
    ['MIDWIFE', 'Midwife', 'clinical_nursing'],
    ['CHARGE_NURSE', 'Charge Nurse', 'clinical_nursing'],
  // Clinical — allied health
    ['PHYSIOTHERAPIST', 'Physiotherapist / Physical Therapist', 'allied_health'],
    ['OCCUPATIONAL_THERAPIST', 'Occupational Therapist', 'allied_health'],
    ['RESPIRATORY_THERAPIST', 'Respiratory Therapist', 'allied_health'],
    ['DIETITIAN', 'Dietitian / Nutritionist', 'allied_health'],
    ['SOCIAL_WORKER', 'Medical Social Worker', 'allied_health'],
    ['CLINICAL_PSYCHOLOGIST', 'Clinical Psychologist', 'allied_health'],
  // Diagnostics & pharmacy
    ['LAB_TECH', 'Laboratory Technologist', 'diagnostics'],
    ['MEDICAL_LABORATORY_SCIENTIST', 'Medical Laboratory Scientist', 'diagnostics'],
    ['PATHOLOGIST', 'Pathologist', 'diagnostics'],
    ['RADIOLOGY_TECH', 'Radiology / Imaging Technologist', 'diagnostics'],
    ['SONOGRAPHER', 'Sonographer / Ultrasound Technologist', 'diagnostics'],
    ['PHARMACIST', 'Pharmacist', 'diagnostics'],
    ['PHARMACY_TECHNICIAN', 'Pharmacy Technician', 'diagnostics'],
  // Front office & revenue
    ['RECEPTIONIST', 'Receptionist / Front Desk', 'front_office'],
    ['ADMISSIONS_COORDINATOR', 'Admissions Coordinator', 'front_office'],
    ['MEDICAL_RECORDS_CLERK', 'Medical Records Clerk', 'front_office'],
    ['BILLING', 'Billing / Cashier', 'front_office'],
    ['MEDICAL_CODER', 'Medical Coder / Coding Specialist', 'front_office'],
  // Emergency & transport
    ['AMBULANCE_OPERATOR', 'Ambulance Operator', 'emergency'],
    ['PARAMEDIC', 'Paramedic', 'emergency'],
    ['EMT', 'Emergency Medical Technician (EMT)', 'emergency'],
  // Facilities & support
    ['HOUSE_KEEPER', 'Housekeeping Staff', 'facilities'],
    ['HOUSEKEEPING_MANAGER', 'Housekeeping Manager', 'facilities'],
    ['FOOD_SERVICE_WORKER', 'Food Service Worker', 'facilities'],
    ['PORTER', 'Porter / Orderly', 'facilities'],
    ['SECURITY_OFFICER', 'Security Officer', 'facilities'],
    ['MAINTENANCE_ENGINEER', 'Maintenance Engineer', 'facilities'],
    ['CHAPLAIN', 'Hospital Chaplain', 'facilities'],
  // Biomedical
    ['BIOMED', 'Biomedical Engineer / Technician', 'biomedical'],
    ['BIOMED_MANAGER', 'Biomedical Manager', 'biomedical'],
  // Unit & department management
    ['UNIT_MANAGER', 'Unit Manager', 'management'],
    ['WARD_MANAGER', 'Ward Manager / Charge Nurse', 'management'],
    ['ICU_MANAGER', 'ICU Manager', 'management'],
    ['THEATRE_MANAGER', 'Theatre / Perioperative Manager', 'management'],
  // Mortuary
    ['MORTUARY_STAFF', 'Mortuary Attendant', 'mortuary'],
    ['MORTUARY_MANAGER', 'Mortuary Manager', 'mortuary'],
  ].map(([code, defaultLabel, category]) => ({
    code,
    defaultLabel,
    labelKey: roleLabelKey(code),
    category,
  }))
);

const HR_ASSIGNABLE_ROLE_NAMES = Object.freeze(
  HR_ROLE_CATALOG.map((entry) => entry.code).filter(
    (code) =>
      ![ROLES.PLATFORM_OWNER, ROLES.PLATFORM_ADMIN, ROLES.PATIENT, ROLES.OTHER].includes(
        code
      )
  )
);

const ROLE_BY_CODE = new Map(HR_ROLE_CATALOG.map((entry) => [entry.code, entry]));

const CATEGORY_ORDER = Object.freeze([
  'clinical_physician',
  'clinical_nursing',
  'allied_health',
  'diagnostics',
  'emergency',
  'front_office',
  'management',
  'administration',
  'biomedical',
  'facilities',
  'mortuary',
]);

const resolveLabel = (labelKey, locale = DEFAULT_LOCALE, fallback = '') =>
  translate(labelKey, locale) || fallback;

const roleLabel = (code, locale = DEFAULT_LOCALE) => {
  const normalized = String(code || '').trim().toUpperCase();
  const entry = ROLE_BY_CODE.get(normalized);
  if (!entry) {
    return normalized.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());
  }
  return resolveLabel(entry.labelKey, locale, entry.defaultLabel);
};

const roleLabelKeyForCode = (code) => {
  const normalized = String(code || '').trim().toUpperCase();
  return ROLE_BY_CODE.get(normalized)?.labelKey || null;
};

const compareRoleCatalogEntries = (left, right) => {
  const leftIndex = CATEGORY_ORDER.indexOf(left.category);
  const rightIndex = CATEGORY_ORDER.indexOf(right.category);
  if (leftIndex !== rightIndex) {
    return leftIndex - rightIndex;
  }
  return left.defaultLabel.localeCompare(right.defaultLabel);
};

const enrichRoleOption = (entry, locale = DEFAULT_LOCALE) => {
  const code = String(entry?.name || '').trim().toUpperCase();
  if (!code) {
    return null;
  }
  const catalogEntry = ROLE_BY_CODE.get(code);
  const labelKey = catalogEntry?.labelKey || roleLabelKeyForCode(code);
  const label = labelKey
    ? resolveLabel(labelKey, locale, catalogEntry?.defaultLabel || code)
    : roleLabel(code, locale);

  return {
    value: entry.human_friendly_id || entry.id || code,
    label,
    label_key: labelKey,
    display_id: entry.human_friendly_id || null,
    name: code,
    category: catalogEntry?.category || null,
    permission_count: Array.isArray(entry.permissions) ? entry.permissions.length : 0,
    is_system_critical: Boolean(entry.is_system_critical),
  };
};

const sortRoleRecords = (records = []) =>
  [...records].sort((left, right) => {
    const leftEntry = ROLE_BY_CODE.get(String(left?.name || '').toUpperCase());
    const rightEntry = ROLE_BY_CODE.get(String(right?.name || '').toUpperCase());
    if (leftEntry && rightEntry) {
      return compareRoleCatalogEntries(leftEntry, rightEntry);
    }
    return String(left?.name || '').localeCompare(String(right?.name || ''));
  });

module.exports = {
  HR_ROLE_CATALOG,
  HR_ASSIGNABLE_ROLE_NAMES,
  ROLE_BY_CODE,
  roleLabel,
  roleLabelKeyForCode,
  enrichRoleOption,
  sortRoleRecords,
};
