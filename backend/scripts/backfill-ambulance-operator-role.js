/**
 * Backfill Ambulance Operator Role Script
 *
 * Ensures AMBULANCE_OPERATOR role records exist for active tenants/facilities.
 * This script does not assign any users to the role.
 *
 * Usage:
 *   node scripts/backfill-ambulance-operator-role.js
 *   node scripts/backfill-ambulance-operator-role.js --dry-run
 *   node scripts/backfill-ambulance-operator-role.js --tenant-id=<tenantId>
 *
 * @module scripts/backfill-ambulance-operator-role
 */

// Must be absolute first - register module aliases before any other requires
require('module-alias/register');
const path = require('path');

// Register global aliases for runtime resolution
try {
  const moduleAlias = require('module-alias');
  const prismaRuntimePath = path.join(__dirname, '..', 'node_modules', '@prisma', 'client', 'runtime');

  moduleAlias.addAliases({
    '@app': path.join(__dirname, '..', 'src', 'app'),
    '@lib': path.join(__dirname, '..', 'src', 'lib'),
    '@config': path.join(__dirname, '..', 'src', 'config'),
    '@middlewares': path.join(__dirname, '..', 'src', 'middlewares'),
    '@logs': path.join(process.cwd(), 'logs'),
    '@websockets': path.join(__dirname, '..', 'src', 'websockets'),
    '@modules': path.join(__dirname, '..', 'src', 'modules'),
    '@prisma/client': path.join(__dirname, '..', 'src', 'prisma', 'client.js')
  });

  moduleAlias.addAlias('@prisma/client/runtime', prismaRuntimePath);
} catch (err) {
  console.error('Failed to register module aliases:', err);
  process.exit(1);
}

// Register module-scoped aliases
try {
  const { registerAllModuleAliases } = require('@lib/aliases');
  registerAllModuleAliases();
} catch (err) {
  console.warn('Failed to register module aliases (may not be critical):', err.message);
}

const prisma = require('@prisma/client');

const ROLE_NAME = 'AMBULANCE_OPERATOR';

const parseCliArgs = (argv = process.argv.slice(2)) => {
  let dryRun = false;
  let tenantId = null;

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if (arg === '--dry-run') {
      dryRun = true;
      continue;
    }

    if (arg.startsWith('--tenant-id=')) {
      const value = arg.slice('--tenant-id='.length).trim();
      if (!value) throw new Error('Missing value for --tenant-id');
      tenantId = value;
      continue;
    }

    if (arg === '--tenant-id') {
      const value = String(argv[i + 1] || '').trim();
      if (!value || value.startsWith('--')) {
        throw new Error('Missing value for --tenant-id');
      }
      tenantId = value;
      i += 1;
      continue;
    }
  }

  return { dryRun, tenantId };
};

const resolveActiveTenants = async (tenantId = null) => {
  const where = {
    deleted_at: null,
    is_active: true
  };

  if (tenantId) {
    where.id = tenantId;
  }

  return prisma.tenant.findMany({
    where,
    select: {
      id: true,
      name: true
    },
    orderBy: {
      created_at: 'asc'
    }
  });
};

const resolveActiveFacilities = async (tenantId) => prisma.facility.findMany({
  where: {
    tenant_id: tenantId,
    deleted_at: null,
    is_active: true
  },
  select: {
    id: true,
    name: true
  },
  orderBy: {
    created_at: 'asc'
  }
});

const findExistingRole = async ({ tenantId, facilityId }) => prisma.role.findFirst({
  where: {
    tenant_id: tenantId,
    facility_id: facilityId,
    name: ROLE_NAME,
    deleted_at: null
  },
  select: {
    id: true
  }
});

const createRole = async ({ tenantId, facilityId }) => prisma.role.create({
  data: {
    tenant_id: tenantId,
    facility_id: facilityId,
    name: ROLE_NAME,
    description: 'Default AMBULANCE_OPERATOR role'
  }
});

const backfillAmbulanceOperatorRole = async ({ dryRun = false, tenantId = null } = {}) => {
  const summary = {
    dryRun,
    tenantFilter: tenantId,
    tenantsProcessed: 0,
    facilitiesProcessed: 0,
    rolesCreated: 0,
    rolesSkipped: 0,
    rolesWouldCreate: 0,
    failures: 0
  };

  const tenants = await resolveActiveTenants(tenantId);

  if (tenants.length === 0) {
    console.log('No active tenants found for backfill.');
    return summary;
  }

  console.log(`Processing ${tenants.length} active tenant(s)...`);

  for (const tenant of tenants) {
    summary.tenantsProcessed += 1;

    try {
      const facilities = await resolveActiveFacilities(tenant.id);
      const createdBeforeTenant = summary.rolesCreated;
      const wouldCreateBeforeTenant = summary.rolesWouldCreate;

      if (facilities.length === 0) {
        const existingTenantRole = await findExistingRole({
          tenantId: tenant.id,
          facilityId: null
        });

        if (existingTenantRole) {
          summary.rolesSkipped += 1;
          console.log(`- ${tenant.name} (${tenant.id}): tenant-level role already exists`);
          continue;
        }

        if (dryRun) {
          summary.rolesWouldCreate += 1;
          console.log(`- ${tenant.name} (${tenant.id}): would create tenant-level role`);
          continue;
        }

        await createRole({
          tenantId: tenant.id,
          facilityId: null
        });
        summary.rolesCreated += 1;
        console.log(`- ${tenant.name} (${tenant.id}): created tenant-level role`);
        continue;
      }

      summary.facilitiesProcessed += facilities.length;

      for (const facility of facilities) {
        const existingFacilityRole = await findExistingRole({
          tenantId: tenant.id,
          facilityId: facility.id
        });

        if (existingFacilityRole) {
          summary.rolesSkipped += 1;
          continue;
        }

        if (dryRun) {
          summary.rolesWouldCreate += 1;
          continue;
        }

        await createRole({
          tenantId: tenant.id,
          facilityId: facility.id
        });
        summary.rolesCreated += 1;
      }

      const roleAction = dryRun ? 'would create' : 'created';
      const tenantCreatedCount = summary.rolesCreated - createdBeforeTenant;
      const tenantWouldCreateCount = summary.rolesWouldCreate - wouldCreateBeforeTenant;
      console.log(
        `- ${tenant.name} (${tenant.id}): checked ${facilities.length} facility role(s), ${roleAction} ${dryRun ? tenantWouldCreateCount : tenantCreatedCount}`
      );
    } catch (error) {
      summary.failures += 1;
      console.error(`- ${tenant.name} (${tenant.id}): failed - ${error.message}`);
    }
  }

  return summary;
};

const printSummary = (summary) => {
  console.log('');
  console.log('Backfill summary');
  console.log(`- mode: ${summary.dryRun ? 'dry-run' : 'execute'}`);
  console.log(`- tenant filter: ${summary.tenantFilter || 'none'}`);
  console.log(`- tenants processed: ${summary.tenantsProcessed}`);
  console.log(`- facilities processed: ${summary.facilitiesProcessed}`);
  console.log(`- roles created: ${summary.rolesCreated}`);
  console.log(`- roles skipped (already exists): ${summary.rolesSkipped}`);
  if (summary.dryRun) {
    console.log(`- roles that would be created: ${summary.rolesWouldCreate}`);
  }
  console.log(`- failures: ${summary.failures}`);
};

const main = async () => {
  try {
    const args = parseCliArgs();
    const summary = await backfillAmbulanceOperatorRole(args);
    printSummary(summary);

    if (summary.failures > 0) {
      process.exitCode = 1;
    }
  } catch (error) {
    console.error('Failed to backfill AMBULANCE_OPERATOR role:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
};

if (require.main === module) {
  main();
}

module.exports = {
  ROLE_NAME,
  parseCliArgs,
  backfillAmbulanceOperatorRole
};
