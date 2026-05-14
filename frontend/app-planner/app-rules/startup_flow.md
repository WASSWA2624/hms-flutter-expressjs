# Startup Flow

## Scope
Defines how the app initializes configuration, storage, session, localization, theme, and the first route.

## Mandatory rules
- Keep `main.dart` small.
- Perform setup through `bootstrap.dart` and startup services.
- Initialize Flutter bindings before platform or storage services.
- Load environment configuration before creating API clients.
- Restore theme and locale preferences before rendering the main app where practical.
- Restore session state before allowing protected-route decisions.
- Show a predictable startup/loading state when initialization is not complete.
- Do not run network calls in widget `build` methods.

## Startup order
1. Initialize bindings.
2. Load environment configuration.
3. Initialize logging.
4. Initialize local storage/database adapters.
5. Initialize secure storage and session manager.
6. Restore theme and locale preferences.
7. Create root `ProviderScope` overrides.
8. Start `App` with router guards.

## Acceptance checklist
- Cold start, warm start, and session-expired start all behave predictably.
- Startup errors are shown with a localized recovery path.
- `main.dart` remains readable and does not contain feature logic.

## Related rules
- [`environment_configuration.md`](./environment_configuration.md)
- [`state_management.md`](./state_management.md)
- [`authentication_session.md`](./authentication_session.md)
- [`error_handling.md`](./error_handling.md)
