"""Generate per-dialog standardization prompts for patient-encounter inventory."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INVENTORY = ROOT / "dialog-inventory" / "02-patient-encounter-flow.md"
PROMPTS = ROOT / "prompts"
CONTRACT = "prompt.md"
SYNC_RULE = "frontend/.cursor/instant_ui_sync.mdc"
PATTERN_TEST = "frontend/test/shared/layout/workspace_ui_pattern_test.dart"

SHELL_REFS = {
    "AppDialog": "frontend/lib/shared/components/app_dialog.dart",
    "AppButton": "frontend/lib/shared/components/app_button.dart",
    "AppActionIcons": "frontend/lib/shared/icons/app_action_icons.dart",
    "AppLoadingIndicator": "frontend/lib/shared/components/app_loading_indicator.dart",
    "toDialogTitleUppercase": "frontend/lib/core/utils/app_dialog_title.dart",
}

SHARED_REUSE = [
    ("Patient chrome", "`AppPatientDetails` / `AppPatientDetailDialog`"),
    (
        "Encounter / flow hubs",
        "`OpdEncounterDialog`, `FlowActionsDialog`, OPD appointment/stage dialogs under `shared/opd_actions/`",
    ),
    (
        "Triage / vitals",
        "`AppTriageActionDialog`, `RecordVitalsDialog` / `app_record_vitals_dialog`, `AppVitalsForm`",
    ),
    (
        "Status / forms / layout",
        "`AppStatusBadge`, shared form fields, `showAppWorkspaceMutationDialog`, confirm helpers",
    ),
]


def slugify(symbol: str, module: str | None = None) -> str:
    s = symbol.lstrip("_")
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", s)
    s = s.replace("_", "-").lower()
    s = re.sub(r"[^a-z0-9-]+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    if module and module not in {"shared", "shared/opd_actions", "shared/components", "shared/patient_actions"}:
        mod = module.replace("/", "-").replace("_", "-")
        # Disambiguate when the same class name exists in multiple features.
        if not s.startswith(mod):
            s = f"{mod}-{s}"
    return s


def parse_inventory() -> list[dict]:
    rows: list[dict] = []
    for line in INVENTORY.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| `"):
            continue
        parts = [p.strip() for p in line.strip().strip("|").split("|")]
        if len(parts) < 7:
            continue
        symbol = parts[0].strip("`")
        purpose = parts[1]
        defined = parts[2]
        kind = parts[3]
        extends = parts[4]
        openers = parts[5]
        used = parts[6]
        # Strip markdown backticks / <br>
        defined_clean = defined.replace("`", "").replace("<br>", "\n")
        m = re.search(r"([^\s:]+\.dart):(\d+)", defined_clean)
        path = m.group(1) if m else None
        line_no = int(m.group(2)) if m else None
        used_sites = [
            u.strip().replace("`", "")
            for u in re.split(r"<br\s*/?>|\n", used)
            if u.strip() and u.strip() != "-"
        ]
        opener_list = [
            o.strip().replace("`", "")
            for o in re.split(r",|\s+", openers)
            if o.strip() and o.strip() != "-"
        ]
        rows.append(
            {
                "symbol": symbol,
                "purpose": purpose,
                "path": path,
                "line": line_no,
                "kind": kind,
                "extends": extends,
                "openers": opener_list,
                "used": used_sites,
            }
        )
    return rows


def peek_dialog_context(path: str | None, symbol: str, line_no: int | None) -> dict:
    """Lightweight source peek for titles, AppDialog usage, and buttons."""
    info = {
        "uses_app_dialog": False,
        "uses_show_app_dialog": False,
        "uses_raw_show_dialog": False,
        "uses_alert_dialog": False,
        "title_snippets": [],
        "button_snippets": [],
        "close_enabled_false": False,
        "barrier_false": False,
        "is_loading": False,
        "nearby_excerpt": "",
    }
    if not path:
        return info
    file_path = ROOT / path.replace("\\", "/")
    if not file_path.exists():
        return info
    text = file_path.read_text(encoding="utf-8")
    # Find symbol region: from definition to next top-level class/function or +250 lines
    start = None
    patterns = [
        rf"(?:class|mixin)\s+{re.escape(symbol)}\b",
        rf"(?:Future<[^>]*>\s+|void\s+|Widget\s+)?{re.escape(symbol)}\s*\(",
    ]
    for pat in patterns:
        m = re.search(pat, text)
        if m:
            start = m.start()
            break
    if start is None and line_no:
        # Approximate from line number
        lines = text.splitlines(keepends=True)
        idx = max(0, line_no - 1)
        start = sum(len(l) for l in lines[:idx])
    if start is None:
        region = text
    else:
        tail = text[start:]
        # Include paired State class for StatefulWidget symbols.
        state_name = None
        if re.match(rf"class\s+{re.escape(symbol)}\b", tail):
            state_name = f"_{symbol}State" if not symbol.startswith("_") else f"{symbol}State"
            # Also common: class Foo extends StatefulWidget -> _FooState
            alt = re.search(
                rf"createState\(\)\s*(?:=>|\{{)\s*{re.escape(symbol)}?.*?(\w+State)\s*\(",
                tail[:800],
                re.S,
            )
            # Prefer explicit State class search
            state_m = re.search(
                rf"\nclass\s+(_?{re.escape(symbol.lstrip('_'))}State)\b",
                tail,
            )
            if state_m:
                state_name = state_m.group(1)

        # Walk top-level classes; keep this symbol + its State.
        positions = [m.start() for m in re.finditer(r"(?m)^(?:class |mixin )", tail)]
        end = min(len(tail), 40000)
        if positions:
            # positions[0] is usually 0 (this class). Find first class after
            # symbol+state that is unrelated.
            kept_state = False
            for pos in positions[1:]:
                header = tail[pos : pos + 120]
                hm = re.match(r"(?:class |mixin )(\w+)", header)
                name = hm.group(1) if hm else ""
                if state_name and name == state_name and not kept_state:
                    kept_state = True
                    continue
                # Stop at next unrelated type
                end = min(pos, 40000)
                break
        region = tail[:end]
    info["nearby_excerpt"] = region[:4000]
    scan = region
    info["uses_app_dialog"] = "AppDialog(" in scan
    info["uses_show_app_dialog"] = (
        "showAppDialog(" in scan
        or "showAppWorkspaceMutationDialog(" in scan
        or "showAppWorkspaceActionDialog(" in scan
        or "AppConfirmActionDialog" in scan
        or "showAppConfirm" in scan
    )
    info["uses_raw_show_dialog"] = bool(
        re.search(r"(?<![A-Za-z])showDialog\s*\(", scan)
    )
    info["uses_alert_dialog"] = "AlertDialog(" in scan
    info["close_enabled_false"] = "closeEnabled: false" in scan
    info["barrier_false"] = "barrierDismissible: false" in scan
    info["is_loading"] = (
        "isLoading:" in scan
        or "AppLoadingIndicator" in scan
        or "AppLoadingSurface" in scan
    )

    for m in re.finditer(
        r"title:\s*(?:const\s+)?Text\(\s*([^,\n)]+)", scan
    ):
        snippet = m.group(1).strip()[:80]
        if snippet not in info["title_snippets"]:
            info["title_snippets"].append(snippet)
        if len(info["title_snippets"]) >= 6:
            break
    for m in re.finditer(
        r"AppButton\.(primary|secondary|tertiary)\s*\(", scan
    ):
        info["button_snippets"].append(m.group(1))
        if len(info["button_snippets"]) >= 12:
            break
    return info


def human_title(symbol: str, purpose: str) -> str:
    # Prefer purpose short label after colon if present
    if ":" in purpose:
        short = purpose.split(":", 1)[1].strip()
        # Drop trailing parenthetical module
        short = re.sub(r"\s*\([^)]*\)\s*$", "", short)
        if short:
            return short
    # Fallback from symbol
    name = symbol.lstrip("_")
    name = re.sub(r"(Dialog|show)$", "", name, flags=re.I)
    name = re.sub(r"([a-z])([A-Z])", r"\1 \2", name)
    return name.strip() or symbol


def module_hint(path: str | None) -> str:
    if not path:
        return "shared"
    m = re.search(r"features/([^/]+)/", path.replace("\\", "/"))
    if m:
        return m.group(1)
    if "shared/opd_actions" in path:
        return "shared/opd_actions"
    if "shared/patient_actions" in path:
        return "shared/patient_actions"
    if "shared/components" in path:
        return "shared/components"
    return "shared"


def gap_notes(peek: dict) -> list[str]:
    gaps = []
    if peek["uses_alert_dialog"] or peek["uses_raw_show_dialog"]:
        gaps.append(
            "Raw Material dialog API detected in the symbol region - migrate to `AppDialog` / `showAppDialog` (or approved workspace helpers)."
        )
    if not peek["uses_app_dialog"] and not peek["uses_show_app_dialog"]:
        gaps.append(
            "No clear `AppDialog` / `showAppDialog` usage found near the symbol - verify the shell and migrate if needed."
        )
    if peek["button_snippets"]:
        order = peek["button_snippets"]
        if "primary" in order and "tertiary" in order:
            # Check if tertiary appears before primary (good: Cancel then primary)
            try:
                ti = order.index("tertiary")
                pi = order.index("primary")
                if pi < ti:
                    gaps.append(
                        "Footer button order may place primary before Cancel - §1 requires Cancel left of the committing primary (or Cancel rightmost only when reading left->right with primary immediately left of Cancel per helpers)."
                    )
            except ValueError:
                pass
    if not peek["barrier_false"]:
        gaps.append(
            "Confirm mutating openers set `barrierDismissible: false` while submit is in flight / for mutating dialogs."
        )
    if not peek["close_enabled_false"] and peek["is_loading"]:
        gaps.append(
            "Loading path exists - ensure `closeEnabled: false` and disabled Cancel while mutation/load is in flight."
        )
    if not peek["is_loading"]:
        gaps.append(
            "No obvious loading primitive (`isLoading` / `AppLoadingIndicator`) near the symbol - add shared loading UX for async open/submit."
        )
    return gaps


def build_prompt(idx: int, row: dict, peek: dict) -> str:
    symbol = row["symbol"]
    purpose = row["purpose"]
    path = row["path"] or "(unknown)"
    line = row["line"] or "?"
    kind = row["kind"]
    extends = row["extends"]
    openers = row["openers"]
    used = row["used"]
    title = human_title(symbol, purpose)
    module = module_hint(row["path"])
    slug = slugify(symbol, module)
    gaps = gap_notes(peek)

    defined_loc = f"`{path}:{line}`"
    opener_md = (
        ", ".join(f"`{o}`" for o in openers) if openers else "_none listed - discover call sites_"
    )
    used_md = (
        "\n".join(f"- `{u}`" for u in used)
        if used
        else "- _Inventory lists no *Used from* sites - keep existing private openers reachable._"
    )
    title_snip = (
        ", ".join(f"`{t}`" for t in peek["title_snippets"][:4])
        if peek["title_snippets"]
        else "_not detected in peek - inspect source_"
    )
    buttons = (
        " -> ".join(peek["button_snippets"][:8])
        if peek["button_snippets"]
        else "_not detected - inspect `AppDialog.actions`_"
    )
    gap_md = (
        "\n".join(f"- {g}" for g in gaps)
        if gaps
        else "- Peek did not flag obvious gaps; still run the full acceptance checklist - peeks are heuristic."
    )
    reuse_md = "\n".join(f"- **{k}:** {v}" for k, v in SHARED_REUSE)

    return f"""# Standardize `{symbol}` - {title}

## Objective

Refactor **`{symbol}`** ({purpose}) so it fully complies with [`{CONTRACT}`](../{CONTRACT}) - the patient-encounter dialog standardization contract. After this prompt, the dialog must feel like the same product surface as the rest of the inventory in [`dialog-inventory/02-patient-encounter-flow.md`](../dialog-inventory/02-patient-encounter-flow.md), with UI state and backend persistence staying in sync per [`{SYNC_RULE}`](../{SYNC_RULE}).

## Compliance checklist (from `{CONTRACT}` - this dialog only)

- [ ] Opens only through `AppDialog` / `showAppDialog` / approved helpers (`showAppWorkspaceMutationDialog`, `AppConfirmActionDialog` / text / select / text-input variants). **No** raw `AlertDialog` / `showDialog` in feature presentation code.
- [ ] Footer actions use `AppButton` (`primary` / `secondary` / `tertiary`) + `AppActionIcons` where icons apply; labels via `context.l10n` (e.g. `commonCancelActionLabel`).
- [ ] Footer order matches §1: dialog-specific secondary actions (left) -> mutating Create/Edit/Delete when present (Edit labeled **Edit**, not Update) -> **Cancel** dismiss/abort. Committing primary sits immediately left of Cancel when Cancel is present; destructive confirms use existing error/delete patterns.
- [ ] Confirm dialogs: one Confirm (or domain verb) + Cancel - no duplicate save-then-confirm pairs in the same footer.
- [ ] Title is **role-based / general** (not the patient's personal name); passed through `AppDialog` so `toDialogTitleUppercase` keeps casing consistent; meaningful `icon` when siblings in this flow already use one.
- [ ] Loading / mutation in flight: shared loading primitives; `closeEnabled: false` when needed; `barrierDismissible: false` on mutating openers; competing footer actions disabled until work finishes.
- [ ] After success or failure: refresh dialog state; on success only, patch/invalidate Riverpod so parent workspaces stay current; Cancel/failure must not patch.
- [ ] Body reuses shared components where equivalents exist (patient chrome, encounter hubs, triage/vitals, status/forms). Extract under `frontend/lib/shared/` if two inventory dialogs need the same section - do not fork per feature.
- [ ] Opens with contextual IDs already resolved (patient, encounter, queue item, bed, appointment); permission-aware actions stay behind existing wrappers.
- [ ] Every load/mutation HTTP call succeeds on the happy path against the real backend contract; failures surface via shared failure banner/helper; no silent ignore / fake local success.
- [ ] Still reachable from every *Used from* / opener site listed below.
- [ ] `{PATTERN_TEST}` stays green for this module's presentation code.

## Context for the executing agent

You are a coding AI agent with full read/write access to this Flutter HMS repo. Execute every step below. Do not ask for clarification. Treat `{CONTRACT}` as normative for dialog UX and `{SYNC_RULE}` as normative for sync. **Scope:** only `{symbol}` and the minimum call-site / shared-helper edits required for compilation and compliance. Do **not** expand to the full 304-dialog catalog. Do **not** invent a new dialog shell.

**Module / surface:** `{module}`  
**Inventory kind:** `{kind}`  
**Extends / uses (inventory):** {extends}

## Current inventory row

| Field | Value |
| --- | --- |
| Symbol | `{symbol}` |
| Purpose | {purpose} |
| Defined in | {defined_loc} |
| Kind | `{kind}` |
| Paired opener(s) | {opener_md} |
| Used from | see list below |

### Used from

{used_md}

### Source peek (heuristic - verify in code)

| Signal | Observation |
| --- | --- |
| `AppDialog` in region | {"yes" if peek["uses_app_dialog"] else "no / unclear"} |
| `showAppDialog` / workspace helpers | {"yes" if peek["uses_show_app_dialog"] else "no / unclear"} |
| Raw `showDialog` / `AlertDialog` | {"yes - migrate" if peek["uses_raw_show_dialog"] or peek["uses_alert_dialog"] else "not seen in peek"} |
| Title snippets | {title_snip} |
| `AppButton` variants (order seen) | {buttons} |
| `barrierDismissible: false` | {"yes" if peek["barrier_false"] else "not seen"} |
| `closeEnabled: false` | {"yes" if peek["close_enabled_false"] else "not seen"} |
| Loading primitives | {"seen" if peek["is_loading"] else "not seen"} |

### Likely gaps vs `{CONTRACT}`

{gap_md}

## Shared building blocks (mandatory reuse)

Prefer these over new one-offs:

{reuse_md}

Shell / chrome references:

- `AppDialog` - `{SHELL_REFS["AppDialog"]}`
- `AppButton` - `{SHELL_REFS["AppButton"]}`
- `AppActionIcons` - `{SHELL_REFS["AppActionIcons"]}`
- Loading - `{SHELL_REFS["AppLoadingIndicator"]}` (+ `AppLoadingSurface` if used by siblings)
- Title casing - `{SHELL_REFS["toDialogTitleUppercase"]}`

Prefer existing openers in `shared/opd_actions`, `shared/patient_actions`, and `shared/components` over copying chrome into a feature folder.

## Implementation steps

1. **Read contract + source**
   - Read `{CONTRACT}` end-to-end (especially §1 Footer, §2 Titles, §3 Loading, §4 Reuse, §5 Behavior, §6 Backend sync, Acceptance checklist).
   - Read `{symbol}` at {defined_loc} and every paired opener / *Used from* call site above.
   - Trace the mutation path: widget -> controller/repository -> REST route -> response DTO -> Riverpod patch.

2. **Normalize shell**
   - Ensure the dialog is composed with `AppDialog` (or an approved higher helper) and opened with `showAppDialog` / `showAppWorkspaceMutationDialog` / confirm helpers as appropriate.
   - Remove any raw `AlertDialog` / `showDialog` introduced by this dialog's presentation path.
   - Keep maximize/resize/close behavior consistent with sibling encounter dialogs unless the helper already owns it.

3. **Normalize title + icon**
   - Use a general, role-based title for **{title}** (e.g. flow/action name - never the patient display name as `AppDialog` title).
   - Wire title through the shell so uppercase normalization applies.
   - Add/keep a meaningful `icon` if peer dialogs in `{module}` already use icons.

4. **Normalize footer actions**
   - Rebuild `actions` with `AppButton` + `AppActionIcons` + `context.l10n`.
   - Enforce §1 order; Cancel label must be **Cancel** (never Close); Cancel aborts without committing.
   - Primary/confirm: `AppButton.primary` with `isLoading` while submitting; destructive paths match `AppConfirmActionDialog` patterns.
   - Match established helpers: **Cancel left of primary**.

5. **Loading + dismissibility**
   - For initial load and submit: show shared loading UX; disable Cancel/close and competing actions; set `barrierDismissible: false` on mutating openers; set `closeEnabled: false` while in flight.

6. **Component reuse**
   - Replace bespoke patient/encounter/triage/vitals/status blocks with shared components listed above when equivalents exist.
   - If this dialog duplicates UI also needed by another inventory row, extract once under `frontend/lib/shared/` and reuse.

7. **Behavior + permissions**
   - Ensure openers pass resolved contextual IDs; do not re-derive identity with blocking logic inside the dialog body.
   - Preserve permission wrappers already used by the parent workspace.

8. **Backend / frontend sync (hard requirement)**
   - Mutations go through repositories over existing REST APIs only.
   - Happy path: every load/mutation API used by this dialog must succeed against the real contract; fix DTO/route/call site if broken.
   - On `AppFailure` / non-success: show shared failure UI, leave data unpatched, keep dialog usable for retry or Cancel.
   - On success only (`saved == true` or equivalent): patch every affected Riverpod slice (encounter, queue, bed, appointment, patient, badges) from response or typed delta.
   - After close, parent workspaces / pinned encounter surfaces must reflect backend truth without a full-app reload.
   - No dual sources of truth: widgets read from Riverpod after a successful round-trip.

9. **Preserve reachability**
   - Do not break `{opener_md}` or the *Used from* sites. Update signatures only when required; fix all call sites in the same change.

10. **Verify**
   - Run analyzer on touched files.
   - Run `{PATTERN_TEST}` (and any feature tests covering this dialog if present).
   - Manually walk the acceptance checklist below and fix any miss before finishing.

## Acceptance criteria (must all pass)

1. `{symbol}` opens through `AppDialog` / approved helpers only.
2. Footer order and Cancel/primary semantics match `{CONTRACT}` §1.
3. Title is general + uppercase-normalized; no patient name as title.
4. Loading blocks dismiss; UI + providers update after successful mutations only.
5. Body sections reuse shared components where equivalents exist.
6. Still reachable from inventory openers / *Used from* sites.
7. Every load and mutation API succeeds on the happy path; failures are shown, not ignored.
8. After success, Riverpod state matches backend persistence for dialog + parent workspaces (no stale encounter/queue/bed/patient data).
9. `{PATTERN_TEST}` remains green.

## Out of scope

- Other inventory rows (unless a shared extract is required for reuse - then keep the extract minimal and shared).
- New dialog frameworks, redesigns unrelated to compliance, or drive-by refactors outside `{symbol}`'s path.
- Inventing client-only "saved" state that is not backed by HTTP success.

## Deliverable

Implement the compliance fixes in the repo. Summarize: files changed, footer/title/loading/sync fixes, any shared extracts, and how verification was run.

<!-- generator: encounter-dialog prompt {idx:02d} slug={slug} symbol={symbol} -->
"""


def main() -> None:
    PROMPTS.mkdir(exist_ok=True)
    # Remove prior encounter-dialog prompts (by generator marker or legacy names)
    for old in list(PROMPTS.glob("*.md")):
        try:
            text = old.read_text(encoding="utf-8")
        except OSError:
            continue
        if (
            "generator: encounter-dialog prompt" in text
            or old.name.startswith("02-")
            and "standardize-" in old.name
        ):
            old.unlink()
    sample = PROMPTS / "_sample_structure_extract.md"
    if sample.exists():
        sample.unlink()

    rows = parse_inventory()
    if len(rows) != 41:
        raise SystemExit(f"Expected 41 inventory rows, found {len(rows)}")

    index_lines = [
        "# Patient encounter flow - dialog prompts",
        "",
        "One actionable agent prompt per inventory row in "
        "[`02-patient-encounter-flow.md`](02-patient-encounter-flow.md).",
        f"Normative contract: [`../{CONTRACT}`](../{CONTRACT}).",
        "",
        "Prompt files live in [`../prompts/`](../prompts/) "
        "(named `NN-<dialog-slug>.md`). "
        "`run_prompts.py` executes every `prompts/*.md` - keep this index here "
        "so it is not mistaken for an implementation brief.",
        "",
        "Regenerate with:",
        "",
        "```bash",
        "python tool/generate_encounter_dialog_prompts.py",
        "```",
        "",
        "| # | Prompt | Symbol | Purpose |",
        "| --- | --- | --- | --- |",
    ]

    used_names: set[str] = set()
    for i, row in enumerate(rows, start=1):
        peek = peek_dialog_context(row["path"], row["symbol"], row["line"])
        body = build_prompt(i, row, peek)
        module = module_hint(row["path"])
        slug = slugify(row["symbol"], module)
        name = f"{i:02d}-{slug}.md"
        if name in used_names:
            raise SystemExit(f"Duplicate prompt filename: {name}")
        used_names.add(name)
        (PROMPTS / name).write_text(body, encoding="utf-8")
        index_lines.append(
            f"| {i:02d} | [`../prompts/{name}`](../prompts/{name}) | `{row['symbol']}` | {row['purpose']} |"
        )
        print(f"wrote {name}")

    index_path = ROOT / "dialog-inventory" / "02-patient-encounter-flow-prompts.md"
    index_path.write_text("\n".join(index_lines) + "\n", encoding="utf-8")
    print(f"wrote index {index_path.name} ({len(rows)} prompts)")


if __name__ == "__main__":
    main()
