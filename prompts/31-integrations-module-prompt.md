# Integrations Module — Implementation Prompt

## Objective

Complete the **Integrations Module** for HOSSPI HMS: API keys, external integrations, integration logs, webhooks, interoperability configuration (FHIR/HL7/DICOM where applicable), and external system status — enabling hospital systems to connect without embedding integration logic in OPD/IPD clinical paths.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Integrations row
2. Clinical modules — PACS in [prompts/17-radiology-module-prompt.md](./17-radiology-module-prompt.md); FHIR patient sync may reference patient registry

**Central rule:** integrations are **admin/technical** configuration. OPD and IPD flows consume outcomes (e.g., imaging from PACS, lab results from external LIS) via backend services — not via ad-hoc UI in clinical workspaces.

---

## Flow Integration Requirements

### OPD / IPD (indirect)

| Concept | Integrations responsibility |
| ------- | --------------------------- |
| PACS / DICOM | Radiology `pacs-sync` — configured here, executed in radiology workflow |
| External lab | Results may arrive via integration — surface on lab orders without OPD stage hacks |
| Webhooks | Post domain events (admission, discharge) to external systems |
| API keys | Scoped permissions for third-party read/write — never bypass RBAC |

### App write-up

- Integration logs with replay for failed deliveries.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/integrations/` | Workspace page, controller, repository |
| Backend | `integration`, `integration-log`, `api-key`, `webhook-subscription`, `interop` | |
| APIs | Integrations CRUD + test/sync; API keys; webhooks; `POST /integration-logs/:id/replay`; `/interop` routes | |
| Interop UI | **Hardcoded** capabilities in repository — no live `/interop` calls | |

### Known gaps

- No backend `integrations-workspace` aggregator
- Interop panel not wired to backend
- Webhook secret rotation / retry UX minimal
- Log replay limited UI surfacing
- Link radiology PACS config to integration records

---

## Scope — Core Capabilities

1. **Integrations registry** — create, test connection, sync now, disable.
2. **API keys** — issue, revoke, permission scopes.
3. **Webhooks** — subscriptions, delivery logs.
4. **Integration logs** — filter, replay failed events.
5. **Interop** — wire FHIR/HL7/DICOM status from `/interop` APIs (replace hardcoded list).

---

## Acceptance Criteria

- [ ] Admins can manage API keys and webhooks with audit trail.
- [ ] Integration test/sync actions show clear success/failure.
- [ ] Clinical modules unaffected when integration disabled — graceful degradation.
- [ ] Interop capabilities loaded from backend when available.

---

## Key File References

```
frontend/lib/features/integrations/
backend/src/modules/integration/, api-key/, webhook-subscription/, interop/

Related prompts: prompts/17-radiology-module-prompt.md, prompts/03-tenant-facility-module-prompt.md
```
