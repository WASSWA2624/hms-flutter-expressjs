---
alwaysApply: true
---
# Project Structure Rules

Purpose: define the canonical backend file layout.

Canonical folders:
- root tooling: `package.json`, lockfile, eslint, jest, nodemon, env template, README
- `scripts/`: essential development, validation, seed, maintenance, diagnostics scripts only
- `prisma/`: schema, migrations, seed entrypoint, prisma-specific maintenance scripts
- `src/app/`: express app bootstrap and root router
- `src/config/`: validated environment access and static config
- `src/lib/`: shared stateless helpers
- `src/middlewares/`: reusable middleware
- `src/modules/<module>/`: routes, controllers, services, repositories, schemas
- `src/prisma/`: client wrapper
- `src/websockets/`: realtime server and gateway
- `src/locales/`: backend locale catalog files
- `src/tests/`: tests mirroring runtime ownership
- `src/generated/`: generated artifacts committed by policy only when required by deployment constraints

Structure rules:
- all business code lives under `src/`
- one backend module maps to one folder under `src/modules/`
- module tests mirror module structure under `src/tests/modules/<module>/`
- shared code must not become a dumping ground for module-specific logic
- script families must be consolidated before new script names are added
- if a script becomes obsolete, remove it in the same change that obsoletes it
