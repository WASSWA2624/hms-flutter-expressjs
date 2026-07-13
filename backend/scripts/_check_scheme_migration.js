require('dotenv').config();
const mysql = require('mysql2/promise');

async function main() {
  const url = new URL(process.env.DATABASE_URL.replace(/^mysql:/, 'http:'));
  const conn = await mysql.createConnection({
    host: url.hostname,
    port: Number(url.port || 3306),
    user: decodeURIComponent(url.username),
    password: decodeURIComponent(url.password),
    database: url.pathname.replace(/^\//, ''),
  });

  const queries = [
    "SHOW TABLES LIKE 'insurance_company'",
    "SHOW COLUMNS FROM coverage_plan LIKE 'insurance_company_id'",
    "SHOW TABLES LIKE 'scheme_offer'",
    "SHOW COLUMNS FROM price_book_entry LIKE 'insurance_company_id'",
    "SHOW COLUMNS FROM invoice_item LIKE 'scheme_offer_id'",
  ];

  for (const sql of queries) {
    const [rows] = await conn.query(sql);
    console.log(sql, '=>', rows);
  }

  await conn.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
