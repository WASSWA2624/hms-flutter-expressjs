# Global Delivery & Acceptance — Implementation Prompt

## Objective

Establish and enforce the cross-cutting delivery contract for every HOSSPI HMS improvement. Implementers must satisfy these rules before claiming any section complete. Do not re-implement compliant behavior; audit first and change only gaps, obsolete code, or non-compliant areas.

**Source requirement:** [prompt.md](../prompt.md) §0  
**Authority order:** [`.cursor/index.mdc`](../.cursor/index.mdc) → stack indexes → flow/access rules

---

## Mandatory reading (before any change)

1. [`.cursor/index.mdc`](../.cursor/index.mdc) — conflict precedence
2. [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc) — HTTP, IDs, envelopes, offline
3. [`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc) + [`realtime_sync.mdc`](../frontend/.cursor/realtime_sync.mdc)
4. [`backend/.cursor/index.mdc`](../backend/.cursor/index.mdc) and [`frontend/.cursor/index.mdc`](../frontend/.cursor/index.mdc)
5. Applicable flow/access files for the touched domain

---

## Step-by-step instructions

### 1. Audit before coding

- Inspect existing frontend feature folders, backend modules, Prisma schema, shared components, and tests for the target change.
- Document what already complies; list only missing, obsolete, or non-compliant items.
- Preserve correct behavior; do not duplicate services, repositories, controllers, providers, or design-system primitives.

### 2. Architecture & boundaries

- Keep Flutter `data/domain/presentation` and backend module/layer boundaries intact.
- Widgets must not call APIs, databases, or sync services directly.
- Reuse existing shared code before adding new implementations.

### 3. End-to-end delivery checklist

For each feature, cover as applicable:

1. Database schema + safe migration/backfill + rollback/recovery notes
2. Backend validation, authorization, transactionality, audit
3. Versioned `/api/v1/*` API with normalized envelopes
4. Domain event after persistence and audit
5. Frontend Riverpod state + UI + localization (`app_en.arb` only unless asked otherwise)
6. Automated tests proportional to risk
7. Documentation updates; remove stale docs

### 4. Identifiers & API contract

- Public APIs, routes, UI state, deep links, and realtime events use `human_friendly_id` (or approved domain display IDs).
- Backend repositories map public IDs ↔ internal IDs at the data boundary only.
- Payloads/query params: lowercase `snake_case`; UTC ISO-8601 timestamps; safe pagination.
- Validate path/query/body at the API boundary; reject unknown/unsafe fields without leaking PHI, secrets, or record existence.

### 5. Mutation & sync contract

Every shared-data mutation must:

1. Persist through HTTP (WebSockets are never a mutation transport)
2. Patch all affected Riverpod state immediately after success
3. Leave UI unchanged on cancel/failure
4. Emit a scoped backend domain event after persistence + audit
5. Reconcile authorized clients via WebSocket + smallest targeted refresh

Reconnect must recover missed events; do not promise fixed delivery latency.

### 6. Scope, offline, storage, observability

- Scope data, caches, events, reports, and navigation to authenticated user, tenant, facility, and finer ABAC context.
- Queue offline only mutations allowed by the API contract; auth/session, payments, refunds, billing closeout, break-glass, mortuary release, and final close are online-only.
- Sensitive documents/imaging/reports: controlled, access-checked storage only.
- Structured logs with redaction; keep audit evidence separate from app logs; preserve `/health`, `/ready`, `/live`.

### 7. UX quality bars

- Localize all user-facing and accessibility text; use shared locale-aware formatters.
- Design tokens only — no hardcoded colors, typography, spacing, shape, or elevation in feature code.
- Meet accessibility: semantics, keyboard/focus, text scaling, contrast, non-color status cues, practical targets.
- Server-side filter/paginate worklists; lazy-render; avoid unnecessary full-workspace reloads.

---

## Definition of done

- Applicable quality gates pass (frontend format/analyze/test; targeted backend tests).
- No obsolete duplicate implementation remains.
- Unauthorized, cross-scope, cancel, failure, conflict, reconnect, and retry paths are covered where relevant.

### Executable delivery gate

Run the repository gate from the project root:

```powershell
.\scripts\delivery-gate.ps1
```

```sh
./scripts/delivery-gate.sh
```

The gate refreshes Flutter generated code and verifies formatting, analysis, and
tests, then runs the backend delivery-contract lint, targeted tests, and OpenAPI
validation. CI additionally rejects stale committed generated code. Run
module-specific tests for every touched domain in addition to this baseline.
Schema changes must follow the
[`backend/docs/migrations/v1.md`](../backend/docs/migrations/v1.md) deployment
and recovery runbook.

## Related prompts

All numbered prompts in this folder inherit this contract. Specialize per domain; never weaken security, integrity, or sync rules.
