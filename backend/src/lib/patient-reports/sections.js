const { PERMISSIONS } = require('@config/permissions');

/**
 * Canonical clinical report section catalog.
 * Each section maps to an authoritative module/permission gate.
 */
const PATIENT_REPORT_SECTIONS = Object.freeze([
  Object.freeze({
    id: 'patient_information',
    sort_order: 10,
    permissions: [PERMISSIONS.PATIENT_READ],
    always_available: true,
  }),
  Object.freeze({
    id: 'encounter_details',
    sort_order: 20,
    permissions: [PERMISSIONS.PATIENT_READ, PERMISSIONS.CLINICAL_READ],
  }),
  Object.freeze({
    id: 'vitals',
    sort_order: 30,
    permissions: [PERMISSIONS.CLINICAL_READ, PERMISSIONS.PATIENT_READ],
  }),
  Object.freeze({
    id: 'clinical_notes',
    sort_order: 40,
    permissions: [PERMISSIONS.CLINICAL_READ],
  }),
  Object.freeze({
    id: 'diagnoses',
    sort_order: 50,
    permissions: [PERMISSIONS.CLINICAL_READ],
  }),
  Object.freeze({
    id: 'findings',
    sort_order: 60,
    permissions: [PERMISSIONS.CLINICAL_READ],
  }),
  Object.freeze({
    id: 'laboratory_results',
    sort_order: 70,
    permissions: [PERMISSIONS.LAB_READ],
  }),
  Object.freeze({
    id: 'radiology_reports',
    sort_order: 80,
    permissions: [PERMISSIONS.RADIOLOGY_READ],
  }),
  Object.freeze({
    id: 'procedures',
    sort_order: 90,
    permissions: [PERMISSIONS.CLINICAL_READ],
  }),
  Object.freeze({
    id: 'prescriptions',
    sort_order: 100,
    permissions: [PERMISSIONS.PHARMACY_READ, PERMISSIONS.CLINICAL_READ],
  }),
  Object.freeze({
    id: 'medications',
    sort_order: 110,
    permissions: [PERMISSIONS.PHARMACY_READ],
  }),
  Object.freeze({
    id: 'doctors_notes',
    sort_order: 120,
    permissions: [PERMISSIONS.CLINICAL_READ],
  }),
  Object.freeze({
    id: 'billing_information',
    sort_order: 130,
    permissions: [PERMISSIONS.BILLING_READ],
  }),
  Object.freeze({
    id: 'appointments',
    sort_order: 140,
    permissions: [PERMISSIONS.PATIENT_READ],
  }),
  Object.freeze({
    id: 'admissions',
    sort_order: 150,
    permissions: [PERMISSIONS.PATIENT_READ],
  }),
  Object.freeze({
    id: 'allergies',
    sort_order: 160,
    permissions: [PERMISSIONS.PATIENT_READ],
  }),
  Object.freeze({
    id: 'medical_history',
    sort_order: 170,
    permissions: [PERMISSIONS.PATIENT_READ],
  }),
  Object.freeze({
    id: 'identifiers',
    sort_order: 180,
    permissions: [PERMISSIONS.PATIENT_READ],
  }),
  Object.freeze({
    id: 'contacts',
    sort_order: 190,
    permissions: [PERMISSIONS.PATIENT_READ],
  }),
  Object.freeze({
    id: 'guardians',
    sort_order: 200,
    permissions: [PERMISSIONS.PATIENT_READ],
  }),
  Object.freeze({
    id: 'documents',
    sort_order: 210,
    permissions: [PERMISSIONS.PATIENT_READ],
  }),
  Object.freeze({
    id: 'consents',
    sort_order: 220,
    permissions: [PERMISSIONS.PATIENT_READ],
  }),
]);

const SECTION_BY_ID = Object.freeze(
  Object.fromEntries(PATIENT_REPORT_SECTIONS.map((section) => [section.id, section]))
);

const REPORT_TYPES = Object.freeze({
  PATIENT_CLINICAL: 'patient_clinical',
  ENCOUNTER_CLINICAL: 'encounter_clinical',
  DEPARTMENT_PRINT: 'department_print',
});

const REPORT_ACTIONS = Object.freeze({
  PREVIEW: 'preview',
  GENERATE: 'generate',
  EXPORT: 'export',
  PRINT: 'print',
  DOWNLOAD: 'download',
  ACCESS: 'access',
});

const isSectionAuthorized = (sectionId, permissions = []) => {
  const section = SECTION_BY_ID[sectionId];
  if (!section) return false;
  const permissionSet = new Set(permissions);
  return section.permissions.some((permission) => permissionSet.has(permission));
};

const filterAuthorizedSections = (sectionIds = [], permissions = []) =>
  sectionIds.filter((sectionId) => isSectionAuthorized(sectionId, permissions));

const listAuthorizedSectionDefs = (permissions = []) =>
  PATIENT_REPORT_SECTIONS.filter((section) =>
    isSectionAuthorized(section.id, permissions)
  );

module.exports = {
  PATIENT_REPORT_SECTIONS,
  SECTION_BY_ID,
  REPORT_TYPES,
  REPORT_ACTIONS,
  isSectionAuthorized,
  filterAuthorizedSections,
  listAuthorizedSectionDefs,
};
