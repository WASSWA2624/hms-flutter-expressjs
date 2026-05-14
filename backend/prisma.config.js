const env = require('./src/config/env');

module.exports = {
  schema: './prisma/schema.prisma',
  datasource: {
    url: env.getDatabaseUrlForPrisma(),
  },
};
