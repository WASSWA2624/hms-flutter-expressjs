const prisma = require('../src/prisma/client');

const expected = [
  { table: 'lab_order', column: 'ordered_by_user_id' },
  { table: 'lab_result', column: 'interpretation_override' },
  { table: 'lab_result', column: 'reference_range_override' },
  { table: 'lab_result', column: 'result_flag_override' },
];

const main = async () => {
  const rows = await prisma.$queryRaw`
    SELECT table_name, column_name
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND (
        (table_name = 'lab_order' AND column_name = 'ordered_by_user_id')
        OR (
          table_name = 'lab_result'
          AND column_name IN (
            'interpretation_override',
            'reference_range_override',
            'result_flag_override'
          )
        )
      )
  `;

  const found = new Set(rows.map((row) => `${row.table_name}.${row.column_name}`));
  const missing = expected.filter(
    (entry) => !found.has(`${entry.table}.${entry.column}`)
  );

  if (missing.length) {
    console.error('Missing lab workflow columns:', missing);
    process.exit(1);
  }

  console.log('Lab workflow migration columns verified:', [...found].sort());
};

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
