# Super Admin Dashboard — Content & Data Refinement

## Objective

Refine the **platform administrator** (`SUPER_ADMIN`) home dashboard so every section surfaces **tenant, facility, and subscription intelligence** — not clinical/patient data. The super admin manages tenants, facilities, subscriptions, and platform health.

**Constraint:** Do **not** change UI layout, component structure, spacing, or visual design. Update **labels, copy, data bindings, actions, and backend payloads only**. All displayed values must be **accurately fetched from the backend** (no hard-coded or placeholder counts).

**Reference:** Existing dashboard scaffold — metric strip, quick actions, priority panel (review / alerts / quick links), trend chart, distribution donut (`home_dashboard_profiles.dart`, `dashboard_*` widgets, `backend/src/lib/dashboard/summary.js`).

---

## 1. Metric strip (top summary cards)

Replace the current four visible cards with platform-scoped metrics. Show **four cards** in the existing strip (same card component, same row layout).

| Card | Label | Value format | Source |
|------|-------|--------------|--------|
| **Tenants** | `Tenants` | `{active} / {total}` — e.g. `3 / 5` | Active tenants vs total registered tenants |
| **Facilities** | `Facilities` | `{total}` — total facilities across all tenants | A tenant may own multiple facilities |
| **Subscriptions** | `Subscriptions` | `{active} / {total}` | Active subscriptions vs total subscription records |
| **Entitlements** | `Entitlements` | `{count}` | Tenants with module entitlement issues, or total entitlement gaps (match backend metric) |

**Remove** the **At risk** card from the super-admin profile.

**Optional secondary metric** (only if backend already exposes it; do not add a fifth card): surface **expiring / expired subscriptions** count inside the Subscriptions card subtitle or tooltip — e.g. “2 expiring soon”. Do not expand the layout.

---

## 2. Quick actions (modal dialogs)

Keep up to **four** quick-action buttons in the existing quick-actions row. Each action below must open the **relevant modal dialog** and complete the task in-place (no full-page navigation).

| Action | Behavior |
|--------|----------|
| **Select tenant/facility** | Open tenant/facility context picker dialog |
| **Create tenant** | Open create-tenant dialog |
| **Create facility** | Open create-facility dialog (requires tenant context when applicable) |
| **Fourth action** | Choose one additional platform task completable in a modal — e.g. **Assign subscription plan** or **Invite tenant admin** — only if a dialog already exists; otherwise omit |

**Do not** add page-navigation actions here (e.g. “Manage subscriptions”). Those belong under **Quick links**.

Wire `create_tenant` into `quickActionIds` for `AppRole.superAdmin` if not already active.

---

## 3. Review panel (worklist — currently shows patient admissions)

**Rename / retitle** the queue section to something platform-appropriate, e.g. **Follow-up** or **Subscription renewals**.

**Content:** Tenant-scoped follow-up items for the super admin — **no patient or clinical records**.

Each list item should include:

- Tenant name  
- Subscription status (e.g. `Expired`, `Expiring`, `Lapsed`)  
- Contact details: **email** and **phone** (for outreach)  
- Expiry or lapse date  

**Primary use case:** Subscriptions that have **expired** (or are expiring) and tenants that have **not renewed**, so the platform admin can contact them.

**Empty state:** “No follow-ups required” (or equivalent).

**View all:** Navigate to the subscriptions or tenant-management list filtered to at-risk accounts.

---

## 4. Alerts panel

Show **platform- and tenant-level alerts** relevant to a super admin, for example:

- Subscription payment failures  
- Entitlement / module access violations  
- Tenant onboarding incomplete  
- Integration or API errors (if tracked)  
- Security or compliance items requiring review  

**Do not** show clinical alerts (admissions, lab critical values, etc.).

**Empty state:** Keep “All clear” when no alerts exist.

---

## 5. Quick links (page navigation)

Up to **four** shortcuts in the existing quick-links card. Each opens the **corresponding app screen** (route navigation, not a modal).

| Link | Destination |
|------|-------------|
| **Subscriptions** | Subscriptions workspace |
| **Tenant setup** | Tenant & facility setup |
| **Settings** | Platform / system settings |
| **Reports** | Reports workspace |

Ensure all four appear for `AppRole.superAdmin` via `shortcutIds` in the super-admin dashboard profile.

---

## 6. Charts

### 6a. Trend chart (currently “Platform signal trend”)

Retitle and rebind to **platform revenue / tenant growth** signals. Prefer a **bar or line chart** using the existing chart component — do not change chart dimensions or position.

Suggested series (pick what the backend can supply accurately):

- **New tenants** joined per day/week (current month)  
- **Revenue collected** per period (platform subscription payments)  
- Optionally: count of tenants **without an active subscription**

Choose the most actionable single metric; a combined chart is acceptable if the API returns multiple series.

### 6b. Distribution donut (currently “Tenant mix donut”)

Keep the donut chart. Show **tenant subscription mix**, e.g.:

- Paid / Trial / Expired / None  
- Or plan-tier breakdown (Free, Standard, Enterprise)

Center label: total tenant count. Legend: segment labels with percentages.

---

## 7. Backend requirements

Extend or adjust `super_admin` pack in `backend/src/lib/dashboard/summary.js` (and related repository/service) to return:

```text
metrics:
  tenantsTotal, tenantsActive
  facilitiesTotal
  subscriptionsTotal, subscriptionsActive
  subscriptionsExpiring, subscriptionsExpired   // for review panel & optional subtitle
  moduleEntitlementIssues

reviewQueue: [{ tenantId, tenantName, email, phone, status, expiresAt }]

alerts: [{ id, title, severity, tenantName?, meta }]

trend: [{ date, value }]                        // revenue or new-tenant signups
distribution: { total, segments: [{ label, value }] }  // subscription status mix
```

- Super-admin dashboard queries use **platform scope** — no `tenant_id` required for the home view.  
- Align metric `id` values with `HomeStatusCardTemplate` ids in `home_dashboard_profiles.dart` or update ids in both frontend profile and backend mapping consistently.  
- Add/update tests in `dashboard-workspace` and `dashboard-widget` service tests.

---

## 8. Acceptance criteria

- [ ] Logged in as `super.admin@hosspi.com` (or equivalent `SUPER_ADMIN`), dashboard shows **no patient names, admissions, or clinical worklist items**.  
- [ ] Metric strip shows real **tenant, facility, subscription, and entitlement** counts from the API.  
- [ ] Quick actions open **modals** for select-context, create-tenant, and create-facility.  
- [ ] Review panel lists **expired / non-renewed subscriptions** with tenant contact info.  
- [ ] Alerts reflect **platform/tenant** issues only.  
- [ ] Quick links navigate to Subscriptions, Tenant setup, Settings, and Reports.  
- [ ] Charts display **tenant/subscription** data, not generic flat zeros when seed data exists.  
- [ ] **No layout or styling changes** — only content, labels, bindings, and backend data.  
- [ ] Responsive behavior unchanged on mobile, tablet, and desktop.

---

## Out of scope

- Redesigning dashboard layout or adding/removing dashboard sections  
- Tenant-scoped operational dashboards (those belong to tenant/facility admin roles)  
- New modal implementations unless an existing dialog can be reused
