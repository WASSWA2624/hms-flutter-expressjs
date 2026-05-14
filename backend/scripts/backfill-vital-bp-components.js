/**
 * Backfill vital sign BP component columns
 *
 * Populates systolic_value, diastolic_value, and map_value for legacy
 * blood pressure rows that only stored value as "SYS/DIA".
 *
 * Usage:
 *   node scripts/backfill-vital-bp-components.js
 *   node scripts/backfill-vital-bp-components.js --dry-run
 */

const path = require('path');
const prisma = require(path.join(__dirname, '..', 'src', 'prisma', 'client'));

const BP_VALUE_REGEX = /^(\d{2,3}(?:\.\d{1,2})?)\s*\/\s*(\d{2,3}(?:\.\d{1,2})?)$/;
const BATCH_SIZE = 500;

const toFiniteNumber = (value) => {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === 'string') {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value?.toNumber === 'function') {
    const parsed = value.toNumber();
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value?.toString === 'function') {
    const parsed = Number(value.toString());
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
};

const roundToTwo = (value) => {
  if (!Number.isFinite(value)) return null;
  return Math.round(value * 100) / 100;
};

const formatBpComponent = (value) => {
  if (!Number.isFinite(value)) return '';
  const rounded = roundToTwo(value);
  return Number.isInteger(rounded) ? String(rounded) : String(rounded);
};

const parseLegacyBpValue = (value) => {
  const match = String(value || '').trim().match(BP_VALUE_REGEX);
  if (!match) return null;

  const systolic = toFiniteNumber(match[1]);
  const diastolic = toFiniteNumber(match[2]);

  if (!Number.isFinite(systolic) || !Number.isFinite(diastolic)) {
    return null;
  }

  return {
    systolic: roundToTwo(systolic),
    diastolic: roundToTwo(diastolic),
  };
};

const computeMap = (systolic, diastolic) => {
  if (!Number.isFinite(systolic) || !Number.isFinite(diastolic)) return null;
  return roundToTwo((systolic + 2 * diastolic) / 3);
};

const parseCliOptions = (argv = process.argv.slice(2)) => ({
  dryRun: argv.includes('--dry-run'),
});

const backfillBpComponents = async ({ dryRun = false } = {}) => {
  const summary = {
    dryRun,
    scanned: 0,
    updated: 0,
    unchanged: 0,
    unparsable: 0,
  };

  let cursorId = null;

  while (true) {
    const rows = await prisma.vital_sign.findMany({
      where: {
        deleted_at: null,
        vital_type: 'BLOOD_PRESSURE',
      },
      select: {
        id: true,
        value: true,
        systolic_value: true,
        diastolic_value: true,
        map_value: true,
      },
      orderBy: {
        id: 'asc',
      },
      take: BATCH_SIZE,
      ...(cursorId
        ? {
            cursor: { id: cursorId },
            skip: 1,
          }
        : {}),
    });

    if (rows.length === 0) break;

    for (const row of rows) {
      summary.scanned += 1;

      const existingSystolic = roundToTwo(toFiniteNumber(row.systolic_value));
      const existingDiastolic = roundToTwo(toFiniteNumber(row.diastolic_value));
      const existingMap = roundToTwo(toFiniteNumber(row.map_value));

      const parsedLegacy = parseLegacyBpValue(row.value);

      const systolic = Number.isFinite(existingSystolic)
        ? existingSystolic
        : parsedLegacy?.systolic ?? null;
      const diastolic = Number.isFinite(existingDiastolic)
        ? existingDiastolic
        : parsedLegacy?.diastolic ?? null;
      const mapValue = Number.isFinite(existingMap)
        ? existingMap
        : computeMap(systolic, diastolic);

      if (!Number.isFinite(systolic) || !Number.isFinite(diastolic)) {
        summary.unparsable += 1;
        summary.unchanged += 1;
        continue;
      }

      const canonicalValue = `${formatBpComponent(systolic)}/${formatBpComponent(diastolic)}`;
      const currentValue = String(row.value || '').trim();

      const data = {};
      if (!Number.isFinite(existingSystolic)) {
        data.systolic_value = systolic;
      }
      if (!Number.isFinite(existingDiastolic)) {
        data.diastolic_value = diastolic;
      }
      if (!Number.isFinite(existingMap) && Number.isFinite(mapValue)) {
        data.map_value = mapValue;
      }
      if (currentValue !== canonicalValue) {
        data.value = canonicalValue;
      }

      if (Object.keys(data).length === 0) {
        summary.unchanged += 1;
        continue;
      }

      if (!dryRun) {
        await prisma.vital_sign.update({
          where: { id: row.id },
          data,
        });
      }

      summary.updated += 1;
    }

    cursorId = rows[rows.length - 1].id;
  }

  return summary;
};

const printSummary = (summary) => {
  console.log('BP backfill summary');
  console.log(`- mode: ${summary.dryRun ? 'dry-run' : 'execute'}`);
  console.log(`- rows scanned: ${summary.scanned}`);
  console.log(`- rows updated: ${summary.updated}`);
  console.log(`- rows unchanged: ${summary.unchanged}`);
  console.log(`- rows unparsable: ${summary.unparsable}`);
};

const main = async () => {
  try {
    const options = parseCliOptions();
    const summary = await backfillBpComponents(options);
    printSummary(summary);
  } catch (error) {
    console.error('Failed to backfill BP component fields:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
};

if (require.main === module) {
  main();
}

module.exports = {
  BP_VALUE_REGEX,
  parseLegacyBpValue,
  backfillBpComponents,
};
