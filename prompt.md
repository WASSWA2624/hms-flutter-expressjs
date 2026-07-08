# Role-Personalized Home Dashboard Refinement

## Objective

Redesign the HMS **Home** dashboard so each account type sees **only what they need to act on today**—nothing more. The result must be **visual-first, scannable, and elegant**: a user should grasp their priorities in one glance from layout, icons, numbers, and color—not from reading copy.

## Design principles

1. **Text is a last resort** — Prefer icons, KPI values, badges, color, and spatial hierarchy over labels and descriptions. If something can be communicated without words, remove the words.
2. **No hero subtitle** — Remove the `homeSubtitle` field and the hero/subtitle strip entirely. Do not replace it with shorter copy elsewhere.
3. **Role-first, not one-size-fits-all** — Content, layout density, and section order vary by role tier (see below). Shared visual language only; not shared content blocks.
4. **Action-oriented** — Primary queue or KPIs lead; charts, activity feeds, and shortcut grids are secondary or omitted when they add noise.
5. **Consistent shell** — Same typography, spacing, card style, and responsive breakpoints across roles. Personalization is *what* appears, not *how* it looks.
6. **Responsive** — Mobile, tablet, and desktop layouts must remain usable without relying on hidden explanatory text.

## Text minimization rules

Apply everywhere on home (profiles, widgets, fallbacks, empty states):

| Keep | Remove or avoid |
|------|-----------------|
| Role title (short, e.g. “Clinical worklist”) | `homeSubtitle` and any descriptive paragraph under the header |
| KPI labels (1–3 words) | Section intros, helper paragraphs, disclaimer banners |
| Action button labels | Redundant section headings when layout is self-evident |
| Critical alert text (severity + count) | Chart subtitles/descriptions when the chart is self-explanatory |
| Queue item primary identifier | “Recent activity” narrative rows when a timestamp + icon suffices |
| | Fallback copy like “Profile shortcuts until live dashboard data is available” |
| | Duplicate nav labels (same destination in quick actions, shortcuts, and queue) |

**Default:** When adding or keeping UI copy, ask: *Can this be an icon, number, or color instead?* If yes, remove the text.

## Role tiers and layout strategy

| Tier | Roles | Home layout priority |
|------|-------|----------------------|
| **Platform** | Super admin | Tenant/facility context picker; risk KPIs (subscriptions, entitlements, integrations). No clinical charts. |
| **Organization** | Tenant admin | Org health KPIs (facilities, adoption, revenue, staffing exceptions). Minimal queues. |
| **Facility command** | Facility admin, operations | Today’s flow, beds, blockers, billing exceptions. Short action row. |
| **Clinical queue** | Doctor, nurse, ward/ICU/unit managers | Worklist + critical alerts first; 1–2 primary actions (e.g. start consult, record vitals). Drop generic charts when queue is empty. |
| **Department queue** | Lab, pharmacy, reception, billing, biomed, ambulance | Pending/critical queue + top KPIs + one primary CTA. No activity feed or duplicate shortcuts. |
| **Task-first staff** | Housekeeping, mortuary staff | Assigned tasks only; start/complete actions. No charts or shortcut grid. |
| **Workforce** | HR | KPI-first modal pattern; pending leaves and unassigned shifts above the fold. |
| **Patient** | Patient portal | Next appointment, open bills, messages; single “view care” path. |

**Multi-role users:** Resolve primary profile by highest role rank; merge actions only when they do not duplicate the same route.

## Scope (codebase)

- **Remove subtitle from profiles:** `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`
- **Remove subtitle from domain model:** `frontend/lib/features/home/domain/entities/home_dashboard.dart` (`homeSubtitle` field)
- **Remove or gut hero panel:** `frontend/lib/features/home/presentation/widgets/home_hero_panel.dart` — delete subtitle rendering; remove widget usage if nothing remains except redundant text
- **Page layout:** `frontend/lib/features/home/presentation/pages/home_page.dart` — drop `HomeHeroPanel` subtitle wiring; trim section headings and chart/activity descriptions
- **Fallback content:** `frontend/lib/features/home/domain/entities/home_dashboard_guided_content.dart` — icon/badge-only empty states where possible
- **DTO mapping:** `frontend/lib/features/home/data/dtos/home_dashboard_dtos.dart` — stop mapping unused subtitle fields if removed end-to-end
- **HR metric behavior:** `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart`
- **Roles:** `frontend/lib/core/permissions/access_policy.dart`

Do not conflate this with module workspace pages (`*_workspace_page.dart`) or the Reports dashboard system.

## Required changes

### Remove text / subtitle layer
- [ ] **Delete `homeSubtitle`** from `HomeDashboardProfile`, all profile entries, and any API/DTO mapping that feeds it.
- [ ] **Remove `HomeHeroPanel` subtitle UI** (and the panel itself if it only existed to show subtitle/context copy).
- [ ] **Remove disclaimer and fallback banner text**; use empty states with icon + optional single-word status (e.g. “Offline”) only when necessary.
- [ ] **Strip chart subtitles/descriptions** unless required for accessibility (`Semantics` / `tooltip` is acceptable; visible paragraph copy is not).
- [ ] **Collapse or remove section headings** (“Quick actions”, “Shortcuts”, “Recent activity”) where the section type is obvious from layout.
- [ ] **Localize only strings that remain** via existing l10n/arb patterns.

### Content & structure
- [ ] Remove or collapse sections that repeat the same destination (quick actions vs shortcuts vs queue rows).
- [ ] Per role tier, **hide or defer** low-value sections: trend/distribution charts for frontline staff; recent activity when queue is populated; full shortcut grid when ≤3 actions suffice.

### Layout
- [ ] Implement **tier-based section order** (e.g. task-first roles: queue → KPIs → actions; admin roles: KPIs → alerts → actions).
- [ ] Header = **role title + icon only** (plus tenant/facility context controls where needed—controls, not prose).
- [ ] Cap visible KPIs: **4** for frontline roles, **6** for facility/admin, **8** only for HR.
- [ ] Ensure super admin without tenant context keeps tenant picker as the sole focus.

### Quality bar
- [ ] No visible `homeSubtitle` or equivalent descriptive strip on any role or breakpoint.
- [ ] Each test account’s home screen is understandable **without reading explanatory paragraphs**.
- [ ] No role sees three navigation paths to the same module on home.
- [ ] UI remains uniform across roles (cards, buttons, spacing).

## Out of scope

- Backend API schema changes (ignore or gracefully drop unused `subtitle` fields from API responses).
- New module workspace features.
- Reports dashboard redesign.

## Verification

Sign in with each account below (shared password). Confirm home has **no subtitle/hero copy**, minimal labels, and role-appropriate layout at mobile / tablet / desktop widths.

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

The home dashboard is **predominantly non-textual**: no `homeSubtitle`, no descriptive hero strip, no disclaimer banners. Users infer priorities from metrics, queues, icons, and actions alone. Remaining copy is the minimum needed for accessibility and primary CTAs—and nothing more.
