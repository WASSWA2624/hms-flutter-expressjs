// TEMPORARY - rewrites RENAME INDEX into portable CREATE/DROP INDEX pairs.
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

const MIG = path.join(__dirname, 'prisma', 'migrations');
const TARGET = path.join(MIG, '20260816090000_sync_schema_drift', 'migration.sql');
const SHADOW = 'hms_shadow_diff';

const url = new URL(
  fs.readFileSync(path.join(__dirname, '.env.development'), 'utf8')
    .match(/^DATABASE_URL\s*=\s*"?([^"\r\n]+)"?/m)[1]
);

const main = async () => {
  const conn = await mysql.createConnection({
    host: url.hostname,
    port: url.port || 3306,
    user: decodeURIComponent(url.username),
    password: decodeURIComponent(url.password),
    multipleStatements: true,
  });

  await conn.query(`DROP DATABASE IF EXISTS \`${SHADOW}\``);
  await conn.query(`CREATE DATABASE \`${SHADOW}\``);
  await conn.query(`USE \`${SHADOW}\``);

  // Replay history up to (but excluding) the new migration.
  const dirs = fs.readdirSync(MIG).filter((d) => d < '20260816090000_sync_schema_drift').sort();
  for (const d of dirs) {
    const sql = fs.readFileSync(path.join(MIG, d, 'migration.sql'), 'utf8');
    try {
      await conn.query(sql);
    } catch (e) {
      console.error(`FAILED replaying ${d}: ${e.message}`);
      process.exit(1);
    }
  }
  console.log(`replayed ${dirs.length} migrations into ${SHADOW}`);

  let sql = fs.readFileSync(TARGET, 'utf8');
  const re = /ALTER TABLE `([^`]+)` RENAME INDEX `([^`]+)` TO `([^`]+)`;/g;
  const jobs = [...sql.matchAll(re)];

  for (const [stmt, table, oldName, newName] of jobs) {
    const [rows] = await conn.query(
      `SELECT COLUMN_NAME, NON_UNIQUE, SEQ_IN_INDEX FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND INDEX_NAME = ? ORDER BY SEQ_IN_INDEX`,
      [SHADOW, table, oldName]
    );
    if (!rows.length) {
      console.error(`no columns found for ${table}.${oldName}`);
      process.exit(1);
    }
    const cols = rows.map((r) => `\`${r.COLUMN_NAME}\``).join(', ');
    const unique = rows[0].NON_UNIQUE === 0 ? 'UNIQUE ' : '';
    const replacement =
      `CREATE ${unique}INDEX \`${newName}\` ON \`${table}\`(${cols});\n` +
      `DROP INDEX \`${oldName}\` ON \`${table}\`;`;
    sql = sql.replace(stmt, replacement);
  }

  fs.writeFileSync(TARGET, sql, 'utf8');
  console.log(`rewrote ${jobs.length} RENAME INDEX statements`);
  await conn.end();
};

main().catch((e) => {
  console.error('ERR', e.message);
  process.exit(1);
});
