/**
 * Shared HR reference-data catalog for onboarding, staff profiles, and payroll.
 * All user-facing labels use labels.hr.reference.{category}.{slug} keys for localization.
 *
 * @module lib/hr/reference-data
 */

const { translate } = require('@lib/i18n');
const { DEFAULT_LOCALE } = require('@config/constants');

const slugify = (value) =>
  String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');

const staffPositionLabelKey = (code) =>
  `labels.hr.reference.staff_position.${slugify(code)}`;

const practitionerTypeLabelKey = (code) =>
  `labels.hr.reference.practitioner_type.${slugify(code)}`;

const compensationPayTypeLabelKey = (code) =>
  `labels.hr.reference.compensation_pay_type.${slugify(code)}`;

/** @type {ReadonlyArray<{ code: string, defaultName: string, labelKey: string }>} */
const STAFF_POSITION_CATALOG = Object.freeze(
  [
    ['NURSE', 'Nurse'],
    ['SENIOR_NURSE', 'Senior Nurse'],
    ['STAFF_NURSE', 'Staff Nurse'],
    ['THEATRE_NURSE', 'Theatre Nurse'],
    ['SCRUB_NURSE', 'Scrub Nurse'],
    ['WARD_MANAGER', 'Ward Manager'],
    ['MIDWIFE', 'Midwife'],
    ['NURSING_ASSISTANT', 'Nursing Assistant'],
    ['DOCTOR', 'Doctor'],
    ['CONSULTANT_PHYSICIAN', 'Consultant Physician'],
    ['MEDICAL_OFFICER', 'Medical Officer'],
    ['RESIDENT_DOCTOR', 'Resident Doctor'],
    ['INTERN', 'Intern'],
    ['GENERAL_PRACTITIONER', 'General Practitioner'],
    ['SURGEON', 'Surgeon'],
    ['ANAESTHETIST', 'Anaesthetist'],
    ['PAEDIATRICIAN', 'Paediatrician'],
    ['OBGYN', 'Obstetrician/Gynaecologist'],
    ['PSYCHIATRIST', 'Psychiatrist'],
    ['EMERGENCY_PHYSICIAN', 'Emergency Physician'],
    ['FAMILY_MEDICINE_PHYSICIAN', 'Family Medicine Physician'],
    ['DENTAL_SURGEON', 'Dental Surgeon'],
    ['NURSE_PRACTITIONER', 'Nurse Practitioner'],
    ['PHYSIOTHERAPIST', 'Physiotherapist'],
    ['OCCUPATIONAL_THERAPIST', 'Occupational Therapist'],
    ['SPEECH_THERAPIST', 'Speech Therapist'],
    ['DIETITIAN', 'Dietitian'],
    ['CLINICAL_PSYCHOLOGIST', 'Clinical Psychologist'],
    ['SOCIAL_WORKER', 'Social Worker'],
    ['RESPIRATORY_THERAPIST', 'Respiratory Therapist'],
    ['LAB_TECHNOLOGIST', 'Lab Technologist'],
    ['MEDICAL_LABORATORY_SCIENTIST', 'Medical Laboratory Scientist'],
    ['PHLEBOTOMIST', 'Phlebotomist'],
    ['RADIOLOGIST', 'Radiologist'],
    ['SONOGRAPHER', 'Sonographer'],
    ['ECG_TECHNICIAN', 'ECG Technician'],
    ['PHARMACIST', 'Pharmacist'],
    ['PHARMACY_TECHNICIAN', 'Pharmacy Technician'],
    ['PHARMACY_ASSISTANT', 'Pharmacy Assistant'],
    ['ADMINISTRATOR', 'Administrator'],
    ['HR_OFFICER', 'HR Officer'],
    ['RECEPTIONIST', 'Receptionist'],
    ['MEDICAL_RECORDS_OFFICER', 'Medical Records Officer'],
    ['HEALTH_INFORMATION_OFFICER', 'Health Information Officer'],
    ['PATIENT_RELATIONS_OFFICER', 'Patient Relations Officer'],
    ['BILLING_CLERK', 'Billing Clerk'],
    ['ACCOUNTS_OFFICER', 'Accounts Officer'],
    ['INSURANCE_OFFICER', 'Insurance Officer'],
    ['CASHIER', 'Cashier'],
    ['HOUSEKEEPER', 'Housekeeper'],
    ['PORTER', 'Porter'],
    ['SECURITY_OFFICER', 'Security Officer'],
    ['LAUNDRY_ATTENDANT', 'Laundry Attendant'],
    ['KITCHEN_STAFF', 'Kitchen Staff'],
    ['MORTUARY_ATTENDANT', 'Mortuary Attendant'],
    ['AMBULANCE_DRIVER', 'Ambulance Driver'],
    ['AMBULANCE_OPERATOR', 'Ambulance Operator'],
    ['BIOMEDICAL_ENGINEER', 'Biomedical Engineer'],
    ['IT_SUPPORT_OFFICER', 'IT Support Officer'],
    ['MAINTENANCE_TECHNICIAN', 'Maintenance Technician'],
    ['HOSPITAL_ADMINISTRATOR', 'Hospital Administrator'],
    ['DEPARTMENT_HEAD', 'Department Head'],
    ['CHIEF_NURSING_OFFICER', 'Chief Nursing Officer'],
    ['OPERATIONS_MANAGER', 'Operations Manager'],
    ['FACILITY_MANAGER', 'Facility Manager'],
  ].map(([code, defaultName]) => ({
    code,
    defaultName,
    labelKey: staffPositionLabelKey(code),
  }))
);

/** @type {ReadonlyArray<{ code: string, labelKey: string, clinicalPrescriber: boolean, consultationFeeEligible: boolean }>} */
const PRACTITIONER_TYPE_CATALOG = Object.freeze(
  [
    ['MO', true, true],
    ['SPECIALIST', true, true],
    ['RESIDENT', true, true],
    ['INTERN', false, false],
    ['GP', true, true],
    ['SURGEON', true, true],
    ['ANAESTHETIST', true, true],
    ['PAEDIATRICIAN', true, true],
    ['OBGYN', true, true],
    ['NURSE_PRACTITIONER', true, true],
    ['DENTIST', true, true],
    ['PSYCHIATRIST', true, true],
    ['EMERGENCY_MEDICINE', true, true],
    ['FAMILY_MEDICINE', true, true],
    ['PATHOLOGIST', true, false],
    ['RADIOLOGIST', true, false],
    ['DERMATOLOGIST', true, true],
    ['CARDIOLOGIST', true, true],
    ['OPHTHALMOLOGIST', true, true],
    ['ORTHOPAEDIC_SURGEON', true, true],
  ].map(([code, clinicalPrescriber, consultationFeeEligible]) => ({
    code,
    labelKey: practitionerTypeLabelKey(code),
    clinicalPrescriber,
    consultationFeeEligible,
  }))
);

/** @type {ReadonlyArray<{ code: string, labelKey: string }>} */
const COMPENSATION_PAY_TYPE_CATALOG = Object.freeze(
  [
    'PER_CONSULTATION',
    'PER_MONTH',
    'PER_DAY',
    'PER_HOUR',
    'PER_PROCEDURE',
  ].map((code) => ({
    code,
    labelKey: compensationPayTypeLabelKey(code),
  }))
);

const CLINICAL_PRESCRIBER_ROLE_NAMES = Object.freeze(['DOCTOR', 'SPECIALIST']);

const DEFAULT_STAFF_POSITION_NAMES = Object.freeze(
  STAFF_POSITION_CATALOG.map((entry) => entry.defaultName)
);

const PRACTITIONER_TYPE_OPTIONS = Object.freeze(
  PRACTITIONER_TYPE_CATALOG.map((entry) => entry.code)
);

const PRACTITIONER_TYPES = new Set(PRACTITIONER_TYPE_OPTIONS);

const PRACTITIONER_TYPE_LABELS = Object.freeze(
  Object.fromEntries(
    PRACTITIONER_TYPE_CATALOG.map((entry) => [entry.code, entry.labelKey])
  )
);

const CONSULTATION_FEE_PRACTITIONER_TYPES = new Set(
  PRACTITIONER_TYPE_CATALOG.filter((entry) => entry.consultationFeeEligible).map(
    (entry) => entry.code
  )
);

const COMPENSATION_PAY_TYPES = Object.freeze(
  COMPENSATION_PAY_TYPE_CATALOG.map((entry) => entry.code)
);

const STAFF_POSITION_BY_NAME = new Map(
  STAFF_POSITION_CATALOG.map((entry) => [
    entry.defaultName.trim().toLowerCase(),
    entry,
  ])
);

const STAFF_POSITION_BY_CODE = new Map(
  STAFF_POSITION_CATALOG.map((entry) => [entry.code, entry])
);

const PRACTITIONER_TYPE_BY_CODE = new Map(
  PRACTITIONER_TYPE_CATALOG.map((entry) => [entry.code, entry])
);

const resolveLabel = (labelKey, locale = DEFAULT_LOCALE, fallback = '') =>
  translate(labelKey, locale) || fallback;

const practitionerTypeLabel = (value, locale = DEFAULT_LOCALE) => {
  const normalized = String(value || '').trim().toUpperCase();
  const entry = PRACTITIONER_TYPE_BY_CODE.get(normalized);
  if (!entry) {
    return normalized;
  }
  return resolveLabel(entry.labelKey, locale, normalized);
};

const staffPositionLabel = (value, locale = DEFAULT_LOCALE) => {
  const normalized = String(value || '').trim();
  if (!normalized) {
    return '';
  }
  const entry =
    STAFF_POSITION_BY_NAME.get(normalized.toLowerCase()) ||
    STAFF_POSITION_BY_CODE.get(normalized.toUpperCase());
  if (!entry) {
    return normalized;
  }
  return resolveLabel(entry.labelKey, locale, entry.defaultName);
};

const staffPositionLabelKeyForName = (value) => {
  const normalized = String(value || '').trim();
  if (!normalized) {
    return null;
  }
  const entry =
    STAFF_POSITION_BY_NAME.get(normalized.toLowerCase()) ||
    STAFF_POSITION_BY_CODE.get(normalized.toUpperCase());
  return entry?.labelKey || null;
};

const compensationPayTypeLabel = (value, locale = DEFAULT_LOCALE) => {
  const normalized = String(value || '').trim().toUpperCase();
  const entry = COMPENSATION_PAY_TYPE_CATALOG.find((item) => item.code === normalized);
  if (!entry) {
    return normalized;
  }
  return resolveLabel(entry.labelKey, locale, normalized);
};

const buildLocalizedOption = (value, labelKey, fallbackLabel, locale = DEFAULT_LOCALE) => ({
  value,
  label: resolveLabel(labelKey, locale, fallbackLabel),
  label_key: labelKey,
});

const practitionerTypeOptions = (locale = DEFAULT_LOCALE) =>
  PRACTITIONER_TYPE_CATALOG.map((entry) =>
    buildLocalizedOption(entry.code, entry.labelKey, entry.code, locale)
  );

const compensationPayTypeOptions = (locale = DEFAULT_LOCALE) =>
  COMPENSATION_PAY_TYPE_CATALOG.map((entry) =>
    buildLocalizedOption(entry.code, entry.labelKey, entry.code, locale)
  );

const staffPositionCatalogOptions = (locale = DEFAULT_LOCALE) =>
  STAFF_POSITION_CATALOG.map((entry) =>
    buildLocalizedOption(entry.defaultName, entry.labelKey, entry.defaultName, locale)
  );

const enrichStaffPositionOption = (entry, locale = DEFAULT_LOCALE) => {
  const name = String(entry?.name || '').trim();
  if (!name) {
    return null;
  }
  const labelKey = staffPositionLabelKeyForName(name);
  return {
    value: entry.human_friendly_id || entry.id || name,
    label: labelKey
      ? resolveLabel(labelKey, locale, name)
      : name,
    label_key: labelKey,
    display_id: entry.human_friendly_id || null,
    name,
    department_id: entry.department_id || null,
    is_active: entry.is_active !== false,
  };
};

const isClinicalPrescriberPractitionerType = (value) => {
  const normalized = String(value || '').trim().toUpperCase();
  const entry = PRACTITIONER_TYPE_BY_CODE.get(normalized);
  return Boolean(entry?.clinicalPrescriber);
};

const isConsultationFeePractitionerType = (value) => {
  const normalized = String(value || '').trim().toUpperCase();
  return CONSULTATION_FEE_PRACTITIONER_TYPES.has(normalized);
};

module.exports = {
  STAFF_POSITION_CATALOG,
  PRACTITIONER_TYPE_CATALOG,
  COMPENSATION_PAY_TYPE_CATALOG,
  CLINICAL_PRESCRIBER_ROLE_NAMES,
  DEFAULT_STAFF_POSITION_NAMES,
  PRACTITIONER_TYPE_OPTIONS,
  PRACTITIONER_TYPE_LABELS,
  PRACTITIONER_TYPES,
  CONSULTATION_FEE_PRACTITIONER_TYPES,
  COMPENSATION_PAY_TYPES,
  practitionerTypeLabel,
  staffPositionLabel,
  staffPositionLabelKeyForName,
  compensationPayTypeLabel,
  practitionerTypeOptions,
  compensationPayTypeOptions,
  staffPositionCatalogOptions,
  enrichStaffPositionOption,
  isClinicalPrescriberPractitionerType,
  isConsultationFeePractitionerType,
};
