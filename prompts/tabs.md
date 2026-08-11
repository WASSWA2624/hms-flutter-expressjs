# Tabs — Flush desk chrome (remove top spacing)

## Context

Across HMS workspace / registry screens that use `AppTabStrip`, the tab row must sit **flush under the app bar** with **no extra top padding or margin**. Tabs are the first content in that body region — not inset below empty space.

Chosen visual direction: flared desk chrome (`tab-designs/01-flared-desk-chrome.png`) — compact padding, `⋮` overflow when tabs do not fit. This prompt is specifically about **vertical flushness above the strip**, not redesigning tab visuals.

**Reference (correct):** Reporting & analytics and Facility setup already sit flush (they use `AppWorkspace` compact horizontal-only padding). Match that behavior on the desks listed below.

Source of truth for layout: `AppWorkspace` / `_compactWorkspacePagePadding` in `app_workspace.dart`, and `ResponsiveSpacing.pagePaddingFor` (default vertical `lg` is the usual culprit).

## Requirements

1. On every listed screen, remove extra spacing **above** `AppTabStrip` (or equivalent primary desk tabs). The strip must be the topmost content child in the page body.
2. Do **not** remove useful spacing **below** the strip (e.g. small gap before the table/panel is fine).
3. Prefer the shared fix: route desk bodies through `AppWorkspace` (or reuse the same compact page padding as `_compactWorkspacePagePadding` — horizontal only). Do not invent a second padding system.
4. If a page uses bare `ResponsivePage` without a padding override, either:
   - migrate to `AppWorkspace` with `scrollable: false` where appropriate, **or**
   - set explicit horizontal-only padding equivalent to the workspace compact padding.
5. Keep flared `AppTabStrip` behavior (toolbar merge, overflow `more_vert`) unchanged except where density already landed.
6. Touch only pages that currently show excess top inset; leave non-tab pages that need default vertical page padding alone.
7. Preserve light/dark themes and mobile / tablet / desktop layouts — no clipped tabs or inaccessible overflow.

## Screens in scope (fix — excess top space)

| Area | Feature folder / page (typical) |
|------|----------------------------------|
| Reception | `reception` workspace |
| Patient registry / Patients | `patients` registry |
| Outpatient (OPD) | `opd` workspace |
| Nursing | `nursing` workspace |
| Clinical | `clinical` workspace |
| Operating theater | `theater` workspace |
| Discharge / Discharge planning | `discharge` workspace |
| Laboratory | `lab` workspace |
| Radiology | `radiology` workspace |
| Pharmacy | `pharmacy` workspace |
| Billing | `billing` workspace |
| Accounts | `accounts` workspace |
| Insurance / Claims | `claims` workspace |
| Human resources | `hr` workspace |
| Settings | `settings` page |

Also sweep any sibling desk that uses the same bare-`ResponsivePage` + `AppTabStrip` pattern (e.g. ICU, Emergency, Operations) if they share the top inset — only if they exhibit the same gap.

## Screens out of scope (already OK)

- Reporting & analytics (`reports`)
- Facility setup (`tenant_facility`)

Do not regress these.

## Constraints

- Do not redesign tab shapes, colors, or badges in this pass.
- Do not remove side inset entirely unless matching the compact workspace horizontal padding.
- Do not add top padding back “for breathing room” under the app bar on tab desks.
- No unrelated refactors outside tab-hosting page shells.
- Prefer exporting/reusing one shared compact padding helper over copy-paste `EdgeInsets` on every page.

## Acceptance Criteria

- [ ] AC1: On each in-scope screen, there is no visible empty band between the app bar / page chrome and `AppTabStrip`.
- [ ] AC2: Reporting and Facility setup remain flush (no regression).
- [ ] AC3: Spacing below the strip (to table/panels) remains intentional and usable.
- [ ] AC4: Fix uses shared `AppWorkspace` compact padding or an equivalent shared helper — not one-off magic numbers per module.
- [ ] AC5: Light + dark, narrow and wide viewports: tabs and overflow menu remain usable.
- [ ] AC6: Non-tab pages that rely on default `ResponsivePage` vertical padding are unchanged.

## Verification

- Manual: open each in-scope desk and confirm tabs sit flush under the header; compare side-by-side with Reporting / Facility setup.
- Spot-check Billing, Accounts, Patients, Settings, OPD.
- Widget/layout tests only if the repo already asserts workspace padding; otherwise manual + screenshot is enough for this chrome pass.
- Confirm no new top `SizedBox` / `Padding` was introduced above `AppTabStrip`.

## Relevant Files

- `tab-designs/01-flared-desk-chrome.png`
- `tab-designs/README.md`
- `frontend/lib/shared/layout/app_workspace.dart` (`_compactWorkspacePagePadding`)
- `frontend/lib/shared/layout/responsive_spacing.dart` (`pagePaddingFor`)
- `frontend/lib/shared/components/app_tab_strip.dart`
- Workspace / registry pages under `frontend/lib/features/*/presentation/pages/` listed in the scope table
- Good references: `reports_workspace_page.dart`, `tenant_facility_setup_page.dart`
