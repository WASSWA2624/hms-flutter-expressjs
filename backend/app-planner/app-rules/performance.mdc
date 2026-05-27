---
alwaysApply: true
---
# Performance Rules

Purpose: keep the backend responsive under realistic hospital workloads.

Rules:
- paginate list endpoints by default
- use narrow `select` and `include` shapes and avoid N+1 queries
- index hot filter and join columns
- move expensive exports, report generation, and reconciliation work off the request thread
- profile before introducing caches
- p95 targets should stay appropriate for staff-facing workflows and be reviewed in readiness checks
