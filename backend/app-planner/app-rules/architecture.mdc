---
alwaysApply: true
---
# Architecture Rules

Purpose: define the required backend architecture.

Runtime and framework:
- Node.js runtime only.
- Express.js owns HTTP transport.
- CommonJS module syntax only.
- Long-running work runs in documented worker or async job paths, not in request threads.

Layer order:
`route -> controller -> service -> repository -> prisma`

Layer rules:
- routes map URLs and middleware only
- controllers translate HTTP to service calls and response helpers only
- services own business logic, authorization decisions, workflow orchestration, audit calls, and cross-module coordination
- repositories own Prisma access and query composition only
- Prisma model access outside repositories is forbidden, except transaction orchestration through `prisma.$transaction(...)`

Module rules:
- one domain capability per module
- modules expose standalone workflows and explicit integration points
- services may depend on other services or shared libs, never on another module's controller or repository
- module entitlement checks must exist in both middleware and service layers for sensitive workflows

Dependency rules:
- dependency direction must always move downward through the layer stack
- shared helpers live in `src/lib/*` only when they are stateless and reused by multiple modules
- circular imports, reverse imports, and hidden side effects are defects

Lifecycle rules:
- `src/server.js` owns startup and graceful shutdown
- shutdown must close HTTP, Prisma, storage, and websocket resources cleanly
- startup diagnostics may fail fast when mandatory dependencies are unavailable
