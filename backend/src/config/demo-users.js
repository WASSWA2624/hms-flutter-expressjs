/**
 * Seeded demo / default login accounts (Hosspi demo workspace).
 *
 * These accounts are immutable from access-admin APIs: no profile edits,
 * status changes, deletes, or role/permission reassignment.
 *
 * Keep in sync with `DEMO_TENANT.users` in scripts/seeders/seed-catalog.js.
 *
 * @module config/demo-users
 */

const DEMO_USER_EMAILS = Object.freeze(
  new Set([
    'platform.owner@hosspi.com',
    'platform.admin@hosspi.com',
    'tenant.admin@hosspi.com',
    'facility.admin@hosspi.com',
    'integration.admin@hosspi.com',
    'hr.staff@hosspi.com',
    'operations.staff@hosspi.com',
    'discharge@hosspi.com',
    'dentist@hosspi.com',
    'radiologist@hosspi.com',
    'sonographer@hosspi.com',
    'accountant@hosspi.com',
    'support@hosspi.com',
    'visitor@hosspi.com',
    'doctor@hosspi.com',
    'opd.doctor@hosspi.com',
    'icu.doctor@hosspi.com',
    'attending@hosspi.com',
    'resident@hosspi.com',
    'surgeon@hosspi.com',
    'anesthesia@hosspi.com',
    'pa@hosspi.com',
    'er.doctor@hosspi.com',
    'nurse@hosspi.com',
    'lpn@hosspi.com',
    'np@hosspi.com',
    'triage@hosspi.com',
    'midwife@hosspi.com',
    'charge.nurse@hosspi.com',
    'lab@hosspi.com',
    'mls@hosspi.com',
    'pathologist@hosspi.com',
    'radiology@hosspi.com',
    'pharmacy@hosspi.com',
    'pharmacy2@hosspi.com',
    'pharmacy.tech@hosspi.com',
    'pharmacy.billing@hosspi.com',
    'reception@hosspi.com',
    'admissions@hosspi.com',
    'records@hosspi.com',
    'billing@hosspi.com',
    'coder@hosspi.com',
    'operations@hosspi.com',
    'hr@hosspi.com',
    'biomed@hosspi.com',
    'housekeeping@hosspi.com',
    'ambulance@hosspi.com',
    'paramedic@hosspi.com',
    'emt@hosspi.com',
    'physio@hosspi.com',
    'ot@hosspi.com',
    'rt@hosspi.com',
    'dietitian@hosspi.com',
    'social@hosspi.com',
    'psychologist@hosspi.com',
    'mortuary.staff@hosspi.com',
    'mortuary.manager@hosspi.com',
    'patient.portal@hosspi.com',
  ])
);

const normalizeDemoEmail = (email) => String(email || '').trim().toLowerCase();

const isDemoUserEmail = (email) => DEMO_USER_EMAILS.has(normalizeDemoEmail(email));

const isDemoUser = (user = {}) => isDemoUserEmail(user?.email);

module.exports = {
  DEMO_USER_EMAILS,
  isDemoUser,
  isDemoUserEmail,
  normalizeDemoEmail,
};
