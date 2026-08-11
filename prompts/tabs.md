# AppTabStrip — underline redesign

## Context

Redesign the shared tab strip so primary desk tabs match the simple underline style used on Reporting and Analytics (`ModuleReportingDomainTabs` / `AppTabStripVariant.nested` in the screenshot: selected tab uses primary-colored icon + label with a solid primary bottom underline; inactive tabs stay muted with no emphasis fill).

Today `AppTabStripVariant.standard` uses flared filled chips that merge into the toolbar. Replace that visual language with the flat underline strip. Keep behavior (selection, counts, icons, tooltips, overflow More menu, optional toolbar) unchanged.

Source of truth for look: Reporting → Reporting / Analytics nested strip. Implementation surface: `frontend/lib/shared/components/app_tab_strip.dart` (and its tests).

## Requirements

1. **Selected tab:** primary-colored label and optional leading icon; solid primary underline under that tab only (thickness consistent with current nested strip / theme border tokens). No flared fill, no tinted chip background for selection.
2. **Unselected tabs:** muted `onSurfaceVariant` (or equivalent) label/icon; no primary underline; light hover only (subtle fill or opacity change—no card chrome).
3. **Baseline:** keep a full-width faint hairline under the whole strip (as today) so inactive tabs still sit on a continuous rule; the selected underline must read clearly on top of / instead of that hairline for the active tab width.
4. **Inter-tab separators:** between every adjacent visible tab, render a **very thin, faint vertical divider** (theme `borders.faint` or lighter). Do not place a separator before the first tab or after the last visible tab. Do not draw a separator beside the overflow More control unless it already sits as a peer of the last tab—prefer no extra chrome around More.
5. **Icons, counts, tooltips:** preserve optional leading icons, count badges + tones, and tooltip behavior. Count badges must remain readable on both selected and unselected tabs.
6. **Toolbar:** when `primaryAction` / `secondaryActions` are present, keep the toolbar row under the strip. Do **not** require the selected tab to share a continuous flared fill with the toolbar; a simple hairline (or existing bottom border) between strip and toolbar is enough.
7. **Overflow:** keep the More menu for tabs that do not fit; selection, counts, and attention indicator behavior stay the same.
8. **Variants:** either (a) make `standard` match this underline look and keep `nested` as a slightly denser twin of the same language, or (b) converge both variants onto one underline implementation with only spacing/type differences. Do not leave `standard` as flared chips. Nested Reporting tabs should still look correct after the change (and should also get the faint vertical separators unless that conflicts with nested density—prefer separators on both).
9. **Responsive / themes:** usable on mobile, tablet, and desktop; light and dark; no clipped labels, underlines, or separators.
10. **Call sites:** no drive-by refactors of feature workspaces. Update only what is required for the shared component (and tests). Existing `AppTabStrip(...)` / `variant: nested` call sites should keep working without per-desk visual rewrites.

## Constraints

- Change visuals in the shared `AppTabStrip` implementation; do not fork a one-off strip per feature.
- Do not remove counts, icons, tooltips, overflow, or the optional toolbar API.
- Do not invent new tab navigation patterns (pills, segmented buttons, cards).
- No unrelated workspace or routing changes.
- Prefer theme tokens (`colorScheme.primary`, `onSurfaceVariant`, `borders.faint`, spacing/radius) over hard-coded colors.

## Acceptance Criteria

- [ ] AC1: Selected tab shows primary-colored text/icon and a solid primary underline under that tab only—no flared fill. (R1)
- [ ] AC2: Unselected tabs are muted and lack the primary underline. (R2)
- [ ] AC3: A faint full-width baseline remains under the strip; selected underline is visually distinct. (R3)
- [ ] AC4: Adjacent visible tabs are separated by a tiny faint vertical line; none before first / after last. (R4)
- [ ] AC5: Icons, count badges/tones, tooltips, overflow More, and optional toolbar still work. (R5–R7)
- [ ] AC6: Reporting / Analytics nested tabs still match the intended underline language (and include separators if applied to nested). (R8)
- [ ] AC7: Light + dark and narrow viewports show no clipping or inaccessible tabs. (R9)
- [ ] AC8: Existing desk call sites compile and render without per-feature strip forks. (R10)

## Verification

- Update / extend `frontend/test/shared/components/app_tab_strip_test.dart` for selection chrome assumptions if any assert on flared fill; add coverage for separators if practical (e.g. widget presence / semantics between tabs).
- Manual: open a multi-tab desk (e.g. Billing or Accounts) and Reporting and Analytics; confirm underline selection, muted inactive tabs, faint vertical separators, counts, overflow More, toolbar actions, light + dark, narrow width.
- Confirm no flared selected tab remains on `standard` strips.

## Relevant Files

- `frontend/lib/shared/components/app_tab_strip.dart`
- `frontend/test/shared/components/app_tab_strip_test.dart`
- `frontend/lib/shared/reporting/module_reporting_domain_tabs.dart` (reference look / nested consumer)
- Call sites using `AppTabStrip` / `AppTabStripVariant` (smoke only; no drive-by edits)

## Visual reference

Reporting and Analytics desk: **Reporting** (selected) = primary icon + label + primary underline; **Analytics** (inactive) = muted icon + label; flat strip with full-width baseline under the row. Target the same language for the shared strip, plus faint vertical separators between tabs.
