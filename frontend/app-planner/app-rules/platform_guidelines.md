# Platform Guidelines

## Scope
Defines platform behavior for Android, iOS, Web, Windows, macOS, and Linux.

## Mandatory rules
- Keep the starter compatible with all Flutter target families where enabled: Android, iOS, Web, Windows, macOS, and Linux.
- Avoid packages or APIs that break supported platforms unless guarded and documented.
- Use platform checks only at infrastructure boundaries, not throughout feature UI.
- Keep web URLs, browser refresh, keyboard navigation, pointer behavior, and storage limitations in mind.
- Keep desktop resizable windows, menu bars, side navigation, keyboard shortcuts, pointer targets, and hover behavior in mind.
- Keep mobile touch, safe areas, keyboard overlays, back behavior, and orientation behavior in mind.
- Avoid smartwatch-specific requirements.

## Platform notes
| Platform | Required consideration |
|---|---|
| Android | back behavior, permissions, adaptive icons, small screens, keyboard insets |
| iOS | safe areas, lifecycle, permissions, review expectations, keyboard insets |
| Web | readable URLs, refresh behavior, browser storage limits, keyboard/pointer interaction |
| Windows | resizable windows, keyboard navigation, menu bar, pointer/hover states |
| macOS | resizable windows, platform menu expectations, keyboard navigation, pointer/hover states |
| Linux | resizable windows, keyboard navigation, menu bar, pointer/hover states |

## Build-host notes
- iOS and macOS builds require a macOS host with the required Apple tooling.
- Windows builds require a Windows host with desktop build tooling enabled.
- Linux builds require a Linux host with the required Linux desktop packages.
- CI may split platform builds across multiple operating systems.

## Acceptance checklist
- App builds for every enabled platform on a correctly configured host.
- Platform-specific behavior is isolated, documented, and testable where practical.
- UI remains usable with touch, mouse, keyboard, and screen readers.

## Related rules
- [`responsive_adaptive_design.md`](./responsive_adaptive_design.md)
- [`multi_platform_input.md`](./multi_platform_input.md)
- [`permissions.md`](./permissions.md)
- [`ci_cd_quality_gates.md`](./ci_cd_quality_gates.md)
