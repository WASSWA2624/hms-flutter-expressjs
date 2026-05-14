#!/usr/bin/env node
const prisma = require('../src/prisma/client');

const normalizeKey = (value) => String(value || '').trim().toUpperCase();

const main = async () => {
  const summary = {
    scannedDrugs: 0,
    matchedPairs: 0,
    created: 0,
    revived: 0,
    updated: 0,
    unmatched: 0,
  };

  try {
    const [drugs, inventoryItems] = await Promise.all([
      prisma.drug.findMany({
        where: {
          deleted_at: null,
          code: {
            not: null,
          },
        },
        select: {
          id: true,
          tenant_id: true,
          code: true,
        },
      }),
      prisma.inventory_item.findMany({
        where: {
          deleted_at: null,
          sku: {
            not: null,
          },
        },
        select: {
          id: true,
          tenant_id: true,
          sku: true,
        },
      }),
    ]);

    summary.scannedDrugs = drugs.length;

    const inventoryByTenantSku = new Map();
    for (const item of inventoryItems) {
      const key = `${item.tenant_id}::${normalizeKey(item.sku)}`;
      if (!inventoryByTenantSku.has(key)) {
        inventoryByTenantSku.set(key, item);
      }
    }

    const activeDefaultByDrug = new Map();
    const activeMappings = await prisma.drug_inventory_map.findMany({
      where: { deleted_at: null },
      select: {
        drug_id: true,
        is_default: true,
      },
    });

    for (const row of activeMappings) {
      if (!activeDefaultByDrug.has(row.drug_id)) {
        activeDefaultByDrug.set(row.drug_id, false);
      }
      if (row.is_default) {
        activeDefaultByDrug.set(row.drug_id, true);
      }
    }

    for (const drug of drugs) {
      const key = `${drug.tenant_id}::${normalizeKey(drug.code)}`;
      const matchedItem = inventoryByTenantSku.get(key);
      if (!matchedItem) {
        summary.unmatched += 1;
        continue;
      }

      summary.matchedPairs += 1;

      const existing = await prisma.drug_inventory_map.findFirst({
        where: {
          drug_id: drug.id,
          inventory_item_id: matchedItem.id,
        },
        select: {
          id: true,
          deleted_at: true,
          is_default: true,
        },
      });

      const shouldDefault = !activeDefaultByDrug.get(drug.id);

      if (!existing) {
        await prisma.drug_inventory_map.create({
          data: {
            tenant_id: drug.tenant_id,
            drug_id: drug.id,
            inventory_item_id: matchedItem.id,
            is_default: shouldDefault,
          },
        });

        activeDefaultByDrug.set(drug.id, shouldDefault);
        summary.created += 1;
        continue;
      }

      if (existing.deleted_at) {
        await prisma.drug_inventory_map.update({
          where: { id: existing.id },
          data: {
            deleted_at: null,
            is_default: existing.is_default || shouldDefault,
            tenant_id: drug.tenant_id,
          },
        });

        activeDefaultByDrug.set(drug.id, existing.is_default || shouldDefault);
        summary.revived += 1;
        continue;
      }

      const nextIsDefault = existing.is_default || shouldDefault;
      if (nextIsDefault !== existing.is_default) {
        await prisma.drug_inventory_map.update({
          where: { id: existing.id },
          data: {
            is_default: nextIsDefault,
            tenant_id: drug.tenant_id,
          },
        });

        activeDefaultByDrug.set(drug.id, nextIsDefault);
        summary.updated += 1;
      }
    }

    console.log('Drug-inventory mapping backfill complete.');
    console.log(summary);
  } catch (error) {
    console.error(`Backfill failed: ${error.message}`);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect().catch(() => {});
  }
};

main();
