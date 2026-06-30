/**
 * Shared HR reference-data constants for onboarding and staff profiles.
 *
 * @module lib/hr/reference-data
 */

const DEFAULT_STAFF_POSITION_NAMES = Object.freeze([
  'Nurse',
  'Doctor',
  'Pharmacist',
  'Lab Technologist',
  'Radiologist',
  'Receptionist',
  'HR Officer',
  'Administrator',
  'Ward Manager',
  'Theatre Nurse',
  'Billing Clerk',
  'Housekeeper',
  'Biomedical Engineer',
  'Mortuary Attendant',
  'Security Officer',
  'Porter',
  'Dietitian',
  'Physiotherapist',
  'Anaesthetist',
  'Surgeon',
  'Midwife',
]);

const PRACTITIONER_TYPE_OPTIONS = Object.freeze([
  'MO',
  'SPECIALIST',
  'RESIDENT',
  'INTERN',
  'GP',
  'SURGEON',
  'ANAESTHETIST',
  'PAEDIATRICIAN',
  'OBGYN',
]);

const PRACTITIONER_TYPE_LABELS = Object.freeze({
  MO: 'Medical Officer (MO)',
  SPECIALIST: 'Specialist / Consultant',
  RESIDENT: 'Resident / Registrar',
  INTERN: 'Intern / House Officer',
  GP: 'General Practitioner (GP)',
  SURGEON: 'Surgeon',
  ANAESTHETIST: 'Anaesthetist',
  PAEDIATRICIAN: 'Paediatrician',
  OBGYN: 'Obstetrician/Gynaecologist',
});

/** Practitioner types that may carry a consultation fee. */
const CONSULTATION_FEE_PRACTITIONER_TYPES = new Set([
  'MO',
  'SPECIALIST',
  'GP',
  'SURGEON',
  'ANAESTHETIST',
  'PAEDIATRICIAN',
  'OBGYN',
  'RESIDENT',
]);

const PRACTITIONER_TYPES = new Set(PRACTITIONER_TYPE_OPTIONS);

const COMPENSATION_PAY_TYPES = Object.freeze([
  'PER_CONSULTATION',
  'PER_MONTH',
  'PER_DAY',
  'PER_HOUR',
  'PER_PROCEDURE',
]);

const practitionerTypeLabel = (value) =>
  PRACTITIONER_TYPE_LABELS[value] || value;

const practitionerTypeOptions = () =>
  PRACTITIONER_TYPE_OPTIONS.map((value) => ({
    value,
    label: practitionerTypeLabel(value),
  }));

module.exports = {
  DEFAULT_STAFF_POSITION_NAMES,
  PRACTITIONER_TYPE_OPTIONS,
  PRACTITIONER_TYPE_LABELS,
  PRACTITIONER_TYPES,
  CONSULTATION_FEE_PRACTITIONER_TYPES,
  COMPENSATION_PAY_TYPES,
  practitionerTypeLabel,
  practitionerTypeOptions,
};
