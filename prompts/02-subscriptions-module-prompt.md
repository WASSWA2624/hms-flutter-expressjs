# Subscription Management Module — Implementation Prompt

## Objective

Complete **Subscription Management** for HOSSPI HMS so tenant admins and platform operators can manage commercial entitlements end-to-end: subscription plans, active subscriptions, module subscriptions, licenses, invoices, renewal state, and plan limits — controlling which hospital modules (including OPD and IPD) are enabled.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Subscription management row; demo seed subscription data
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — OPD module gated by `opd-flow` entitlement
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — IPD gated by `inpatient-bed-management` / related entitlements

**Central rule:** module entitlements drive route visibility and backend `module-entitlement` middleware. Subscription changes should prompt session refresh or realtime entitlement updates.

---

## Flow Integration Requirements

### OPD / IPD

| Concept | Subscriptions responsibility |
| ------- | -------------------------- |
| Module gates | `module-subscription` activates OPD, IPD, ICU, etc. |
| Plan limits | Enforce user/bed/module limits per plan — surface in admin UI |
| Demo seed | Default plan + module subscriptions for safe demos (app-write-up) |

### App write-up

- Subscription invoices, renewal, license state visibility for tenant admins.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/subscriptions/` | Workspace page, controller, repository |
| Backend | `subscriptions-workspace`, `subscription-plan`, `subscription`, `module-subscription`, `license`, `subscription-invoice` | |
| APIs | `GET /subscriptions-workspace/workspace`; plan/subscription CRUD; renew/upgrade/downgrade; module activate/deactivate; invoice collect/retry | |
| Feature flag | Workspace may be gated | |

### Known gaps

- `reference-data` and `resolve-legacy` unused in frontend
- No payment-provider checkout UI for invoice collect
- Entitlement changes not realtime on other open workspaces
- Cross-tenant super-admin UX limited
- Link from tenant setup to subscription status could be stronger

---

## Scope — Core Capabilities

1. **Plans and tiers** — CRUD subscription plans; feature/module matrix.
2. **Active subscription** — renew, upgrade, downgrade with confirmation.
3. **Module subscriptions** — enable/disable clinical modules per tenant.
4. **Licenses** — view license state and limits.
5. **Invoices** — list subscription invoices; collect/retry when API supports.

---

## Acceptance Criteria

- [ ] Tenant admin can view and manage subscription and module entitlements.
- [ ] Disabling OPD/IPD module hides routes and backend returns 403/404 appropriately.
- [ ] Demo seed subscription documented and testable.
- [ ] No raw UUIDs; permissions enforced.

---

## Key File References

```
frontend/lib/features/subscriptions/
backend/src/modules/subscriptions-workspace/

Related prompts: prompts/03-tenant-facility-module-prompt.md, prompts/04-access-admin-module-prompt.md
```
