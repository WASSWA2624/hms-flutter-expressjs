---
alwaysApply: true
---
# Authentication And Security Rules

Purpose: define backend identity and authorization behavior.

Authentication:
- JWT access tokens and finite-lifetime refresh or session records are required
- session revocation must be supported
- MFA-capable flows must remain compatible with the auth module

Authorization:
- `user_role` is the role-assignment source of truth
- one user may hold multiple active roles simultaneously
- role assignments are scoped and may be time-bound
- RBAC grants baseline permissions; ABAC narrows access by scope, ownership, shift, patient relationship, and emergency state
- module entitlements are enforced in middleware and again in services for sensitive workflows

Management-role requirements:
- support `UNIT_MANAGER`, `WARD_MANAGER`, `ICU_MANAGER`, and `THEATRE_MANAGER`
- HR keeps tenant-wide workforce authority
- scoped managers can manage rosters only inside their assigned scope

Emergency access:
- break-glass access must be explicit, time-limited, and audited
- break-glass review and approval flows must remain queryable for compliance

Sensitive workflow rules:
- patient, billing, payroll, security admin, mortuary release, and closeout actions require full audit evidence
- sensitive reads must be loggable without exposing secret values in standard logs
