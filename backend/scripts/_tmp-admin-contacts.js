require('module-alias/register');
const path = require('path');
const moduleAlias = require('module-alias');
moduleAlias.addAliases({
  '@prisma/client': path.join(__dirname, '..', 'src', 'prisma', 'client.js'),
  '@config': path.join(__dirname, '..', 'src', 'config'),
  '@lib': path.join(__dirname, '..', 'src', 'lib'),
});
moduleAlias.addAlias(
  '@prisma/client/runtime',
  path.join(__dirname, '..', 'node_modules', '@prisma', 'client', 'runtime')
);
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const prisma = require('@prisma/client');
const { resolveOrgAdminContacts } = require('../src/lib/authorization/org-admin-contacts');
const { resolvePlatformAdminContact } = require('../src/lib/subscriptions/tenant-subscription-summary');

async function main() {
  const roles = await prisma.role.findMany({
    where: { deleted_at: null },
    select: { name: true, tenant_id: true },
    take: 50,
  });
  console.log('roles', roles.map((r) => r.name));

  const tenants = await prisma.tenant.findMany({
    where: { deleted_at: null },
    select: { id: true, name: true },
    take: 5,
  });
  console.log('tenants', tenants);

  for (const tenant of tenants) {
    const contacts = await resolveOrgAdminContacts({ tenantId: tenant.id });
    console.log(tenant.name, contacts);
  }

  console.log('platform', resolvePlatformAdminContact());
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error(e);
  await prisma.$disconnect();
  process.exit(1);
});
