# Scripts Directory

This directory contains utility scripts for database setup, maintenance, and development tasks.

## Available Scripts

### Demo Seed Workflow

The HMS demo environment now uses a curated reset, seed, and verify flow aligned to `write-up.md` and `subscription-plan.md`.

#### Primary Commands

```bash
# Destructive: clears all app tables except _prisma_migrations, then seeds curated demo data
npm run db:reset:demo

# Non-destructive: upserts the curated single-workspace demo dataset into the current dev database
npm run db:seed:demo

# Validates that the single-tenant demo dataset and catalog baseline are still present
npm run db:verify:demo
```

#### Seeded Credentials

Default password for **every** seeded account: `Hosspi@2624.`

Source of truth: `scripts/seeders/seed-catalog.js` (`DEMO_TENANT.users`). Re-seed with `npm run db:seed:demo` or `node scripts/setup-default-accounts.js`.

| # | Email                           | Primary role                 | Extra roles               |
|---|---------------------------------|------------------------------|---------------------------|
| 1 | `platform.owner@hosspi.com`     | PLATFORM_OWNER               |                           |
| 2 | `platform.admin@hosspi.com`     | PLATFORM_ADMIN               |                           |
| 3 | `tenant.admin@hosspi.com`       | TENANT_ADMIN                 | UNIT_MANAGER              |
| 4 | `facility.admin@hosspi.com`     | FACILITY_ADMIN               |                           |
| 5 | `integration.admin@hosspi.com`  | INTEGRATION_ADMIN            |                           |
| 6 | `hr.staff@hosspi.com`           | HR_STAFF                     |                           |
| 7 | `operations.staff@hosspi.com`   | OPERATIONS_STAFF             |                           |
| 8 | `discharge@hosspi.com`          | DISCHARGE_PLANNER            |                           |
| 9 | `dentist@hosspi.com`            | DENTIST                      |                           |
|10 | `radiologist@hosspi.com`        | RADIOLOGIST                  |                           |
|11 | `sonographer@hosspi.com`        | SONOGRAPHER                  |                           |
|12 | `accountant@hosspi.com`         | ACCOUNTANT                   |                           |
|13 | `support@hosspi.com`            | SUPPORT_STAFF                |                           |
|14 | `visitor@hosspi.com`            | VISITOR_GUEST                |                           |
|15 | `doctor@hosspi.com`             | DOCTOR                       |                           |
|16 | `opd.doctor@hosspi.com`         | OPD_DOCTOR                   |                           |
|17 | `icu.doctor@hosspi.com`         | ICU_DOCTOR                   |                           |
|18 | `attending@hosspi.com`          | ATTENDING_PHYSICIAN          |                           |
|19 | `resident@hosspi.com`           | RESIDENT_PHYSICIAN           |                           |
|20 | `surgeon@hosspi.com`            | SURGEON                      |                           |
|21 | `anesthesia@hosspi.com`         | ANESTHESIOLOGIST             |                           |
|22 | `pa@hosspi.com`                 | PHYSICIAN_ASSISTANT          |                           |
|23 | `er.doctor@hosspi.com`          | EMERGENCY_PHYSICIAN          |                           |
|24 | `nurse@hosspi.com`              | NURSE                        | WARD_MANAGER, ICU_MANAGER |
|25 | `lpn@hosspi.com`                | LICENSED_PRACTICAL_NURSE     |                           |
|26 | `np@hosspi.com`                 | NURSE_PRACTITIONER           |                           |
|27 | `triage@hosspi.com`             | TRIAGE_NURSE                 |                           |
|28 | `midwife@hosspi.com`            | MIDWIFE                      |                           |
|29 | `charge.nurse@hosspi.com`       | CHARGE_NURSE                 |                           |
|30 | `lab@hosspi.com`                | LAB_TECH                     |                           |
|31 | `mls@hosspi.com`                | MEDICAL_LABORATORY_SCIENTIST |                           |
|32 | `pathologist@hosspi.com`        | PATHOLOGIST                  |                           |
|33 | `radiology@hosspi.com`          | RADIOLOGY_TECH               |                           |
|34 | `pharmacy@hosspi.com`           | PHARMACIST                   |                           |
|35 | `pharmacy2@hosspi.com`          | PHARMACIST                   |                           |
|36 | `pharmacy.tech@hosspi.com`      | PHARMACY_TECHNICIAN          |                           |
|37 | `pharmacy.billing@hosspi.com`   | PHARMACY_BILLING             |                           |
|38 | `reception@hosspi.com`          | RECEPTIONIST                 |                           |
|39 | `admissions@hosspi.com`         | ADMISSIONS_COORDINATOR       |                           |
|40 | `records@hosspi.com`            | MEDICAL_RECORDS_CLERK        |                           |
|41 | `billing@hosspi.com`            | BILLING                      |                           |
|42 | `coder@hosspi.com`              | MEDICAL_CODER                |                           |
|43 | `operations@hosspi.com`         | OPERATIONS                   |                           |
|44 | `hr@hosspi.com`                 | HR                           |                           |
|45 | `biomed@hosspi.com`             | BIOMED                       | BIOMED_MANAGER            |
|46 | `housekeeping@hosspi.com`       | HOUSE_KEEPER                 | HOUSEKEEPING_MANAGER      |
|47 | `ambulance@hosspi.com`          | AMBULANCE_OPERATOR           |                           |
|48 | `paramedic@hosspi.com`          | PARAMEDIC                    |                           |
|49 | `emt@hosspi.com`                | EMT                          |                           |
|50 | `physio@hosspi.com`             | PHYSIOTHERAPIST              |                           |
|51 | `ot@hosspi.com`                 | OCCUPATIONAL_THERAPIST       |                           |
|52 | `rt@hosspi.com`                 | RESPIRATORY_THERAPIST        |                           |
|53 | `dietitian@hosspi.com`          | DIETITIAN                    |                           |
|54 | `social@hosspi.com`             | SOCIAL_WORKER                |                           |
|55 | `psychologist@hosspi.com`       | CLINICAL_PSYCHOLOGIST        |                           |
|56 | `mortuary.staff@hosspi.com`     | MORTUARY_STAFF               |                           |
|57 | `mortuary.manager@hosspi.com`   | MORTUARY_MANAGER             |                           |
|58 | `patient.portal@hosspi.com`     | PATIENT                      |                           |

#### Seeded Scenarios

- One tenant: `DemoCare General Hospital`
- One facility: `DemoCare General Hospital`
- One assignment per seeded role, with some users holding scoped manager roles: `PLATFORM_OWNER`, `PLATFORM_ADMIN`, `TENANT_ADMIN`, `FACILITY_ADMIN`, `DOCTOR`, `NURSE`, `LAB_TECH`, `RADIOLOGY_TECH`, `PHARMACIST`, `RECEPTIONIST`, `BILLING`, `OPERATIONS`, `HR`, `BIOMED`, `HOUSE_KEEPER`, `AMBULANCE_OPERATOR`, `UNIT_MANAGER`, `WARD_MANAGER`, `ICU_MANAGER`, `THEATRE_MANAGER`, `HOUSEKEEPING_MANAGER`, `BIOMED_MANAGER`, `MORTUARY_STAFF`, `MORTUARY_MANAGER`, `PATIENT`
- Subscription catalog aligned to the commercial baseline, including Basic facility limit correction and add-on eligibility rules
- One active advanced-plan subscription with a paid invoice and active license for the seeded tenant
- Communications scenarios covering an unread direct escalation, an archived billing thread, a sensitive biomedical incident channel, attachments, notifications, and templates
- Clinical and operations journeys covering outpatient, inpatient, telemedicine, diagnostics, pharmacy, emergency, ambulance, billing, procurement, and rosters
- Biomedical and compliance records covering PM plans, work orders, calibration, safety testing, downtime, spare parts, incidents, recalls, disposal, PHI access, breach drill, system change, integrations, and webhooks

---

### `setup-default-accounts.js`

Compatibility wrapper that seeds the curated tenant and account baseline without running the full clinical and operational data packs.

#### Purpose

This script initializes the system with default accounts for:

- **PLATFORM_OWNER**: Highest platform authority (manage platform admins and owner-only controls)
- **PLATFORM_ADMIN**: Platform-level administrator (manages multiple hospitals)
- **TENANT_ADMIN**: Hospital/tenant-level administrator
- **FACILITY_ADMIN**: Facility-level administrator
- **DOCTOR**: Medical doctor
- **NURSE**: Nursing staff
- **LAB_TECH**: Laboratory technician
- **RADIOLOGY_TECH**: Radiology technologist
- **PHARMACIST**: Pharmacy staff
- **RECEPTIONIST**: Front desk staff
- **BILLING**: Billing and finance staff
- **OPERATIONS**: Operations staff
- **HR**: Human resources staff
- **BIOMED**: Biomedical engineering staff
- **HOUSE_KEEPER**: Housekeeping staff
- **AMBULANCE_OPERATOR**: Ambulance operations staff
- **MORTUARY_STAFF** and **MORTUARY_MANAGER**: Mortuary operations users
- **PATIENT**: Patient user (example)

#### What It Does

1. Creates the curated demo tenant and facility
2. Creates the supporting departments, ward, room, and bed
3. Creates roles, permissions, users, user profiles, and staff profiles
4. Assigns the shared demo password to all seeded accounts without printing it in command output

#### Usage

```bash
# From project root
node scripts/setup-default-accounts.js
```

Runs in **every environment, production included** — the account set is
identical on development and production. Unlike the randomised demo data
seeders, this script is not gated by `scripts/demo-safety.js`.

```bash
# Production: always supply a private shared password
SEED_DEFAULT_PASSWORD='<strong-shared-password>' node scripts/setup-default-accounts.js
```

#### Prerequisites

- Database must be initialized (migrations applied)
- `.env` file must be configured with `DATABASE_URL`
- Prisma client must be generated (`npx prisma generate`)
- Production installs may omit devDependencies; that is supported — this path
  does not use `@faker-js/faker`

#### Default Credentials

**⚠️ SECURITY WARNING**: Without `SEED_DEFAULT_PASSWORD`, all accounts are
created with the committed default password:

```
Hosspi@2624.
```

**Set `SEED_DEFAULT_PASSWORD` on production, and change all passwords immediately after first login!**

#### Notable Accounts Created

See the full **Seeded Credentials** table above (all `DEMO_TENANT.users` emails). Tenant for each: DemoCare General Hospital.

#### Account Details

Each account includes:

- **Email**: Unique email address
- **Phone**: Unique phone number (format: +123456789XX)
- **Status**: ACTIVE (ready to use)
- **User Profile**: First name, last name, gender
- **Staff Profile**: Staff number, position, hire date (for staff roles)
- **Role Assignment**: Appropriate role assigned via `user_role` table

#### Idempotency

The script is **idempotent** - it can be run multiple times safely:

- Existing tenants/facilities are reused
- Existing users are skipped (not recreated)
- New users are created only if they don't exist

#### Customization

To customize the demo baseline, edit `scripts/seeders/seed-catalog.js` and keep `verify-demo-data.js` aligned with the intended invariants.

#### Troubleshooting

**Error: "Prisma client not found"**

- Run `npx prisma generate` first

**Error: "Invalid DATABASE_URL"**

- Check your `.env` file has a valid `DATABASE_URL`
- Format: `mysql://user:password@host:port/database`

**Error: "Module alias not found"**

- Ensure you're running from the project root
- Check that `node_modules` is installed (`npm install`)

**Users not created**

- Check database connection
- Verify migrations are applied (`npx prisma migrate status`)
- Check console output for specific errors

#### Security Notes

- All passwords are hashed using bcryptjs (10 salt rounds)
- Passwords follow auth-security.mdc requirements (≥8 characters)
- Audit logs are created for each user creation
- Default passwords should be changed immediately after setup

#### Related Documentation

- [Prisma Guide](../prisma/guide.md)
- [Authentication &amp; Security Rules](../.cursor/rules/auth-security.mdc)
- [Project Structure](../.cursor/rules/project-structure.mdc)

---

### `backfill-ambulance-operator-role.js`

Backfills `AMBULANCE_OPERATOR` role records across active tenants and facilities.

#### Purpose

- Ensures each active facility has an `AMBULANCE_OPERATOR` role
- Creates a tenant-level `AMBULANCE_OPERATOR` role when a tenant has no active facilities
- Never auto-assigns users to this role
- Safe to run repeatedly (idempotent)

#### Usage

```bash
# Execute backfill for all active tenants
node scripts/backfill-ambulance-operator-role.js

# Preview only (no writes)
node scripts/backfill-ambulance-operator-role.js --dry-run

# Limit to one tenant
node scripts/backfill-ambulance-operator-role.js --tenant-id=<tenant-id>
```

#### NPM Shortcut

```bash
npm run db:backfill:ambulance-role
```

---

### `clear-demo-data.js`

Clears all application data from the current database.

#### Purpose

- Removes all records from application tables
- Preserves Prisma migration metadata (`_prisma_migrations`)
- Useful before reseeding for clean demo environments

#### Usage

```bash
# Clear all application data after explicit confirmation
node scripts/clear-demo-data.js --yes

# Preview tables without deleting
node scripts/clear-demo-data.js --dry-run
```

#### NPM Shortcut

```bash
npm run db:clear:demo
```

---

### `seed-demo-data.js`

Seeds curated, deterministic demo data packs, an FK-aware volume expansion pack, and optionally a light filler pass for non-curated models.

#### Purpose

- Seeds the authoritative org, access, subscriptions, communications, clinical, operations, biomedical, mortuary, compliance, and governance packs
- Runs `seed-volume-pack` to scale applicable operational tables (≥100, prefer ~1000) with status-diverse demo graphs
- Keeps `npm run db:seed:demo` non-destructive and idempotent
- Runs semantic verification after seeding and fails if required scenarios (and volume floors when enabled) are missing
- Uses `SEED_RECORD_COUNT=0` for curated-only mode (skips volume + filler)

#### Volume defaults

| Setting                   | Behavior                                                                          |
| ------------------------- | --------------------------------------------------------------------------------- |
| unset / default           | `SEED_RECORD_COUNT=1000` — applicable operational tables target 1000 rows each |
| `SEED_RECORD_COUNT=100` | Lighter volume run                                                                |
| `SEED_RECORD_COUNT=0`   | Curated hero scenarios only                                                       |

Intentional exceptions (not volume-filled): singleton tenant/facility/subscription/license, plan/add-on/module catalogs, role/permission catalogs.

#### Usage

```bash
# Seed curated + volume demo data (default target 1000)
node scripts/seed-demo-data.js

# Curated-only (skip volume + filler)
SEED_RECORD_COUNT=0 node scripts/seed-demo-data.js

# Custom volume target
SEED_RECORD_COUNT=100 node scripts/seed-demo-data.js
```

#### NPM Shortcuts

```bash
npm run db:seed:demo
npm run db:reset:demo
```

`db:reset:demo` runs:

1. `db:clear:demo`
2. `db:seed:demo`

### `verify-demo-data.js`

Validates the curated seed invariants and, when `SEED_RECORD_COUNT > 0`, volume floors plus key status coverage.

#### Purpose

- Confirms all five commercial plan records exist
- Confirms Basic, Pro, Advanced, and Custom pricing metadata still matches the agreed baseline
- Confirms workspace-critical subscription and communications scenarios exist
- Confirms biomedical and compliance baseline records exist
- When volume mode is on: confirms high-traffic tables meet the volume target and status mixes exist for appointments, encounters, lab/pharmacy/billing, and mortuary

#### Usage

```bash
node scripts/verify-demo-data.js
```

#### NPM Shortcut

```bash
npm run db:verify:demo
```

---

## Adding New Scripts

When adding new scripts to this directory:

1. **Follow the structure**: Use module aliases registration pattern (see `setup-default-accounts.js`)
2. **Add documentation**: Document purpose, usage, prerequisites, and examples
3. **Update this README**: Add your script to the "Available Scripts" section
4. **Follow project rules**: Ensure compliance with all `.cursor/rules/*.mdc` files
5. **Handle errors**: Use try/catch and proper error messages
6. **Clean up**: Always disconnect Prisma client in finally blocks

### Script Template

```javascript
/**
 * Script Name
 * 
 * Brief description of what the script does
 * 
 * Usage:
 *   node scripts/script-name.js
 * 
 * @module scripts/script-name
 */

// Register module aliases (required)
require('module-alias/register');
const path = require('path');

// ... alias registration code ...

// Import dependencies
const prisma = require('@prisma/client');

async function main() {
  try {
    // Script logic here
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main();
}

module.exports = { main };
```
