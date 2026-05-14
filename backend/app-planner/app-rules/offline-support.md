---
alwaysApply: true
---
# Offline Support Rules

Purpose: define server behavior for sync-capable clients.

Rules:
- offline-capable mutations require idempotency and deterministic conflict handling
- list and detail endpoints exposed to offline clients should support incremental sync metadata
- auth, entitlement changes, break-glass approval, payments, refunds, mortuary release, and last-office final close are online-only actions
- conflict responses must identify the conflicting record and latest version metadata
- server logic must never assume the client clock is authoritative
