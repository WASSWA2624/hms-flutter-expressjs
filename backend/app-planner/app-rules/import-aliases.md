---
alwaysApply: true
---
# Import Alias Rules

Purpose: keep imports stable and prevent boundary drift.

Root aliases from `jsconfig.json`:
- `@app/* -> src/app/*`
- `@lib/* -> src/lib/*`
- `@middlewares/* -> src/middlewares/*`
- `@config/* -> src/config/*`
- `@prisma/client -> src/prisma/client.js`
- `@logs/* -> logs/*`
- `@websockets/* -> src/websockets/*`
- `@modules/* -> src/modules/*`

Runtime module aliases:
- `@controllers/<module>`
- `@services/<module>`
- `@repositories/<module>`
- `@validations/<module>`
- `@routes/<module>`

Import rules:
- use aliases for cross-folder imports
- relative imports may stay inside the same folder tree only
- modules may import another module only through public service or shared-lib entrypoints
- controllers and repositories are never imported across modules
- alias changes require synchronized updates to runtime alias registration and docs
- imports must not create circular dependency chains
