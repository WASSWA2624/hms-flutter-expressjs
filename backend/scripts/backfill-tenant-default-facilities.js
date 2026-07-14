/**
 * Backfill a default facility for tenants that have none.
 *
 * Usage: node scripts/backfill-tenant-default-facilities.js
 */

const prisma = require('../src/prisma/client');

const buildDefaultFacilityName = (tenantName) => {
  const normalized = String(tenantName || '').trim();
  if (!normalized) {
    return 'Main Facility';
  }
  return `${normalized} Main Facility`;
};

const main = async () => {
  const tenants = await prisma.tenant.findMany({
    where: { deleted_at: null },
    select: {
      id: true,
      name: true,
      facilities: {
        where: { deleted_at: null },
        select: { id: true },
        take: 1,
      },
    },
  });

  let created = 0;
  for (const tenant of tenants) {
    if ((tenant.facilities || []).length > 0) {
      continue;
    }

    await prisma.facility.create({
      data: {
        tenant_id: tenant.id,
        name: buildDefaultFacilityName(tenant.name),
        facility_type: 'HOSPITAL',
        is_active: true,
      },
    });
    created += 1;
    console.log(`Created default facility for tenant ${tenant.name} (${tenant.id})`);
  }

  console.log(`Backfill complete. Created ${created} facilities.`);
};

main()
  .catch((error) => {
    console.error('Backfill failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
