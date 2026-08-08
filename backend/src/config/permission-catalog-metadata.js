/**
 * Human-readable labels and descriptions for the canonical permission and role catalog.
 *
 * Stable machine codes remain in `name`; `display_name` and `description` are synced
 * into tenant-scoped database rows by permission-catalog-sync.
 */

const DOMAIN_LABELS = Object.freeze({
  profile: 'Profile',
  patient: 'Patient',
  patients: 'Patients Registry',
  reception: 'Reception',
  opd: 'OPD',
  ipd: 'IPD',
  rooms_beds: 'Rooms & Beds',
  icu: 'ICU',
  nursing: 'Nursing',
  physiotherapy: 'Physiotherapy',
  theater: 'Theater',
  discharge: 'Discharge',
  clinical: 'Clinical',
  emergency: 'Emergency',
  lab: 'Lab',
  radiology: 'Radiology',
  pharmacy: 'Pharmacy',
  billing: 'Billing',
  pricing: 'Pricing',
  claims: 'Claims',
  operations: 'Operations',
  housekeeping: 'Housekeeping',
  hr: 'HR',
  unit: 'Unit',
  roster: 'Roster',
  biomed: 'Biomed',
  mortuary: 'Mortuary',
  communications: 'Communications',
  integration: 'Integration',
  reports: 'Reports',
  subscriptions: 'Subscriptions',
  last_office: 'Last Office',
  compliance: 'Compliance',
  break_glass: 'Break Glass',
  evidence: 'Evidence',
  financial: 'Financial',
  facility: 'Facility',
  tenant: 'Tenant',
  system: 'System',
  setup: 'Administrative Setup',
  access_admin: 'Access Admin',
});

const ACTION_LABELS = Object.freeze({
  read: 'Read',
  write: 'Write',
  delete: 'Delete',
  update: 'Update',
  manage: 'Manage',
  publish: 'Publish',
  approve: 'Approve',
  release: 'Release',
  manage_storage: 'Manage Storage',
  post_mortem_request: 'Post-Mortem Request',
  billing_event: 'Billing Event',
  export: 'Export',
  audit: 'Audit',
  review: 'Review',
  request: 'Request',
  admin: 'Admin',
});

const PERMISSION_OVERRIDES = Object.freeze({
  'facility:admin': {
    displayName: 'Facility — Admin',
    description: 'Manage facility configuration, users, and operational settings.',
  },
  'tenant:admin': {
    displayName: 'Tenant — Admin',
    description: 'Manage tenant-wide settings, facilities, subscriptions, and access.',
  },
  'platform:admin': {
    displayName: 'Platform — Admin',
    description: 'Full platform administration across tenants and global settings.',
  },
  'platform:owner': {
    displayName: 'Platform — Owner',
    description:
      'Highest platform authority. Manage platform administrators and owner-only controls.',
  },
  'financial:approve': {
    displayName: 'Financial — Approve',
    description: 'Approve financial transactions, adjustments, and billing exceptions.',
  },
  'pricing:pharmacy_read': {
    displayName: 'Pricing — Pharmacy Read',
    description: 'View pharmacy retail / OTC sell prices on the drug catalog.',
  },
  'pricing:pharmacy_write': {
    displayName: 'Pricing — Pharmacy Write',
    description: 'Set pharmacy retail / OTC sell prices on the drug catalog.',
  },
  'pricing:facility_read': {
    displayName: 'Pricing — Facility Read',
    description: 'View facility encounter tariffs for pharmacy offerings and related price books.',
  },
  'pricing:facility_write': {
    displayName: 'Pricing — Facility Write',
    description: 'Set facility encounter tariffs for pharmacy offerings and facility price-book rows.',
  },
  'reception:read': {
    displayName: 'Reception — Read',
    description: 'Open the Reception workspace menu and route.',
  },
  'patients:read': {
    displayName: 'Patients Registry — Read',
    description: 'Open the Patients registry menu and route.',
  },
  'opd:read': {
    displayName: 'OPD — Read',
    description: 'Open the OPD workspace menu and route.',
  },
  'ipd:read': {
    displayName: 'IPD — Read',
    description: 'Open the IPD workspace menu and route.',
  },
  'rooms_beds:read': {
    displayName: 'Rooms & Beds — Read',
    description: 'Open the Rooms & beds workspace menu and route.',
  },
  'icu:read': {
    displayName: 'ICU — Read',
    description: 'Open the ICU workspace menu and route.',
  },
  'nursing:read': {
    displayName: 'Nursing — Read',
    description: 'Open the Nursing workspace menu and route.',
  },
  'physiotherapy:read': {
    displayName: 'Physiotherapy — Read',
    description: 'Open the Physiotherapy workspace menu and route.',
  },
  'theater:read': {
    displayName: 'Theater — Read',
    description: 'Open the Theater workspace menu and route.',
  },
  'discharge:read': {
    displayName: 'Discharge — Read',
    description: 'Open the Discharge workspace menu and route.',
  },
  'claims:read': {
    displayName: 'Claims — Read',
    description: 'Open the Claims workspace menu and route.',
  },
  'housekeeping:read': {
    displayName: 'Housekeeping — Read',
    description: 'Open the Housekeeping workspace menu and route.',
  },
  'setup:read': {
    displayName: 'Setup — Read',
    description: 'Open the Administrative setup menu and route.',
  },
  'access_admin:read': {
    displayName: 'Access Admin — Read',
    description: 'Open the Access admin menu and route; assignable to roles and users.',
  },
  'evidence:export': {
    displayName: 'Evidence — Export',
    description: 'Export audit evidence and compliance records for review.',
  },
  'break_glass:request': {
    displayName: 'Break Glass — Request',
    description: 'Request temporary elevated access to restricted patient records.',
  },
  'break_glass:review': {
    displayName: 'Break Glass — Review',
    description: 'Review break-glass access requests submitted by clinical staff.',
  },
  'break_glass:approve': {
    displayName: 'Break Glass — Approve',
    description: 'Approve or deny break-glass access requests.',
  },
});

const ROLE_OVERRIDES = Object.freeze({
  PLATFORM_OWNER: {
    displayName: 'Platform Owner',
    description:
      'Highest platform authority that manages platform administrators and owner-only controls.',
  },
  PLATFORM_ADMIN: {
    displayName: 'Platform Admin',
    description: 'Platform administrator with unrestricted access across all tenants.',
  },
  TENANT_ADMIN: {
    displayName: 'Org Admin',
    description: 'Hospital group administrator responsible for tenant-wide operations.',
  },
  FACILITY_ADMIN: {
    displayName: 'Facility Admin',
    description: 'Facility administrator managing users, modules, and local settings.',
  },
  INTEGRATION_ADMIN: {
    displayName: 'Integration Admin',
    description: 'Administrator for integrations, APIs, and external system connectors.',
  },
  DOCTOR: {
    displayName: 'Doctor',
    description: 'Licensed physician with clinical documentation and order privileges.',
  },
  OPD_DOCTOR: {
    displayName: 'OPD Doctor',
    description: 'Outpatient physician focused on OPD encounters and clinical charting.',
  },
  ICU_DOCTOR: {
    displayName: 'ICU Doctor',
    description: 'Critical-care physician focused on ICU and inpatient clinical workflows.',
  },
  ATTENDING_PHYSICIAN: {
    displayName: 'Attending',
    description: 'Senior physician responsible for supervising clinical care.',
  },
  RESIDENT_PHYSICIAN: {
    displayName: 'Resident',
    description: 'Physician in postgraduate training with supervised clinical privileges.',
  },
  SURGEON: {
    displayName: 'Surgeon',
    description: 'Surgical physician with clinical and theatre visibility.',
  },
  ANESTHESIOLOGIST: {
    displayName: 'Anesthesiologist',
    description: 'Physician managing anesthesia and perioperative patient safety.',
  },
  PHYSICIAN_ASSISTANT: {
    displayName: 'Physician Assistant',
    description: 'Advanced practice clinician supporting physician-led care.',
  },
  EMERGENCY_PHYSICIAN: {
    displayName: 'ED Physician',
    description: 'Emergency department physician managing acute presentations.',
  },
  DENTIST: {
    displayName: 'Dentist',
    description: 'Dental clinician with clinical documentation privileges.',
  },
  RADIOLOGIST: {
    displayName: 'Radiologist',
    description: 'Physician interpreting imaging studies and radiology reports.',
  },
  NURSE: {
    displayName: 'Nurse (RN)',
    description: 'Registered nurse with bedside care and clinical charting access.',
  },
  LICENSED_PRACTICAL_NURSE: {
    displayName: 'LPN',
    description: 'Licensed practical nurse providing bedside and procedural support.',
  },
  NURSE_PRACTITIONER: {
    displayName: 'Nurse Practitioner',
    description: 'Advanced practice nurse with expanded clinical order privileges.',
  },
  TRIAGE_NURSE: {
    displayName: 'Triage Nurse',
    description: 'Nurse prioritizing intake acuity and emergency queues.',
  },
  MIDWIFE: {
    displayName: 'Midwife',
    description: 'Midwifery clinician supporting maternal and newborn care.',
  },
  CHARGE_NURSE: {
    displayName: 'Charge Nurse',
    description: 'Shift lead nurse coordinating unit staffing and bedside care.',
  },
  PHYSIOTHERAPIST: {
    displayName: 'Physiotherapist',
    description: 'Allied health clinician delivering physical therapy.',
  },
  OCCUPATIONAL_THERAPIST: {
    displayName: 'Occupational Therapist',
    description: 'Allied health clinician supporting functional recovery.',
  },
  RESPIRATORY_THERAPIST: {
    displayName: 'Respiratory Therapist',
    description: 'Allied health clinician managing respiratory support.',
  },
  DIETITIAN: {
    displayName: 'Dietitian',
    description: 'Nutrition clinician managing dietary plans and counseling.',
  },
  SOCIAL_WORKER: {
    displayName: 'Social Worker',
    description: 'Care coordination and psychosocial support staff.',
  },
  CLINICAL_PSYCHOLOGIST: {
    displayName: 'Psychologist',
    description: 'Clinical psychologist providing mental health assessment and therapy.',
  },
  LAB_TECH: {
    displayName: 'Lab Tech',
    description: 'Laboratory staff member processing orders and releasing results.',
  },
  MEDICAL_LABORATORY_SCIENTIST: {
    displayName: 'Lab Scientist',
    description: 'Laboratory scientist performing and validating diagnostic tests.',
  },
  PATHOLOGIST: {
    displayName: 'Pathologist',
    description: 'Physician specializing in laboratory diagnosis and pathology.',
  },
  RADIOLOGY_TECH: {
    displayName: 'Radiology Tech',
    description: 'Imaging staff member managing radiology orders and studies.',
  },
  SONOGRAPHER: {
    displayName: 'Sonographer',
    description: 'Ultrasound technologist performing sonography studies.',
  },
  PHARMACIST: {
    displayName: 'Pharmacist',
    description: 'Pharmacy staff member dispensing medications and reviewing orders.',
  },
  PHARMACY_TECHNICIAN: {
    displayName: 'Pharmacy Tech',
    description: 'Pharmacy support staff assisting with dispensing and inventory.',
  },
  RECEPTIONIST: {
    displayName: 'Receptionist',
    description:
      'Front-desk staff handling patient registration, visitor/staff meetings, desk queues, communications, and reporting.',
  },
  ADMISSIONS_COORDINATOR: {
    displayName: 'Admissions',
    description: 'Staff coordinating patient admissions and front-office intake.',
  },
  MEDICAL_RECORDS_CLERK: {
    displayName: 'Medical Records',
    description: 'Health information staff maintaining records and registrations.',
  },
  BILLING: {
    displayName: 'Billing',
    description: 'Finance staff managing invoices, claims, and payment workflows.',
  },
  PHARMACY_BILLING: {
    displayName: 'Pharmacy Billing',
    description: 'Billing staff managing pharmacy invoices and pharmacy price lists.',
  },
  MEDICAL_CODER: {
    displayName: 'Medical Coder',
    description: 'Coding specialist preparing claims and billing documentation.',
  },
  ACCOUNTANT: {
    displayName: 'Accountant',
    description: 'Finance staff managing ledgers, reconciliation, and reporting.',
  },
  OPERATIONS: {
    displayName: 'Operations',
    description: 'Operations staff overseeing compliance, governance, and reporting.',
  },
  OPERATIONS_STAFF: {
    displayName: 'Operations Staff',
    description: 'Operations support staff with limited governance access.',
  },
  HR: {
    displayName: 'HR',
    description: 'Human resources staff managing workforce records, units, and rosters.',
  },
  HR_STAFF: {
    displayName: 'HR Staff',
    description: 'Human resources support staff with limited workforce access.',
  },
  IT_SUPPORT: {
    displayName: 'IT Support',
    description: 'Technical support staff with operational troubleshooting access.',
  },
  DISCHARGE_PLANNER: {
    displayName: 'Discharge Planner',
    description: 'Staff coordinating discharge plans and post-acute transitions.',
  },
  BIOMED: {
    displayName: 'Biomed',
    description: 'Biomedical staff maintaining equipment and service records.',
  },
  BIOMED_MANAGER: {
    displayName: 'Biomed Manager',
    description: 'Manager overseeing biomedical engineering and equipment lifecycle.',
  },
  HOUSE_KEEPER: {
    displayName: 'Housekeeping',
    description: 'Support staff with limited operational visibility.',
  },
  HOUSEKEEPING_MANAGER: {
    displayName: 'Housekeeping Manager',
    description: 'Manager supervising environmental services and housekeeping teams.',
  },
  FOOD_SERVICE_WORKER: {
    displayName: 'Food Service',
    description: 'Dietary support staff with limited operational visibility.',
  },
  PORTER: {
    displayName: 'Porter',
    description: 'Patient transport and ward support staff.',
  },
  SECURITY_OFFICER: {
    displayName: 'Security',
    description: 'Security personnel with limited operational visibility.',
  },
  MAINTENANCE_ENGINEER: {
    displayName: 'Maintenance',
    description: 'Facilities maintenance staff supporting equipment and infrastructure.',
  },
  CHAPLAIN: {
    displayName: 'Chaplain',
    description: 'Pastoral care staff supporting patients and families.',
  },
  AMBULANCE_OPERATOR: {
    displayName: 'Ambulance Operator',
    description: 'Emergency transport staff managing ambulance and emergency cases.',
  },
  PARAMEDIC: {
    displayName: 'Paramedic',
    description: 'Advanced pre-hospital clinician supporting emergency transport.',
  },
  EMT: {
    displayName: 'EMT',
    description: 'Emergency medical technician supporting ambulance response.',
  },
  UNIT_MANAGER: {
    displayName: 'Unit Manager',
    description: 'Manager overseeing a clinical or support unit and its roster.',
  },
  WARD_MANAGER: {
    displayName: 'Ward Manager',
    description: 'Inpatient ward manager coordinating beds, nursing, and rostering.',
  },
  ICU_MANAGER: {
    displayName: 'ICU Manager',
    description: 'Intensive care manager supervising critical-care operations.',
  },
  THEATRE_MANAGER: {
    displayName: 'Theatre Manager',
    description: 'Operating theatre manager coordinating surgical schedules and staff.',
  },
  MORTUARY_STAFF: {
    displayName: 'Mortuary Staff',
    description: 'Mortuary staff handling intake, storage, and case documentation.',
  },
  MORTUARY_MANAGER: {
    displayName: 'Mortuary Manager',
    description: 'Mortuary manager approving releases, audits, and complex cases.',
  },
  SUPPORT_STAFF: {
    displayName: 'Support Staff',
    description: 'General facility support with limited operational visibility.',
  },
  VISITOR_GUEST: {
    displayName: 'Visitor',
    description: 'Limited guest access for visitor workflows.',
  },
  PATIENT: {
    displayName: 'Patient',
    description: 'Patient portal user with access to personal health information.',
  },
  OTHER: {
    displayName: 'Other',
    description: 'Limited-access role for ancillary or uncategorized users.',
  },
});

const humanizeToken = (token = '') =>
  String(token || '')
    .split('_')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(' ');

const getPermissionMetadata = (code) => {
  const override = PERMISSION_OVERRIDES[code];
  if (override) {
    return override;
  }

  const [domain, ...actionParts] = String(code || '').split(':');
  const actionKey = actionParts.join(':');
  const domainLabel = DOMAIN_LABELS[domain] || humanizeToken(domain);
  const actionLabel = ACTION_LABELS[actionKey] || humanizeToken(actionKey);

  return {
    displayName: `${domainLabel} — ${actionLabel}`,
    description: `Allows ${actionLabel.toLowerCase()} access within ${domainLabel.toLowerCase()}.`,
  };
};

const getRoleMetadata = (roleCode) => {
  const normalized = String(roleCode || '').trim().toUpperCase();
  const override = ROLE_OVERRIDES[normalized];
  if (override) {
    return override;
  }

  const displayName = humanizeToken(normalized);
  return {
    displayName,
    description: `System role for ${displayName.toLowerCase()} users.`,
  };
};

module.exports = {
  getPermissionMetadata,
  getRoleMetadata,
};
