# 03 - Brand, App Identity, and Shell

## Goal
Convert the Flutter starter identity into **HOSSPI HMS** without rebuilding the existing shell foundation.

## Current State
- The frontend shell, responsive scaffold, router, theme, app logo component, and settings page already exist.
- The starter app still uses template-oriented naming in places such as `pubspec.yaml`, localization labels, and home starter copy.

## Scope
Implement app identity in this order:
1. Set product label to **HOSSPI HMS**.
2. Set full name to **HOSSPI Hospital Management System**.
3. Replace starter home text with HMS-specific overview and entry points.
4. Add or wire the official app logo using the existing asset and logo rules.
5. Keep the existing responsive shell behavior.
6. Customize the app bar for HMS needs: logged-in avatar, user dropdown, notification badge, online/offline status, and in-app notification indicators.
7. Keep mobile, tablet, desktop, and web behavior consistent.

## Frontend Anchors
- `frontend/pubspec.yaml`
- `frontend/lib/l10n/app_en.arb`
- `frontend/lib/shared/components/app_logo.dart`
- `frontend/lib/shared/layout/responsive_shell_scaffold.dart`
- `frontend/lib/app/router/app_router.dart`
- `frontend/lib/features/home/`

## Implementation Notes
- Do not hard-code user-facing text in widgets; update localization keys.
- Do not create a second shell. Extend the existing `ResponsiveAppShell` pattern.
- Keep app bar controls compact and clear.
- User menu actions should include profile, settings, change password, and logout after auth is implemented.
- Notification indicators should be wired after notification data access is available.

## Done Criteria
- App title and short title display as HOSSPI HMS.
- Home screen no longer reads like a generic starter template.
- Shell remains responsive and accessible.
- Brand assets are loaded from the correct asset folders.
- No unrelated source files are changed.

## Rule References
### Frontend rules
- `frontend/app-planner/app-rules/assets_branding.md`
- `frontend/app-planner/app-rules/theming.md`
- `frontend/app-planner/app-rules/localization_i18n.md`
- `frontend/app-planner/app-rules/responsive_adaptive_design.md`
- `frontend/app-planner/app-rules/navigation.md`
- `frontend/app-planner/app-rules/accessibility.md`
### Backend rules
- `backend/app-planner/app-rules/documentation.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
