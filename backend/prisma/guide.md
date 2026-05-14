# Prisma Guide - HMS Backend

## Overview
This backend uses Prisma 7.x with the MariaDB adapter pattern.

- CLI config: `prisma.config.js`
- Runtime client wrapper: `src/prisma/client.js`
- Schema: `prisma/schema.prisma`
- Connection URL source: `src/config/env.js` only

## Phase 2 Foundation Contracts

- `prisma/schema.prisma` must keep `datasource db` without `url =`.
- `prisma.config.js` must load validated env from `src/config/env.js`.
- `src/prisma/client.js` must use `@prisma/adapter-mariadb` and keep env access centralized through `src/config/env.js`.
- Base connectivity checks should fail fast on the Prisma path (2s timeout in readiness helper).

## Common Commands

### Generate Prisma Client
```sh
npx prisma generate
```

### Create and Apply Dev Migration
```sh
npx prisma migrate dev --name <migration_name>
```

### Apply Migrations in Production
```sh
npx prisma migrate deploy
```

### Open Prisma Studio
```sh
npx prisma studio
```

### Validate and Format Schema
```sh
npx prisma validate
npx prisma format
```

## Connection Pool Sizing

Prisma adapter pool settings are environment-driven and validated in `src/config/env.js`.

- `PRISMA_POOL_CONNECTION_LIMIT` (default: `10`)
- `PRISMA_POOL_CONNECT_TIMEOUT_MS` (default: `5000`)
- `PRISMA_POOL_ACQUIRE_TIMEOUT_MS` (default: `5000`)
- `PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL` (default: `true` in `development`, `false` otherwise)

Production sizing guidance:

- Start with `10` connections per app instance.
- Increase gradually based on DB CPU, active workload, and query latency.
- Keep total pooled connections across all app instances below database capacity.
- Monitor connection wait time and slow query rate before raising limits again.

## Migration Rollback Strategy (Forward-Only)

Prisma migrations are forward-only. Do not edit or delete applied migrations.

- Rollback by creating a new reversing migration.
- Reversal migration names must use `rollback_` prefix.
- Example: `rollback_add_entitlement_controls`.

Operational runbook:

- `docs/migrations/v1.md`

## Troubleshooting

### Client out of sync
Run:
```sh
npx prisma generate
```

### Prisma pool timeout or `ER_CANNOT_RETRIEVE_RSA_KEY`
If Prisma times out during login or startup and the underlying MySQL auth error is
`ER_CANNOT_RETRIEVE_RSA_KEY`, your local MySQL 8 setup likely requires RSA public-key
retrieval during password authentication.

Use:
```sh
PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL="true"
```

This flag is intended as a local-development compatibility switch. In production,
prefer TLS or explicit server-side RSA/auth-plugin configuration instead of enabling
public key retrieval by default.

### Migration failed
1. Check database connectivity.
2. Review SQL in `prisma/migrations/<timestamp>_<name>/migration.sql`.
3. Fix schema or migration inputs and rerun in development/staging first.

### Prisma client package missing
Run:
```sh
npm install
```

## References
- `./../.cursor/rules/prisma.mdc`
- `./../docs/migrations/v1.md`
