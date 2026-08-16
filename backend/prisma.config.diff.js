// TEMPORARY - used only to verify the drift migration; delete after use.
const fs = require('fs');
const path = require('path');

const raw = fs.readFileSync(path.join(__dirname, '.env.development'), 'utf8');
const match = raw.match(/^DATABASE_URL\s*=\s*"?([^"\r\n]+)"?/m);
const url = new URL(match[1]);
url.pathname = '/hms_shadow_diff';

module.exports = {
  schema: './prisma/schema.prisma',
  datasource: {
    url: url.toString(),
    shadowDatabaseUrl: url.toString(),
  },
};
