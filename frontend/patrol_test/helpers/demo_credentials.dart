/// Seeded demo accounts for Patrol E2E against a running backend.
///
/// Source of truth: `backend/scripts/seeders/seed-catalog.js`
const String demoAccountPassword = 'Hosspi@2624.';

enum DemoAccount {
  platformOwner('platform.owner@hosspi.com'),
  platformAdmin('platform.admin@hosspi.com'),
  tenantAdmin('tenant.admin@hosspi.com'),
  facilityAdmin('facility.admin@hosspi.com'),
  doctor('doctor@hosspi.com'),
  nurse('nurse@hosspi.com'),
  lab('lab@hosspi.com'),
  radiology('radiology@hosspi.com'),
  pharmacy('pharmacy@hosspi.com'),
  reception('reception@hosspi.com'),
  billing('billing@hosspi.com'),
  operations('operations@hosspi.com'),
  hr('hr@hosspi.com'),
  biomed('biomed@hosspi.com'),
  housekeeping('housekeeping@hosspi.com'),
  ambulance('ambulance@hosspi.com'),
  patientPortal('patient.portal@hosspi.com');

  const DemoAccount(this.email);

  final String email;
}
