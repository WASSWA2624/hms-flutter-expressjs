# 06 - Startup bootstrap

## Goal
Create a small entry point and predictable startup sequence.

## Applies app rules
- [`startup_flow.md`](../app-rules/startup_flow.md)
- [`state_management.md`](../app-rules/state_management.md)
- [`environment_configuration.md`](../app-rules/environment_configuration.md)
- [`error_handling.md`](../app-rules/error_handling.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Keep `lib/main.dart` limited to calling `bootstrap`.
3. Use `lib/bootstrap.dart` for `WidgetsFlutterBinding.ensureInitialized()`, startup services, and `ProviderScope` setup.
4. Create startup state under `lib/app/startup/` when initialization can fail or take time.
5. Avoid network calls inside widget `build` methods.
6. Show a predictable startup/loading/error state if startup work is asynchronous.

## Expected output
- Small `main.dart`.
- `bootstrap.dart`.
- Startup controller/provider if needed.

## Acceptance criteria
- Cold start is deterministic.
- Startup errors have a safe, localized recovery path.
- App can launch without a real backend.
