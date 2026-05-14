# P000 Setup

Goal: establish a reproducible backend workspace.

Do:
- confirm Node, CommonJS, Prisma, Jest, ESLint, and Nodemon baseline
- keep only essential script families: runtime, test, lint, openapi, prisma, seed, diagnostics, backfill, report
- validate env loading and keep secrets out of source control
- verify alias registration, Jest config, and startup diagnostics

Acceptance:
- `npm run dev`, `npm test`, `npm run lint`, and `npm run prisma:generate` work
- script inventory is lean and duplicate script names are removed before new scripts are added
- env template covers every required runtime variable
