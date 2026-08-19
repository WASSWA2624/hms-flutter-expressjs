# Seeded User Accounts

Generated: 2026-08-17

Source of truth: `backend/scripts/seeders/seed-catalog.js` (`DEMO_TENANTS[0].users`), mirrored by
`backend/src/config/demo-users.js` (immutability guard list).

Seeder entrypoints that create users:

- `npm run seed` → `backend/prisma/seed.js` → `seed-demo-data.js`
- `npm run setup:accounts` → `backend/scripts/setup-default-accounts.js` → `seed-org-pack` + `seed-access-pack`

## Environments

**The same 58 accounts are seeded on development and production.**

Run on both:

```bash
npm run setup:accounts
```

On production, supply a private shared password (otherwise the committed demo password is used):

```bash
SEED_DEFAULT_PASSWORD='<strong-shared-password>' npm run setup:accounts
```

The script is idempotent (deterministic UUID upserts), so re-running it is safe.

What stays **development-only**: the randomised demo *data* packs
(`npm run seed`, `npm run db:seed:demo`) — patients, encounters, invoices, inventory, etc. Those
still short-circuit on `NODE_ENV=production` (`prisma/seed.js:45`) and still refuse a
prod/live-looking `DATABASE_URL` (`scripts/demo-safety.js`).

Other production-safe seeders load reference/catalog data only:

| Script | Seeds |
| --- | --- |
| `scripts/reseed-platform-access-catalog.js` | platform roles + permissions catalog |
| `scripts/sync-permission-catalog.js` | permission catalog sync |
| `scripts/seed-clinical-catalog-data.js` / `refresh-clinical-catalog.js` | diagnosis/clinical catalog |
| `scripts/seed-lab-catalog-data.js` | lab test catalog |
| `scripts/backfill-plan-module-matrix.js` | subscription plan/module matrix |

## Account list

Tenant: **DemoCare General Hospital** (`tenant_code: DEMO`, slug `democare-general-hospital`, plan `pro`).
Facilities: `DemoCare General Hospital` (HOSPITAL, anchor), `DemoCare Annex Pharmacy` (CLINIC).

All 58 accounts share one password — `SEED_DEFAULT_PASSWORD` if set, otherwise the committed
default `Hosspi@2624.` (`scripts/seeders/seed-runtime.js`) — with status `ACTIVE`, attached to the
anchor facility.
They are immutable from access-admin APIs (no edit/delete/role change) per `config/demo-users.js`.

### Platform & administration

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| platform.owner@hosspi.com | PLATFORM_OWNER | Owner Demo | Platform Owner |
| platform.admin@hosspi.com | PLATFORM_ADMIN | Platform Demo | Platform Administrator |
| tenant.admin@hosspi.com | TENANT_ADMIN (+ UNIT_MANAGER) | Taylor Demo | Hospital Administrator |
| facility.admin@hosspi.com | FACILITY_ADMIN | Morgan Demo | Facility Administrator |
| integration.admin@hosspi.com | INTEGRATION_ADMIN | Indigo Demo | Integration Administrator |

### Doctors & clinicians

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| doctor@hosspi.com | DOCTOR | Jordan Demo | Consultant Physician |
| opd.doctor@hosspi.com | OPD_DOCTOR | Owen Demo | OPD Doctor |
| icu.doctor@hosspi.com | ICU_DOCTOR | Iris Demo | ICU Doctor |
| attending@hosspi.com | ATTENDING_PHYSICIAN | Avery Attending | Attending Physician |
| resident@hosspi.com | RESIDENT_PHYSICIAN | Robin Demo | Resident Physician |
| surgeon@hosspi.com | SURGEON | Sydney Demo | Surgeon |
| anesthesia@hosspi.com | ANESTHESIOLOGIST | Ash Demo | Anesthesiologist |
| pa@hosspi.com | PHYSICIAN_ASSISTANT | Pat Demo | Physician Assistant |
| er.doctor@hosspi.com | EMERGENCY_PHYSICIAN | Eden Demo | Emergency Physician |
| dentist@hosspi.com | DENTIST | Devon Demo | Dentist |

### Nursing

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| nurse@hosspi.com | NURSE (+ WARD_MANAGER, ICU_MANAGER) | Casey Demo | Registered Nurse |
| lpn@hosspi.com | LICENSED_PRACTICAL_NURSE | Leslie Demo | Licensed Practical Nurse |
| np@hosspi.com | NURSE_PRACTITIONER | Nora Demo | Nurse Practitioner |
| triage@hosspi.com | TRIAGE_NURSE | Tessa Demo | Triage Nurse |
| midwife@hosspi.com | MIDWIFE | Mia Demo | Midwife |
| charge.nurse@hosspi.com | CHARGE_NURSE | Charlie Demo | Charge Nurse |

### Diagnostics (lab & radiology)

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| lab@hosspi.com | LAB_TECH | Riley Demo | Laboratory Technologist |
| mls@hosspi.com | MEDICAL_LABORATORY_SCIENTIST | Miles Demo | Medical Laboratory Scientist |
| pathologist@hosspi.com | PATHOLOGIST | Paige Demo | Pathologist |
| radiology@hosspi.com | RADIOLOGY_TECH | Emery Demo | Radiology Technologist |
| radiologist@hosspi.com | RADIOLOGIST | Remy Demo | Radiologist |
| sonographer@hosspi.com | SONOGRAPHER | Sage Demo | Sonographer |

### Pharmacy

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| pharmacy@hosspi.com | PHARMACIST | Harper Demo | Pharmacist |
| pharmacy2@hosspi.com | PHARMACIST | Morgan Demo | Pharmacist |
| pharmacy.tech@hosspi.com | PHARMACY_TECHNICIAN | Phoenix Demo | Pharmacy Technician |
| pharmacy.billing@hosspi.com | PHARMACY_BILLING | Blair Demo | Pharmacy Billing |

### Front office & records

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| reception@hosspi.com | RECEPTIONIST | Skyler Demo | Front Desk Officer |
| admissions@hosspi.com | ADMISSIONS_COORDINATOR | Addison Demo | Admissions Coordinator |
| records@hosspi.com | MEDICAL_RECORDS_CLERK | Reese Records | Medical Records Clerk |
| discharge@hosspi.com | DISCHARGE_PLANNER | Drew Demo | Discharge Planner |
| visitor@hosspi.com | VISITOR_GUEST | Vic Demo | Visitor Guest |

### Billing & finance

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| billing@hosspi.com | BILLING | Rowan Demo | Billing Officer |
| coder@hosspi.com | MEDICAL_CODER | Cody Demo | Medical Coder |
| accountant@hosspi.com | ACCOUNTANT | Alex Demo | Accountant |

### Operations, HR & support services

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| operations@hosspi.com | OPERATIONS | Parker Demo | Operations Lead |
| operations.staff@hosspi.com | OPERATIONS_STAFF | Oakley Demo | Operations Staff |
| hr@hosspi.com | HR | Quinn Demo | HR Officer |
| hr.staff@hosspi.com | HR_STAFF | Hayden Demo | HR Staff |
| biomed@hosspi.com | BIOMED (+ BIOMED_MANAGER) | Avery Demo | Biomedical Engineer |
| housekeeping@hosspi.com | HOUSE_KEEPER (+ HOUSEKEEPING_MANAGER) | Dakota Demo | Housekeeping Supervisor |
| support@hosspi.com | SUPPORT_STAFF | Sam Demo | Support Staff |

### Emergency & ambulance

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| ambulance@hosspi.com | AMBULANCE_OPERATOR | Reese Demo | Ambulance Operator |
| paramedic@hosspi.com | PARAMEDIC | Perry Demo | Paramedic |
| emt@hosspi.com | EMT | Ellis Demo | Emergency Medical Technician |

### Allied health

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| physio@hosspi.com | PHYSIOTHERAPIST | Peyton Demo | Physiotherapist |
| ot@hosspi.com | OCCUPATIONAL_THERAPIST | Oakley Therapy | Occupational Therapist |
| rt@hosspi.com | RESPIRATORY_THERAPIST | River Demo | Respiratory Therapist |
| dietitian@hosspi.com | DIETITIAN | Dana Demo | Dietitian |
| social@hosspi.com | SOCIAL_WORKER | Shawn Demo | Medical Social Worker |
| psychologist@hosspi.com | CLINICAL_PSYCHOLOGIST | Piper Demo | Clinical Psychologist |

### Mortuary

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| mortuary.staff@hosspi.com | MORTUARY_STAFF | Taylor Mortuary | Mortuary Officer |
| mortuary.manager@hosspi.com | MORTUARY_MANAGER | Jordan Mortuary | Mortuary Manager |

### Patient portal

| Email | Role | Name | Title |
| --- | --- | --- | --- |
| patient.portal@hosspi.com | PATIENT | Patient Demo | Patient Portal User |

## Notes

- Staff profiles are created for every seeded user **except** `PATIENT`, `PLATFORM_ADMIN`, and
  `PLATFORM_OWNER` (`seed-access-pack.js:299`).
- Phone numbers are derived deterministically (`+2567` + hash of email), so they are stable across reseeds.
- Re-seeding archives any pre-existing non-seed user holding the same email
  (`archived+<id>+<email>`, soft-deleted) to avoid `unique(tenant_id, email)` collisions.
