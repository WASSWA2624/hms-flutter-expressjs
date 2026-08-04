# Tooling Scripts

Place project maintenance scripts here. Scripts should be portable across
Linux and macOS unless a platform-specific filename or README states otherwise.

## Standard commands

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Use `dart run build_runner watch --delete-conflicting-outputs` during model,
provider, or database schema work when continuous generation is useful.

## One-off migration scripts

`migrate_dialog_form_actions.py` migrates in-dialog `AppFormActions` to
`AppDialog.actions` with a fixed footer. It was partially applied (billing,
subscriptions, and radiology); remaining targets still use `AppFormActions`
directly. Run only when continuing that migration—do not re-run on files that
already use `buildAppDialogFormActions`.

Previously applied migrations (icon button consolidation, workspace session
guard, summary notification toolbar, controller lint fixes) have been removed
from this folder.

## Web development

Use the port-specific script when running the Flutter web app locally:

```powershell
.\tool\run_web_5201.ps1
```

On Windows the script defaults to `-d web-server`, binds `--web-hostname=0.0.0.0`
(so phones on the same Wi‑Fi can connect), and opens `http://127.0.0.1:5201/`
in your default browser once the dev server is listening (the first compile can take
1-2 minutes with little terminal output). The terminal also prints a LAN URL such as
`http://192.168.x.x:5201/` for mobile testing. **Phone/tablet browsers need
`-Profile` or `-Release`** (dart2js). A plain debug `web-server` build depends on
DWDS and will show a blank white page on mobile. In development, when the app is
opened from that LAN host, `API_BASE_URL` values that point at
`localhost`/`127.0.0.1` are rewritten to the same host automatically—no separate
env file is required. Pass `-ChromeDebug` when you need Chrome hot reload and the
debugger; the script still retries with a fresh profile and falls back to
web-server if DWDS cannot attach.

The script frees port 5201 first, uses a persistent Chrome profile under
`.dart_tool/flutter_chrome_profile` (avoids Windows DWDS debugger timeouts), and
disables web debugger expression evaluation by default. This avoids DWDS
`WebkitDebugger.enable` startup timeouts on larger debug builds. If expression
evaluation is required for a debugging session, pass `-EnableExpressionEvaluation`.

If Chrome debug still fails after a crash, pass `-ResetChromeProfile` or delete
`.dart_tool/flutter_chrome_profile`. The script also auto-resets profiles larger
than 150 MB, or when a previous run left a `.debug_connection_failed` marker.

On Windows, if DWDS still cannot attach after one automatic profile reset/retry,
the script falls back to `-d web-server` (app runs at `http://127.0.0.1:5201/`
without hot reload; LAN devices can still use the printed Wi‑Fi URL). Pass
`-NoWebServerFallback` to disable that fallback, or
`-WebServerOnly` to skip Chrome debug entirely. Use `-HostName 127.0.0.1` to
disable LAN binding.

## Patrol E2E tests

Run the Patrol smoke suite (Chrome, headless) from `frontend/`:

```powershell
.\tool\run_patrol_tests.ps1
```

Run the full `patrol_test/` directory:

```powershell
.\tool\run_patrol_tests.ps1 -FullSuite
```

Linux/macOS:

```sh
./tool/run_patrol_tests.sh patrol_test/smoke_test.dart
```

See [`patrol_test/README.md`](../patrol_test/README.md) for install notes, failure
report locations, and native platform requirements.
