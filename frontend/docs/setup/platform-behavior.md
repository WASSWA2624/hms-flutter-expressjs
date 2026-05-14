# Platform Behavior

This template follows the shared platform rules in:

- [`app-rules/platform_guidelines.md`](../../app-planner/app-rules/platform_guidelines.md)
- [`app-rules/multi_platform_input.md`](../../app-planner/app-rules/multi_platform_input.md)
- [`app-rules/accessibility.md`](../../app-planner/app-rules/accessibility.md)
- [`app-rules/permissions.md`](../../app-planner/app-rules/permissions.md)

## Supported targets

The generated project files support Android, iOS, Web, Windows, macOS, and
Linux. Host toolchains still apply: iOS and macOS require Xcode on macOS,
Windows requires Developer Mode plus the Visual Studio C++ desktop workload,
and Linux requires the Flutter Linux desktop dependencies.

## Safe areas and keyboard insets

Shared screens should use `ResponsivePage` or a component that composes it.
`ResponsivePage` keeps content inside platform safe areas and adds the current
keyboard bottom inset to scrollable page padding. This keeps form controls and
actions reachable when mobile software keyboards are visible.

`Scaffold` still owns route-level app bars, bottom navigation, and default
keyboard resize behavior. Feature screens should avoid hard-coded platform
padding unless they are adapting a platform view at an infrastructure boundary.

## Pointer and keyboard input

Shared controls expose enabled, disabled, loading, focus, and hover states
through Flutter Material widgets. Icon-only actions use `AppIconButton`, which
requires a semantic label and tooltip. Selectable mobile list rows are keyboard
activatable with Enter or Space, and desktop table rows remain selectable with
pointer and keyboard semantics from `DataTable`.

Desktop side navigation rows expose pointer hover, visible keyboard focus, and
Enter/Space activation. Dialogs should be opened through `showAppDialog`. The
helper requests dialog focus, keeps traversal inside the dialog route, and
restores focus to the previous control after the dialog closes.

## Accessibility baseline

- Important icon-only actions must provide localized semantic labels.
- Practical touch targets use the shared `48px` minimum interactive token.
- Loading and error states announce meaningful messages through shared state
  views.
- Important status messages should use text plus an icon, not color alone.
- Form fields should keep labels, helper text, errors, and accessibility labels
  localized.

## Permissions and limitations

App authorization permissions are represented separately from platform runtime
permissions. This template includes typed app permission primitives and route
guard hooks, but it does not request product-specific runtime permissions until
a feature needs one.

Platform limitations to account for in features:

- Web storage is not equivalent to native secure storage for sensitive data.
- Browser shortcuts, tab traversal, and refresh behavior can differ from native
  desktop behavior.
- Mobile software keyboards can reduce usable height; keep form actions inside
  scrollable, keyboard-aware content.
- Native permission wording and permanently denied states vary by platform and
  must be handled in the requesting feature.
