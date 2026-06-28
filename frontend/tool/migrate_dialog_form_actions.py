"""Migrate AppFormActions inside dialog forms to AppDialog.actions with fixed footer."""

from __future__ import annotations

import re
import sys
from pathlib import Path

LIB = Path(__file__).resolve().parents[1] / "lib"

# Files whose AppFormActions are only used inside showAppWorkspaceActionDialog content.
TARGET_FILES = [
    "features/billing/presentation/pages/billing_workspace_page.dart",
    "features/subscriptions/presentation/pages/subscriptions_workspace_page.dart",
    "features/radiology/presentation/pages/radiology_workspace_page.dart",
    "features/theater/presentation/pages/theater_workspace_page.dart",
    "features/operations/presentation/pages/operations_workspace_page.dart",
    "features/discharge/presentation/pages/discharge_workspace_page.dart",
    "features/claims/presentation/pages/claims_workspace_page.dart",
    "features/housekeeping/presentation/pages/housekeeping_workspace_page.dart",
    "features/integrations/presentation/pages/integrations_workspace_page.dart",
    "features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart",
]

APP_FORM_ACTIONS_RE = re.compile(
    r"""
        AppFormActions\s*\(\s*
        cancelLabel:\s*(?P<cancel>[^,]+),\s*
        submitLabel:\s*(?P<submit>[^,]+),\s*
        (?:submitIcon:\s*(?P<icon>[^,]+),\s*)?
        (?:isSubmitting:\s*(?P<submitting>[^,]+),\s*)?
        onCancel:\s*(?P<on_cancel>\(\)\s*=>\s*Navigator\.of\(context\)\.maybePop\(\)),\s*
        onSubmit:\s*(?P<on_submit>\(\)\s*\{[\s\S]*?\})\s*,?\s*
        \)\s*,?
    """,
    re.VERBOSE,
)


def ensure_app_dialog_import(text: str) -> str:
    if "app_dialog.dart" in text or "showAppDialog" in text:
        return text
    # Insert after app_workspace import if present
    marker = "import 'package:hosspi_hms/shared/layout/app_workspace.dart';"
    if marker in text:
        return text.replace(
            marker,
            marker
            + "\nimport 'package:hosspi_hms/shared/components/app_dialog.dart';",
        )
    return text


def migrate_form_actions(text: str) -> tuple[str, int]:
    count = 0

    def replacer(match: re.Match[str]) -> str:
        nonlocal count
        count += 1
        cancel = match.group("cancel").strip()
        submit = match.group("submit").strip()
        icon = match.group("icon")
        submitting = match.group("submitting")
        on_submit_body = match.group("on_submit")

        submitting_expr = submitting.strip() if submitting else "false"
        icon_line = f"\n          leadingIcon: {icon.strip()}," if icon else ""

        # Extract method body from onSubmit: () { ... }
        body = on_submit_body
        if body.startswith("()"):
            body = body[2:].strip()
        if body.startswith("{"):
            body = body[1:]
        if body.endswith("}"):
            body = body[:-1]
        body = body.strip()

        return f"""actions: <Widget>[
        AppButton.tertiary(
          label: {cancel},
          enabled: !({submitting_expr}),
          onPressed: ({submitting_expr})
              ? null
              : () => Navigator.of(context).maybePop(),
        ),
        AppButton.primary(
          label: {submit},{icon_line}
          isLoading: {submitting_expr},
          onPressed: ({submitting_expr}) ? null : () {body},
        ),
      ],"""

    # Only transform AppFormActions blocks – caller wraps AppFormShell separately.
    new_text, n = APP_FORM_ACTIONS_RE.subn(replacer, text)
    return new_text, n


def wrap_app_form_shell_with_dialog(text: str) -> str:
    """Wrap return AppFormShell( ... ) that now has trailing actions: key."""
    pattern = re.compile(
        r"return AppFormShell\(\s*"
        r"formKey:\s*_formKey,\s*"
        r"(?:enabled:\s*![^,]+,\s*)?"
        r"children:\s*<Widget>\[\s*"
        r"(?P<fields>[\s\S]*?)"
        r"\],\s*"
        r"\),\s*"
        r"actions:\s*<Widget>\[\s*"
        r"(?P<actions>[\s\S]*?)"
        r"\],\s*;",
        re.MULTILINE,
    )

    def wrap(match: re.Match[str]) -> str:
        fields = match.group("fields").rstrip()
        actions = match.group("actions").strip()
        enabled_line = ""
        if "_isSubmitting" in actions or "_isSaving" in actions:
            enabled_line = "      enabled: !_isSubmitting,\n"
            if "_isSaving" in actions and "_isSubmitting" not in actions:
                enabled_line = "      enabled: !_isSaving,\n"
        return f"""return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      closeEnabled: !(_isSubmitting || _isSaving),
      content: AppFormShell(
        formKey: _formKey,
{enabled_line}        children: <Widget>[
{fields}
        ],
      ),
      actions: <Widget>[
{actions}
      ],
    );"""

    return pattern.sub(wrap, text)


def add_dialog_fields_to_widget(text: str, class_name: str) -> str:
    """Add dialogTitle and dialogIcon to widget constructor if missing."""
    if f"class {class_name}" not in text:
        return text
    widget_pattern = re.compile(
        rf"(class {re.escape(class_name)} extends StatefulWidget \{{\s*"
        rf"const {re.escape(class_name)}\(\{{)"
        rf"([^}}]*?)"
        rf"(\}}\);)",
        re.DOTALL,
    )
    match = widget_pattern.search(text)
    if not match or "dialogTitle" in match.group(0):
        return text
    prefix, body, suffix = match.group(1), match.group(2), match.group(3)
    addition = (
        "\n    required this.dialogTitle,\n"
        "    required this.dialogIcon,\n"
    )
    fields = (
        "\n\n  final Widget dialogTitle;\n"
        "  final Widget? dialogIcon;"
    )
    replacement = f"{prefix}{addition}{body}{suffix}{fields}"
    return text[: match.start()] + replacement + text[match.end() :]


def migrate_file(rel_path: str) -> int:
    path = LIB / rel_path.replace("/", "\\").replace("\\", "/")
    if not path.exists():
        path = LIB / Path(*rel_path.split("/"))
    text = path.read_text(encoding="utf-8")
    original = text

    text = ensure_app_dialog_import(text)
    text, action_count = migrate_form_actions(text)
    if action_count:
        text = wrap_app_form_shell_with_dialog(text)

    # Fix closeEnabled - simplify double negation patterns
    text = text.replace(
        "closeEnabled: !(_isSubmitting || _isSaving),",
        "closeEnabled: !_isSubmitting && !_isSaving,",
    )

    # Update showAppWorkspaceActionDialog calls that pass content: _XxxForm(
    def update_call(match: re.Match[str]) -> str:
        form = match.group("form")
        title = match.group("title").strip()
        icon = match.group("icon").strip()
        return (
            f"showAppDialog(\n"
            f"    context: context,\n"
            f"    barrierDismissible: false,\n"
            f"    builder: (_) => {form}(\n"
            f"      dialogTitle: {title},\n"
            f"      dialogIcon: {icon},\n"
        )

    call_re = re.compile(
        r"showAppWorkspaceActionDialog\s*\(\s*"
        r"context:\s*context,\s*"
        r"title:\s*(?P<title>[^,]+(?:\([^)]*\)[^,]*)*),\s*"
        r"icon:\s*(?P<icon>[^,]+),\s*"
        r"content:\s*(?P<form>_\w+\([^)]*)\),",
        re.DOTALL,
    )
    text, call_count = call_re.subn(update_call, text)
    # Close builder parens - fix trailing ), to ), ), );
    text = re.sub(
        r"(builder: \(_\) => _\w+\([^)]*dialogIcon: [^,]+,\s*)\),",
        r"\1    ),\n  )",
        text,
    )

    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"Migrated {rel_path}: {action_count} actions, {call_count} calls")
    else:
        print(f"No changes {rel_path}")
    return action_count


def main() -> int:
    total = 0
    for rel in TARGET_FILES:
        total += migrate_file(rel)
    print(f"Total action blocks processed: {total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
