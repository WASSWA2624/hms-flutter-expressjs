# Navigation and Routing

## Scope
Defines routing, shell navigation, route guards, deep links, and route naming.

## Mandatory rules
- Use `go_router` as the single navigation package.
- Keep route definitions centralized under `lib/app/router`.
- Use named routes or typed route helpers; do not scatter raw route strings through pages.
- Protect routes through route guards based on session and permissions.
- Keep web URLs readable and stable.
- Support deep-link entry where the app needs it.
- Navigation decisions must not live inside repositories or data sources.
- Unknown routes must show a localized not-found page.
- Use a responsive shell for persistent navigation instead of duplicating route trees for each platform.

## Route structure standard
```txt
lib/app/router/
├── app_router.dart
├── app_routes.dart
├── route_guards.dart
└── route_refresh_listenable.dart
```

## Shell rules
- Use a shell route for apps with persistent navigation.
- Mobile may use bottom navigation or a drawer depending on destination count.
- Tablet may use a navigation rail or compact side navigation.
- Desktop/web must include a menu bar and side navigation when the app has multiple sections.
- Desktop side navigation must support collapsed and expanded states.
- Do not duplicate pages for mobile and desktop routes unless interaction requirements differ.

## Acceptance checklist
- Auth redirect behavior is deterministic.
- Browser refresh on web restores expected route state when possible.
- Protected routes cannot be entered without a valid session.
- Route names are documented and reused consistently.
- Desktop shell includes menu bar, side navigation, and collapsible navigation behavior.

## Related rules
- [`authentication_session.md`](./authentication_session.md)
- [`permissions.md`](./permissions.md)
- [`responsive_adaptive_design.md`](./responsive_adaptive_design.md)
- [`localization_i18n.md`](./localization_i18n.md)
