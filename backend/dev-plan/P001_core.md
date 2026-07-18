# P001 Core Foundation
Provide reusable runtime and authorization primitives before domain work starts.

## Runtime

- Implement configuration, constants, typed errors, async handling, response helpers, request context, health helpers, and structured logging.
- Add rate limiting, CORS, security middleware, audit wiring, and canonical role and permission catalogs.

## Access Control

- Authentication must support sessions, `user_role`, permissions, entitlements, ABAC, and break-glass access.
- Middleware must expose stable, reusable authorization behavior.
- Every mutation must have an audit-ready helper path.

## Acceptance

- Core helpers and middleware must be reusable by every module.
- RBAC, ABAC, entitlement, and break-glass behavior must be available before module implementation.
