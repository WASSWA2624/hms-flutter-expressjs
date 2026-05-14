#!/usr/bin/env node
const prisma = require('../src/prisma/client');

const main = async () => {
  try {
    const users = await prisma.user.findMany({
      where: {
        deleted_at: null,
        OR: [{ position_title: null }, { position_title: '' }, { position_title: 'UNSPECIFIED' }],
      },
      select: {
        id: true,
        human_friendly_id: true,
        tenant_id: true,
        facility_id: true,
        email: true,
        phone: true,
        position_title: true,
        created_at: true,
      },
      orderBy: [{ tenant_id: 'asc' }, { created_at: 'asc' }],
    });

    console.log(`Users requiring position-title remediation: ${users.length}`);
    if (users.length === 0) return;

    for (const user of users) {
      console.log(
        [
          `tenant=${user.tenant_id}`,
          `facility=${user.facility_id || '-'}`,
          `user=${user.human_friendly_id || user.id}`,
          `email=${user.email || '-'}`,
          `phone=${user.phone || '-'}`,
          `position_title=${user.position_title || 'NULL'}`,
        ].join(' | ')
      );
    }
  } catch (error) {
    console.error(`Report failed: ${error.message}`);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect().catch(() => {});
  }
};

main();
