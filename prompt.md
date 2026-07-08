# Role-Personalized Home Dashboard Refinement

## Objective

Redesign the HMS **Home** dashboard so each account type sees **only what they need to act on today**—nothing more. The result must be **simple, scannable, and elegant**: a user should grasp their priorities in one glance, without reading paragraphs or hunting through redundant controls.

## Design principles

1. **Role-first, not one-size-fits-all** — Content, layout density, and section order vary by role tier (see below). Shared visual language only; not shared content blocks.
2. **Glanceable** — One-line context max. No long subtitles, disclaimers, or duplicate navigation paths on the home screen.
3. **Action-oriented** — Primary queue or KPIs lead; charts, activity feeds, and shortcut grids are secondary or omitted when they add noise.
4. **Consistent shell** — Same typography, spacing, card style, and responsive breakpoints across roles. Personalization is *what* appears, not *how* it looks.
5. **Responsive** — Mobile, tablet, and desktop layouts must remain usable. Do not hide essential context on small screens (current hero strip behavior is unacceptable).

## Role tiers and layout strategy

| Tier | Roles | Home layout priority |
|------|-------|----------------------|
| **Platform** | Super admin | Tenant/facility context picker; risk KPIs (subscriptions, entitlements, integrations). No clinical charts. |
| **Organization** | Tenant admin | Org health KPIs (facilities, adoption, revenue, staffing exceptions). Minimal queues. |
| **Facility command** | Facility admin, operations | Today’s flow, beds, blockers, billing exceptions. Short action row. |
| **Clinical queue** | Doctor, nurse, ward/ICU/unit managers | Worklist + critical alerts first; 1–2 primary actions (e.g. start consult, record vitals). Drop generic charts when queue is empty. |
| **Department queue** | Lab, pharmacy, reception, billing, biomed, ambulance | Pending/critical queue + top KPIs + one primary CTA. No activity feed or duplicate shortcuts. |
| **Task-first staff** | Housekeeping, mortuary staff | Assigned tasks only; start/complete actions. No charts or shortcut grid. |
| **Workforce** | HR | Keep KPI-first modal pattern; pending leaves and unassigned shifts above the fold. |
| **Patient** | Patient portal | Next appointment, open bills, messages; single “view care” path. |

**Multi-role users:** Resolve primary profile by highest role rank; merge actions only when they do not duplicate the same route.

## Scope (codebase)

- **Profiles & copy:** `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`
- **Page layout & gating:** `frontend/lib/features/home/presentation/pages/home_page.dart`
- **Hero/context strip:** `frontend/lib/features/home/presentation/widgets/home_hero_panel.dart`
- **Fallback content:** `frontend/lib/features/home/domain/entities/home_dashboard_guided_content.dart`
- **HR metric behavior:** `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart`
- **Roles:** `frontend/lib/core/permissions/access_policy.dart`

Do not conflate this with module workspace pages (`*_workspace_page.dart`) or the Reports dashboard system.

## Required changes

### Content
- [ ] Shorten every profile `homeSubtitle` to **one line** (≤ ~80 characters). Move detail to tooltips or empty states.
- [ ] Remove or collapse sections that repeat the same destination (quick actions vs shortcuts vs queue rows).
- [ ] Per role tier, **hide or defer** low-value sections: trend/distribution charts for frontline staff; recent activity when queue is populated; full shortcut grid when ≤3 actions suffice.
- [ ] Replace fallback disclaimer text with subtle empty-state UI, not banner copy.
- [ ] Localize new/changed strings via existing l10n/arb patterns.

### Layout
- [ ] Implement **tier-based section order** (e.g. task-first roles: queue → KPIs → actions; admin roles: KPIs → alerts → actions).
- [ ] Show a **compact mobile hero** (title + one-line context) on all breakpoints.
- [ ] Cap visible KPIs: **4** for frontline roles, **6** for facility/admin, **8** only for HR.
- [ ] Ensure super admin without tenant context keeps tenant picker as the sole focus.

### Quality bar
- [ ] Each listed test account, after login, shows a dashboard where the **top visible content matches that role’s daily job** (see tier table).
- [ ] No role sees three navigation paths to the same module on home.
- [ ] UI remains uniform across roles (cards, buttons, spacing).

## Out of scope

- Backend API schema changes (use existing `GET /dashboard-workspace/workspace` merge behavior).
- New module workspace features.
- Reports dashboard redesign.

## Verification

Sign in with each account below (shared password). Confirm home screen is simple, role-appropriate, and responsive at mobile / tablet / desktop widths.

| Role | Email |
|------|-------|
| Super admin | super.admin@hosspi.com |
| Tenant admin | tenant.admin@hosspi.com |
| Facility admin | facility.admin@hosspi.com |
| Doctor | doctor@hosspi.com |
| Nurse | nurse@hosspi.com |
| Lab | lab@hosspi.com |
| Pharmacy | pharmacy@hosspi.com |
| Reception | reception@hosspi.com |
| Billing | billing@hosspi.com |
| Operations | operations@hosspi.com |
| HR | hr@hosspi.com |
| Biomed | biomed@hosspi.com |
| Housekeeping | housekeeping@hosspi.com |
| Ambulance | ambulance@hosspi.com |
| Patient portal | patient.portal@hosspi.com |

**Password:** `Hosspi@2624`

## Definition of done

The home dashboard feels **calm and obvious** for every role: the right work is visible immediately, text is minimal, navigation is not duplicated, and the layout adapts cleanly across screen sizes without hiding critical context.
