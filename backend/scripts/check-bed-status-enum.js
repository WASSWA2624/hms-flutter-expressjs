const prisma = require('../src/prisma/client');

const EXPECTED_VALUES = [
  'AVAILABLE',
  'OCCUPIED',
  'RESERVED',
  'CLEANING',
  'MAINTENANCE',
  'BLOCKED',
  'OUT_OF_SERVICE',
];

const parseEnumValues = (columnType) => {
  const match = String(columnType || '').match(/^enum\((.*)\)$/i);
  if (!match) {
    return null;
  }

  return match[1]
    .split(',')
    .map((value) => value.trim().replace(/^'|'$/g, ''));
};

const main = async () => {
  const [column] = await prisma.$queryRaw`
    SELECT COLUMN_TYPE AS column_type
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'bed'
      AND column_name = 'status'
  `;

  if (!column) {
    console.error('bed.status column not found');
    process.exit(1);
  }

  const actual = parseEnumValues(column.column_type);
  if (!actual) {
    console.error('bed.status is not a MySQL ENUM:', column.column_type);
    process.exit(1);
  }

  const missing = EXPECTED_VALUES.filter((value) => !actual.includes(value));
  const extra = actual.filter((value) => !EXPECTED_VALUES.includes(value));

  if (missing.length || extra.length) {
    console.error('BedStatus enum mismatch');
    if (missing.length) {
      console.error('  Missing:', missing);
    }
    if (extra.length) {
      console.error('  Extra:', extra);
    }
    process.exit(1);
  }

  console.log('BedStatus enum verified:', actual);
};

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
