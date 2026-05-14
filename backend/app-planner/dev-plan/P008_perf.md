# P008 Performance

Goal: harden the backend for realistic hospital throughput.

Do:
- enforce pagination, index coverage, and query-shape review
- move expensive exports, reporting, and reconciliation work off request threads
- add readiness and performance checks for hot endpoints

Acceptance:
- performance budgets exist for staff-critical reads and mutations
- N+1 query patterns and unnecessary payload bloat are removed
- readiness checks reflect real bottlenecks before release
