#!/usr/bin/env node
const prisma = require('../src/prisma/client');

const DEFAULT_POSITION_TITLE = 'UNSPECIFIED';

const main = async () => {
  try {
    const result = await prisma.user.updateMany({
      where: {
        OR: [{ position_title: null }, { position_title: '' }],
        deleted_at: null,
      },
      data: {
        position_title: DEFAULT_POSITION_TITLE,
      },
    });

    console.log(`Backfill complete. Updated users: ${result.count}`);
  } catch (error) {
    console.error(`Backfill failed: ${error.message}`);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect().catch(() => {});
  }
};

main();
