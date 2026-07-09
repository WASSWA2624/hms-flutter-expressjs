require('module-alias/register');

const path = require('path');
const BACKEND_ROOT = path.join(__dirname, '..');

try {
  const moduleAlias = require('module-alias');
  moduleAlias.addAliases({
    '@lib': path.join(BACKEND_ROOT, 'src', 'lib'),
    '@config': path.join(BACKEND_ROOT, 'src', 'config'),
    '@prisma/client': path.join(BACKEND_ROOT, 'src', 'prisma', 'client.js'),
  });
} catch (error) {
  console.error('Failed to register sync script aliases:', error);
  process.exit(1);
}

const prisma = require('@prisma/client');
const { ensureTenantAccessCatalog } = require('@lib/authorization/permission-catalog-sync');

const main = async () => {
  const tenants = await prisma.tenant.findMany({
    where: { deleted_at: null },
    select: { id: true, name: true },
    orderBy: { name: 'asc' },
  });

  if (tenants.length === 0) {
    console.log('No tenants found. Nothing to sync.');
    return;
  }

  for (const tenant of tenants) {
    const result = await ensureTenantAccessCatalog(tenant.id);
    console.log(
      `Synced ${tenant.name || tenant.id}: ${result?.permissions ?? 0} permissions, ${result?.roles ?? 0} system roles`,
    );
  }
};

main()
  .catch((error) => {
    console.error('Permission catalog sync failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
