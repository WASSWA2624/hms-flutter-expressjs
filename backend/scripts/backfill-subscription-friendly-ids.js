#!/usr/bin/env node
const prisma = require('../src/prisma/client');
const {
  PUBLIC_ID_PREFIXES,
  createSubscriptionPublicId,
} = require('../src/lib/subscriptions/constants');

const TASKS = [
  { model: 'subscription_plan', prefix: PUBLIC_ID_PREFIXES.subscription_plan },
  { model: 'subscription', prefix: PUBLIC_ID_PREFIXES.subscription },
  { model: 'subscription_invoice', prefix: PUBLIC_ID_PREFIXES.subscription_invoice },
  { model: 'module', prefix: PUBLIC_ID_PREFIXES.module },
  { model: 'module_subscription', prefix: PUBLIC_ID_PREFIXES.module_subscription },
  { model: 'license', prefix: PUBLIC_ID_PREFIXES.license },
];

const main = async () => {
  try {
    for (const task of TASKS) {
      const delegate = prisma[task.model];
      const rows = await delegate.findMany({
        where: {
          deleted_at: null,
          OR: [{ human_friendly_id: null }, { human_friendly_id: '' }],
        },
        select: { id: true },
      });

      let updated = 0;
      for (const row of rows) {
        await delegate.update({
          where: { id: row.id },
          data: {
            human_friendly_id: createSubscriptionPublicId(task.prefix),
          },
        });
        updated += 1;
      }

      console.log(`${task.model}: updated ${updated}`);
    }
  } catch (error) {
    console.error(`Backfill failed: ${error.message}`);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect().catch(() => {});
  }
};

main();
