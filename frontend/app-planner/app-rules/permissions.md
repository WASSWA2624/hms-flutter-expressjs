# Permissions and Authorization

## Scope
Defines app-level permission checks, platform permissions, and role-based UI behavior.

## Mandatory rules
- Separate platform permissions from app authorization permissions.
- Hide UI actions that the user cannot access, but never rely only on hidden UI for security.
- Protect restricted routes through navigation guards.
- Map forbidden responses to a localized forbidden state or page.
- Request platform permissions only when needed and explain why before or during the request.
- Handle denied and permanently denied platform permission states.

## Implementation standard
- Represent app permissions as typed values, not scattered strings.
- Keep permission checks reusable through providers or guards.
- Backend authorization remains the source of truth for protected resources.

## Acceptance checklist
- Restricted screens and actions behave correctly for allowed and denied users.
- Permission error messages are localized.
- Platform permission flows are testable or documented per platform.

## Related rules
- [`authentication_session.md`](./authentication_session.md)
- [`navigation.md`](./navigation.md)
- [`security.md`](./security.md)
- [`platform_guidelines.md`](./platform_guidelines.md)
