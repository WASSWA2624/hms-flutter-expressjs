# Reports, Dashboards, and Audit Module — Implementation Prompt

## Objective

Complete **Reports, Dashboards, and Audit** for HOSSPI HMS: role-based reports, report definitions and runs, scheduled reports, exports, audit logs, PHI access logs, data processing logs, and compliance evidence review — **read-only** visibility into OPD/IPD and all modules without replacing module workflows.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Reports, dashboards, and audit row; Access Control Expectations
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — audit of OPD stage transitions via backend audit layer
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — traceability §16; discharge and billing audit trails

**Central rule:** reports and audit **read from** modules; they must not mutate OPD/IPD encounters, orders, or billing.

---

## Flow Integration Requirements

### OPD / IPD

| Concept | Reports/audit responsibility |
| ------- | ---------------------------- |
| Operational reports | OPD visit volumes, wait times, disposition breakdowns |
| Inpatient reports | Admission, LOS, bed occupancy, discharge metrics |
| Audit logs | Who changed OPD stage, IPD bed assignment, discharge finalize |
| PHI access logs | Patient chart access review for compliance |
| Dashboard overlap | [prompts/28-home-dashboard-module-prompt.md](./28-home-dashboard-module-prompt.md) for landing KPIs; this module for deep reports |

### App write-up

- Scheduled reports and exports for administrators.
- Compliance evidence and activity review.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/reports/` | Workspace page, controller, repository |
| Backend | `reports-workspace`, `report-definition`, `report-run`, `report-schedule`, `audit-log`, `phi-access-log`, `data-processing-log` | |
| APIs | `GET /reports-workspace`; `POST /report-definitions/:id/run`; download report runs; compliance log lists | |
| Home | `review_audit` quick action → reports route | |
| Feature flag | `reports_workspace_v1` | |

### Known gaps

- `/reports-workspace/lookups` unused
- Download disabled when backend sets `download_available: false`
- Compliance logs read-only lists without drill-down workspace
- No embedded OPD/IPD-specific report templates in UI beyond backend definitions
- Frontend tests limited

---

## Scope — Core Capabilities

1. **Report catalog** — definitions by category; run with parameters.
2. **Report runs** — status, download/preview when available.
3. **Schedules** — CRUD scheduled reports.
4. **Audit logs** — filter by user, action, resource, date; link to entity display IDs.
5. **Compliance logs** — PHI access and data processing review for admins.

---

## Acceptance Criteria

- [ ] Authorized users can run and download reports per permissions.
- [ ] Audit logs searchable for OPD/IPD actions (via backend audit entries).
- [ ] Reports module does not expose write APIs for clinical/financial mutations.
- [ ] Export/download respects platform capabilities.

---

## Key File References

```
frontend/lib/features/reports/
backend/src/modules/reports-workspace/, audit-log/, phi-access-log/

Related prompts: prompts/28-home-dashboard-module-prompt.md, prompts/01-opd-module-prompt.md, prompts/05-ipd-module-prompt.md
```
