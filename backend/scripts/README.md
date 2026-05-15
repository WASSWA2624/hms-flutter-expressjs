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

- `super.admin@hosspi.com`
- Role-based demo users such as `tenant.admin@hosspi.com`, `doctor@hosspi.com`, `nurse@hosspi.com`, `radiology@hosspi.com`, and `biomed@hosspi.com`
- Default password for every seeded account: `Hosspi@2624.`

#### Seeded Scenarios

- One tenant: `DemoCare General Hospital`
- One facility: `DemoCare General Hospital`
- One assignment per seeded role, with some users holding scoped manager roles: `SUPER_ADMIN`, `TENANT_ADMIN`, `FACILITY_ADMIN`, `DOCTOR`, `NURSE`, `LAB_TECH`, `RADIOLOGY_TECH`, `PHARMACIST`, `RECEPTIONIST`, `BILLING`, `OPERATIONS`, `HR`, `BIOMED`, `HOUSE_KEEPER`, `AMBULANCE_OPERATOR`, `UNIT_MANAGER`, `WARD_MANAGER`, `ICU_MANAGER`, `THEATRE_MANAGER`, `HOUSEKEEPING_MANAGER`, `BIOMED_MANAGER`, `MORTUARY_STAFF`, `MORTUARY_MANAGER`, `PATIENT`
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
- **SUPER_ADMIN**: Platform-level administrator (manages multiple hospitals)
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

#### Prerequisites

- Database must be initialized (migrations applied)
- `.env` file must be configured with `DATABASE_URL`
- Prisma client must be generated (`npx prisma generate`)

#### Default Credentials

**⚠️ SECURITY WARNING**: All accounts are created with the default password:
```
Hosspi@2624.
```

**You MUST change all passwords immediately after first login in production!**

#### Notable Accounts Created

| Email | Role | Tenant |
|-------|------|-------------|
| `super.admin@hosspi.com` | SUPER_ADMIN | DemoCare General Hospital |
| `tenant.admin@hosspi.com` | TENANT_ADMIN | DemoCare General Hospital |
| `facility.admin@hosspi.com` | FACILITY_ADMIN | DemoCare General Hospital |
| `doctor@hosspi.com` | DOCTOR | DemoCare General Hospital |
| `nurse@hosspi.com` | NURSE | DemoCare General Hospital |
| `lab@hosspi.com` | LAB_TECH | DemoCare General Hospital |
| `radiology@hosspi.com` | RADIOLOGY_TECH | DemoCare General Hospital |
| `pharmacy@hosspi.com` | PHARMACIST | DemoCare General Hospital |

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
- [Authentication & Security Rules](../.cursor/rules/auth-security.mdc)
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

Seeds curated, deterministic demo data packs and optionally runs a light filler pass for non-curated models.

#### Purpose

- Seeds the authoritative org, access, subscriptions, communications, clinical, operations, biomedical, and compliance packs
- Keeps `npm run db:seed:demo` non-destructive and idempotent
- Runs semantic verification after seeding and fails if required scenarios are missing
- Uses `SEED_RECORD_COUNT=0` to skip the optional filler pass while keeping the curated scenarios

#### Usage

```bash
# Seed curated demo data with optional filler
node scripts/seed-demo-data.js

# Skip the generic filler pass
SEED_RECORD_COUNT=0 node scripts/seed-demo-data.js
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

Validates the curated seed invariants.

#### Purpose

- Confirms all five commercial plan records exist
- Confirms Basic, Pro, Advanced, and Custom pricing metadata still matches the agreed baseline
- Confirms workspace-critical subscription and communications scenarios exist
- Confirms biomedical and compliance baseline records exist

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
