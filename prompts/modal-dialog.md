# Prompt — Modal Dialog Chrome: Mobile Dismiss Affordance and Adaptive Footer Actions

## Context

- **Scope:** `modal-dialog` — the shared `AppDialog` shell: header dismiss/maximize chrome and the footer action row. Every surface built on `AppDialog` / `showAppDialog` inherits the change.
- **Surfaces:** all feature dialogs under `frontend/lib/features/**/widgets/*_dialog*.dart` and `frontend/lib/shared/**`, at `xs`/`sm` (phone), `md` (tablet), and `lg`+ (desktop/web).
- **Frontend entry points:** `frontend/lib/shared/components/app_dialog.dart` (`_DialogHeader`, `_DialogActions`), `frontend/lib/shared/components/app_button.dart`, `frontend/lib/shared/components/app_action_label_scope.dart`, `frontend/lib/core/responsive/app_breakpoints.dart`, `frontend/lib/shared/layout/app_toolbar_overflow_resolver.dart`, `frontend/lib/shared/layout/app_toolbar_overflow_section.dart`.
- **Rule sources:** `prompts/.cursor/dialogs.mdc` (owns dialog chrome — **must be updated by this change**, see R5), `prompts/.cursor/responsiveness.mdc`, `prompts/.cursor/theming.mdc`, `prompts/.cursor/localization.mdc`, `frontend/.cursor/accessibility.mdc`, `frontend/.cursor/multi_platform_input.mdc`.

This is a shared-chrome change. It must be made once in `AppDialog` and inherited by every call site — not patched per feature dialog.

## Current Behavior (verified in code)

1. `_DialogHeader` (`app_dialog.dart:618`) renders `[icon] [title (Expanded)] [maximize] [close]`. The dismiss control is `AppButton.close(iconOnly: true, …)` whose glyph is `AppActionIcons.cancel = Icons.close` — a bare **✕ at the trailing top corner on every breakpoint**, including phones. It is wrapped in `AppActionLabelScope(showLabels: false, forceIconOnly: true, dense: true)`, so header chrome is icon-only by construction.
2. The maximize/restore control is already suppressed on compact (`showMaximizeButton && desktopInteractive`, `app_dialog.dart:172`), so on phones the header trailing cluster contains only the ✕.
3. `_DialogActions` (`app_dialog.dart:809`) wraps the footer in `AppActionLabelScope(showLabels: showActionLabels, forceIconOnly: !showActionLabels)` where `showActionLabels = AppBreakpoints.of(context).showsToolbarActionLabels`. Per `app_breakpoints.dart:36` that is **`false` at `xs`, `sm`, and `md`** — so every footer action is icon-only on phones *and tablets*, with the name carried only by tooltip + semantics.
4. `AppButton` (`app_button.dart:197`) falls back to `AppActionIcons.save` for primary actions with no explicit icon under forced icon-only chrome, so an unlabeled primary silently becomes a generic save glyph.
5. The default footer layout is a single right-aligned `Row` inside `FittedBox(fit: BoxFit.scaleDown)` (`app_dialog.dart:857`). With many actions on a narrow viewport this **uniformly shrinks the whole row**, driving tap targets below `theme.appTokens.minInteractiveDimension`. There is no overflow, no truncation, and no notion of action importance.
6. Two-action footers are display-reversed so the dismiss action sits extreme-end (`app_dialog.dart:839`); footers of three or more render in author order.
7. `stackActionsWhenCompact` (default `false`) is the only existing compact escape hatch and stacks **all** actions full-width vertically.
8. A tested, reusable overflow mechanism already exists for toolbars — `AppToolbarOverflowSection`, `resolveToolbarOverflowEntries`, and the eviction loop in `_AdaptiveToolbarLayoutState` (`app_workspace_toolbar.dart:417`). `AppDialog` does not use it.
9. `Escape` and the header close both call `Navigator.of(context).maybePop()` and are gated by `closeEnabled` (`app_dialog.dart:322`, `:729`). Android system back is handled by the enclosing route, not by `AppDialog`.
10. `commonBackActionLabel` ("Back") and `commonCloseActionLabel` ("Close") already exist in `frontend/lib/l10n/app_en.arb`. The toolbar overflow label `workspaceToolbarOverflowLabel` ("More actions") exists but `app_workspace_toolbar.dart:135` and `:574` still hard-code the English string.

## Requirements

### 1. Audit before writing code

- Confirm the compact-breakpoint behavior above by running the existing suite in `frontend/test/shared/components/app_dialog_test.dart` (notably the `two-action footer stays on one row at narrow width` and stacked-footer cases) and by inspecting a real multi-action dialog (e.g. `frontend/lib/features/billing/presentation/widgets/billing_receive_payment_dialog.dart`, `frontend/lib/shared/components/app_role_selection_table_dialog.dart`).
- Inventory footer action counts across `AppDialog` call sites and record the maximum observed, so the priority model in R3 is sized to real usage rather than invented.
- Reuse `AppActionLabelScope`, `AppBreakpoints`, `AppButton`, `AppActionIcons`, and the existing toolbar overflow primitives. **Do not** add a second breakpoint helper, a parallel button component, a new label scope, or a dialog-specific overflow menu when the toolbar one can be extended or shared.
- State the audit outcome in the change description: what already existed, what is extended, and what genuinely did not exist.

### 2. Replace the compact dismiss ✕ with a leading back affordance

- On `isMobile` breakpoints (`xs`, `sm`), the dismiss control becomes a **leading** back control at the header start — a platform-conventional back arrow (`Icons.arrow_back` on Android/Fuchsia/web-on-touch, `Icons.arrow_back_ios_new` on iOS/macOS; resolve via `Theme.of(context).platform`, not `dart:io`). It sits before the header icon and title; the trailing cluster is then empty on compact.
- Keep exactly one dismiss control per dialog. Do not render both a leading back control and a trailing ✕ at any breakpoint.
- On `md` and larger, the header is unchanged: title, then trailing `[maximize/restore] [close ✕]`.
- The back control must be a real button with the app's chrome: `theme.appTokens.minInteractiveDimension` tap target, hover/focus/pressed states, `borderRadius: chromeBorderRadius` honored, and the same `closeEnabled` gating and `Navigator.of(context).maybePop()` behavior as today's close. When `closeEnabled` is false it renders disabled, exactly as the ✕ does now.
- Accessible name, tooltip, and `semanticLabel` come from `commonBackActionLabel` on compact and `MaterialLocalizations.closeButtonTooltip` on `md`+. No hard-coded strings.
- `Escape`, `showCloseButton: false`, and the `closeEnabled` contract are unchanged. Do not alter `AppDialog`'s public API surface for dismissal beyond what R3 requires.
- With a leading back control the title must not shift or clip: keep the title `Expanded` with `maxLines: 2` + ellipsis, and keep `normalizeDialogTitleWidget` / `toDialogTitleUppercase` behavior intact.

### 3. Footer actions on mobile: icon **and** label, with priority-driven overflow

- **Always show icon + label.** Footer actions render labeled at every breakpoint, including `xs`. Remove the `forceIconOnly: !showActionLabels` behavior from `_DialogActions`; icon-only footers are no longer the compact default. Header chrome (R2) is unaffected.
- **Introduce an explicit importance signal** so the shell can decide what stays inline. Add a lightweight, opt-in descriptor — e.g. an `AppDialogAction` wrapper or an inherited priority marker carrying `{primary | secondary | overflow-eligible}` — that call sites may attach to footer widgets. Default when unset: the **primary/confirm action and the dismiss action are always inline**; everything else is overflow-eligible, evaluated in author order.
- **Overflow, do not shrink.** When the labeled inline row cannot fit the available footer width, move the lowest-priority actions into a single trailing "More actions" menu until the row fits, keeping the primary and the dismiss action inline. Reuse `AppToolbarOverflowSection` / `resolveToolbarOverflowEntries` and the measurement approach already proven in `_AdaptiveToolbarLayoutState` rather than writing a second resolver.
- **Remove the `FittedBox(fit: BoxFit.scaleDown)` scaling** from the default footer path. No footer control may render below `theme.appTokens.minInteractiveDimension` at any breakpoint or text scale. If, after moving everything overflow-eligible into the menu, the two mandatory inline actions still do not fit, degrade the *lowest-priority remaining* control to icon-only before ever scaling the row.
- The overflow trigger is icon-only (`AppActionIcons.more`) with tooltip and semantics from a localized "More actions" key. Menu entries show icon + label and preserve each action's enabled/disabled and loading state; a disabled action stays visible and disabled, never hidden.
- **Preserve existing footer semantics:** the two-action reversal at `app_dialog.dart:839`, `denseActions`, `pinActionsToBottom`, the footer's `surfaceContainerLow` fill and top border, and the opt-in `stackActionsWhenCompact` path (which continues to stack all actions full-width and bypasses overflow).
- Remove or narrow the `AppActionIcons.save` fallback in `AppButton._iconForCompactChrome` only if it becomes unreachable for dialog footers; do not change its behavior for toolbars that still force icon-only chrome.

### 4. Localization, theming, accessibility

- New or changed copy goes to `frontend/lib/l10n/app_en.arb` with `@` metadata. Reuse `commonBackActionLabel` and `workspaceToolbarOverflowLabel`; while touching this path, replace the hard-coded `'More actions'` literals at `app_workspace_toolbar.dart:135` and `:574` with the existing localized key.
- Focus order on compact must be: back control → header icon/title → body → footer actions → overflow trigger. `FocusTraversalGroup` and the `closedLoop` traversal in `showAppDialog` stay intact.
- Screen readers announce the compact dismiss control as "Back", the desktop one as "Close", and each overflow entry by its own action name.
- Verify light and dark themes at 320, 360, 390, 600, 840, and 1280 px widths, and at 200% text scale.

### 5. Update the governing rule file

- `prompts/.cursor/dialogs.mdc` §"Footer and chrome" items 2 and 4 currently mandate the behavior this change replaces (icon-only footers on small/medium, icon-only header chrome). Update those items to describe the new contract: labeled footer actions at all breakpoints, priority-driven overflow instead of scaling, leading back affordance on mobile, trailing close + maximize on `md`+.
- Keep the rest of the rule file — titles, nesting, sections, selection lists, maximize defaults — unchanged.

### 6. Verification

- Extend `frontend/test/shared/components/app_dialog_test.dart` with cases for: leading back control present and trailing ✕ absent at 390 px; trailing ✕ present and leading back absent at 1280 px; back control disabled when `closeEnabled: false`; back control pops the route.
- Add footer tests asserting: labels render at 320 and 390 px; a five-action footer keeps primary + dismiss inline and routes the rest to the overflow menu; no footer control measures below `minInteractiveDimension` at 320 px and 200% text scale; the two-action reversal and `stackActionsWhenCompact` behavior are unchanged.
- Confirm no existing `app_dialog_test.dart` case regresses, and run at least one feature-dialog test suite (e.g. `test/shared/components/opd_close_encounter_dialog_test.dart`) to catch call-site fallout.
- Run `flutter analyze` and the focused Flutter tests. Report the actual results, including any pre-existing failures you did not introduce.

## Constraints

- Implement only this scope plus directly required shared support; exclude unrelated refactoring.
- Preserve all behavior not explicitly changed here: maximize/restore, desktop drag and resize, `initialMaximized`, `scrollable`, `pinActionsToBottom`, `contentPadding`, `cornerRadius`, nested-dialog shell keys, `Escape` handling, and focus restoration in `showAppDialog`.
- Do not fork a dialog-specific button, label scope, breakpoint helper, or overflow menu. Extend the shared primitives.
- Do not change `AppDialog`'s constructor defaults in a way that silently alters existing call sites' layout beyond the intended header/footer change.
- Do not solve footer crowding by shrinking controls, wrapping to multiple rows, or hiding actions without an overflow affordance.
- Do not add per-feature overrides to make individual dialogs look right; if a call site needs an exception, express it through the R3 priority descriptor.

## Acceptance Criteria

- **AC1 (R1):** The audit is reported: current compact behavior confirmed, maximum footer action count across call sites recorded, and reused-vs-new components stated.
- **AC2 (R2):** At `xs`/`sm`, every `AppDialog` shows a single platform-conventional back arrow at the header start and no trailing ✕; at `md`+ the header is unchanged (title, maximize/restore, close ✕).
- **AC3 (R2):** The compact back control honors `closeEnabled` and `showCloseButton`, pops via `maybePop()`, meets the minimum tap target, and is announced as "Back" from localized copy.
- **AC4 (R3):** Footer actions render icon **and** label at every breakpoint including 320 px; no footer action is icon-only by default.
- **AC5 (R3):** When labeled actions exceed the footer width, the primary and dismiss actions stay inline and the remainder collapse into one localized "More actions" menu; nothing is scaled down and nothing disappears without an affordance.
- **AC6 (R3):** No footer control renders below `theme.appTokens.minInteractiveDimension` at any tested width or at 200% text scale.
- **AC7 (R3):** Two-action reversal, `denseActions`, `pinActionsToBottom`, and `stackActionsWhenCompact` behave exactly as before.
- **AC8 (R4):** All new copy is localized with metadata, the two hard-coded `'More actions'` literals are replaced, focus order and screen-reader names are correct, and both themes verify at the listed widths.
- **AC9 (R5):** `prompts/.cursor/dialogs.mdc` documents the new chrome contract and no longer mandates icon-only footers.
- **AC10 (R6):** `flutter analyze` and the focused Flutter tests pass with no unrelated regressions, and results are reported as observed.

## Relevant Files

- `frontend/lib/shared/components/app_dialog.dart`
- `frontend/lib/shared/components/app_button.dart`
- `frontend/lib/shared/components/app_action_label_scope.dart`
- `frontend/lib/shared/icons/app_action_icons.dart`
- `frontend/lib/shared/layout/app_dialog_insets.dart`
- `frontend/lib/shared/layout/app_toolbar_overflow_resolver.dart`
- `frontend/lib/shared/layout/app_toolbar_overflow_section.dart`
- `frontend/lib/shared/layout/app_workspace_toolbar.dart`
- `frontend/lib/core/responsive/app_breakpoints.dart`
- `frontend/lib/core/utils/app_dialog_title.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/shared/components/app_dialog_test.dart`
- `frontend/test/shared/components/app_button_test.dart`
- `prompts/.cursor/dialogs.mdc`
