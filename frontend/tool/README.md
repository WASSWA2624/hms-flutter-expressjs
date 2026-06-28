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

The script frees port 5201 first and disables web debugger expression
evaluation by default. This avoids DWDS `WebkitDebugger.enable` startup
timeouts on larger debug builds. If expression evaluation is required for a
debugging session, pass `-EnableExpressionEvaluation`.
