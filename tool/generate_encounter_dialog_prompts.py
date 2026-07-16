"""Generate per-dialog standardization prompts for patient-encounter inventory.

Normative contract: prompt.md (patient-encounter dialog standardization).
Regenerate after inventory or contract changes:

    python tool/generate_encounter_dialog_prompts.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INVENTORY = ROOT / "dialog-inventory" / "02-patient-encounter-flow.md"
PROMPTS = ROOT / "prompts"
CONTRACT = "prompt.md"
API_CONTRACT = ".cursor/api-contract.mdc"
SYNC_RULE = "frontend/.cursor/instant_ui_sync.mdc"
PATTERN_TEST = "frontend/test/shared/layout/workspace_ui_pattern_test.dart"

EMPTY_MARKERS = {"-", "—", "–", "", "n/a", "none"}

SHELL_REFS = {
    "AppDialog": "frontend/lib/shared/components/app_dialog.dart",
    "AppButton": "frontend/lib/shared/components/app_button.dart",
    "AppActionIcons": "frontend/lib/shared/icons/app_action_icons.dart",
    "AppLoadingIndicator": "frontend/lib/shared/components/app_loading_indicator.dart",
    "toDialogTitleUppercase": "frontend/lib/core/utils/app_dialog_title.dart",
    "clinicalActionDialogActions": (
        "frontend/lib/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart"
    ),
    "buildAppDialogFormActions": "frontend/lib/shared/forms/app_form_shell.dart",
}

# Mirrors prompt.md §2 "Reuse before creating" — keep lists in sync with the contract.
SHARED_REUSE = [
    (
        "Details / layout",
        "`AppPatientDetails`, `AppPatientDetailDialog`, `AppSectionPanel`, "
        "`AppContentPanel`, `AppInfoSheetGrid` / `AppInfoSheetRow`, "
        "`AppInfoTileGrid`, `AppExpandableRecordSection`",
    ),
    (
        "Action groups",
        "`AppActionPanel` / `AppActionSection`, permission action components, "
        "`clinicalActionDialogActions`, `buildAppDialogFormActions`, "
        "`buildAppDialogWizardActions`",
    ),
    (
        "Clinical UI",
        "`OpdEncounterDialog`, `FlowActionsDialog`, shared OPD openers, triage "
        "components, `AppRecordVitalsDialog`, `AppVitalsForm`, `AppStatusBadge`, "
        "shared fields, `AppFormInformationBanner`",
    ),
    (
        "Approved shells / openers",
        "`showAppDialog`, `showAppWorkspaceMutationDialog`, "
        "`showAppWorkspaceActionDialog`, `AppConfirmActionDialog` variants, "
        "and existing `show*` / `open*` encounter helpers",
    ),
]


# Stable filenames when auto-slugify would drift from established prompt names.
SLUG_OVERRIDES = {
    "QueueActionsDialog": "opd-queue-actions-dialog",
    "FlowActionsDialog": "flow-actions-dialog",
    "_openReleaseBedDialog": "ipd-release-bed-dialog",
    "PatientPinnedOpdEncounterDialog": "patient-pinned-opd-encounter-dialog",
    "ConsultationPaymentDialog": "consultation-payment-dialog",
    "CorrectStageDialog": "correct-stage-dialog",
    "AssignDoctorDialog": "assign-doctor-dialog",
    "RoutingDecisionDialog": "routing-decision-dialog",
    "ReferralDialog": "referral-dialog",
    "FollowUpDialog": "follow-up-dialog",
    "PrintOpdSummaryDialog": "print-opd-summary-dialog",
    "RecordVitalsDialog": "record-vitals-dialog",
}


def slugify(symbol: str, module: str | None = None) -> str:
    if symbol in SLUG_OVERRIDES:
        return SLUG_OVERRIDES[symbol]
    s = symbol.lstrip("_")
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", s)
    s = s.replace("_", "-").lower()
    s = re.sub(r"[^a-z0-9-]+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    if module and module not in {
        "shared",
        "shared/opd_actions",
        "shared/components",
        "shared/patient_actions",
    }:
        mod = module.replace("/", "-").replace("_", "-")
        # Disambiguate when the same class name exists in multiple features.
        if not s.startswith(mod):
            s = f"{mod}-{s}"
    return s


def _is_empty_cell(value: str) -> bool:
    return value.strip().lower() in EMPTY_MARKERS


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
        defined_clean = defined.replace("`", "").replace("<br>", "\n").strip()
        m = re.search(r"([^\s:]+\.dart)(?::(\d+))?", defined_clean)
        path = m.group(1) if m else None
        line_no = int(m.group(2)) if m and m.group(2) else None
        used_sites = [
            u.strip().replace("`", "")
            for u in re.split(r"<br\s*/?>|\n", used)
            if not _is_empty_cell(u.strip().replace("`", ""))
        ]
        opener_list = [
            o.strip().replace("`", "")
            for o in re.split(r",\s*", openers)
            if not _is_empty_cell(o.strip().replace("`", ""))
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


def _symbol_region(text: str, symbol: str, line_no: int | None) -> str:
    """Return the source region for a class/function declaration."""
    start = None
    patterns = [
        rf"(?:class|mixin)\s+{re.escape(symbol)}\b",
        rf"(?m)^\s*(?:static\s+)?(?:Future\s*<[^>]*>|void|Widget|bool|String|int|double)\s+{re.escape(symbol)}\s*\(",
        rf"(?m)^\s*(?:final|const|var)\s+.*=\s*{re.escape(symbol)}\s*[;(]",
    ]
    for pat in patterns:
        m = re.search(pat, text)
        if m:
            start = m.start()
            break
    if start is None and line_no:
        lines = text.splitlines(keepends=True)
        idx = max(0, line_no - 1)
        start = sum(len(l) for l in lines[:idx])
    if start is None:
        m = re.search(rf"\b{re.escape(symbol)}\s*\(", text)
        if m:
            start = m.start()
    if start is None:
        return text

    tail = text[start:]
    state_name = None
    if re.match(rf"class\s+{re.escape(symbol)}\b", tail):
        state_name = (
            f"_{symbol}State" if not symbol.startswith("_") else f"{symbol}State"
        )
        state_m = re.search(
            rf"\nclass\s+(_?{re.escape(symbol.lstrip('_'))}State)\b",
            tail,
        )
        if state_m:
            state_name = state_m.group(1)

    positions = [m.start() for m in re.finditer(r"(?m)^(?:class |mixin )", tail)]
    end = min(len(tail), 40000)
    if positions:
        kept_state = False
        for pos in positions[1:]:
            header = tail[pos : pos + 120]
            hm = re.match(r"(?:class |mixin )(\w+)", header)
            name = hm.group(1) if hm else ""
            if state_name and name == state_name and not kept_state:
                kept_state = True
                continue
            end = min(pos, 40000)
            break
    elif re.match(
        rf"(?m)^\s*(?:static\s+)?(?:Future\s*<[^>]*>|void|Widget)\s+{re.escape(symbol)}\s*\(",
        tail,
    ):
        # Method/function body: stop at next similarly indented declaration or 250 lines.
        end = min(len(tail), 12000)
    return tail[:end]


def peek_dialog_context(
    path: str | None,
    symbol: str,
    line_no: int | None,
    openers: list[str] | None = None,
    used_from: list[str] | None = None,
) -> dict:
    """Lightweight source peek for titles, AppDialog usage, and buttons."""
    info = {
        "uses_app_dialog": False,
        "uses_show_app_dialog": False,
        "uses_raw_show_dialog": False,
        "uses_alert_dialog": False,
        "uses_circular_progress": False,
        "uses_clinical_actions": False,
        "uses_form_actions": False,
        "uses_wizard_actions": False,
        "title_snippets": [],
        "button_snippets": [],
        "close_enabled_false": False,
        "barrier_false": False,
        "is_loading": False,
        "controller_hints": [],
        "nearby_excerpt": "",
    }
    if not path:
        return info
    file_path = ROOT / path.replace("\\", "/")
    if not file_path.exists():
        return info
    text = file_path.read_text(encoding="utf-8")
    region = _symbol_region(text, symbol, line_no)
    # Include paired openers from the definition file and *Used from* files.
    search_blobs: list[tuple[str, str | None]] = [(text, None)]
    for used in used_from or []:
        used_path = ROOT / used.replace("\\", "/").replace("`", "")
        if used_path.exists() and used_path != file_path:
            search_blobs.append((used_path.read_text(encoding="utf-8"), None))
    opener_regions: list[str] = []
    for opener in openers or []:
        if opener == symbol:
            continue
        for blob, _ in search_blobs:
            if re.search(
                rf"(?m)^\s*(?:static\s+)?(?:Future\s*<[^>]*>|void|Widget)\s+{re.escape(opener)}\s*\(",
                blob,
            ) or re.search(rf"(?:class|mixin)\s+{re.escape(opener)}\b", blob):
                opener_regions.append(_symbol_region(blob, opener, None))
                break
    scan = region + "\n".join(opener_regions)
    info["nearby_excerpt"] = region[:4000]
    info["uses_app_dialog"] = "AppDialog(" in scan
    # Generics are common: showAppDialog<bool>(...)
    info["uses_show_app_dialog"] = bool(
        re.search(
            r"showApp(?:Dialog|WorkspaceMutationDialog|WorkspaceActionDialog|"
            r"Confirm|TriageActionDialog)\s*(?:<[^>]*>)?\s*\(",
            scan,
        )
        or "AppConfirmActionDialog" in scan
    )
    info["uses_raw_show_dialog"] = bool(re.search(r"(?<![A-Za-z])showDialog\s*\(", scan))
    info["uses_alert_dialog"] = "AlertDialog(" in scan
    info["uses_circular_progress"] = "CircularProgressIndicator" in scan
    info["uses_clinical_actions"] = "clinicalActionDialogActions" in scan
    info["uses_form_actions"] = "buildAppDialogFormActions" in scan
    info["uses_wizard_actions"] = "buildAppDialogWizardActions" in scan
    info["close_enabled_false"] = (
        "closeEnabled: false" in scan or "closeEnabled: !" in scan
    )
    info["barrier_false"] = "barrierDismissible: false" in scan
    info["is_loading"] = (
        "isLoading:" in scan
        or "AppLoadingIndicator" in scan
        or "AppLoadingSurface" in scan
        or "isSaving" in scan
        or "_isSubmitting" in scan
        or "isSubmitting" in scan
    )

    for m in re.finditer(r"title:\s*(?:const\s+)?Text\(\s*([^,\n)]+)", scan):
        snippet = m.group(1).strip()[:80]
        if snippet not in info["title_snippets"]:
            info["title_snippets"].append(snippet)
        if len(info["title_snippets"]) >= 6:
            break
    for m in re.finditer(r"AppButton\.(primary|secondary|tertiary)\s*\(", scan):
        info["button_snippets"].append(m.group(1))
        if len(info["button_snippets"]) >= 12:
            break
    # clinicalActionDialogActions builds Cancel (secondary) then primary.
    if info["uses_clinical_actions"] and not info["button_snippets"]:
        info["button_snippets"] = ["secondary", "primary"]

    for m in re.finditer(
        r"\b(?:ref\.read|ref\.watch)\(([^)]+(?:Controller|Repository|Provider)[^)]*)\)",
        scan,
    ):
        hint = m.group(1).strip()[:100]
        if hint not in info["controller_hints"]:
            info["controller_hints"].append(hint)
        if len(info["controller_hints"]) >= 6:
            break
    for m in re.finditer(
        r"\.(create|update|delete|save|submit|assign|release|transfer|dispatch|"
        r"handoff|cancel|close|record|register|reschedule|admit|pay)\w*\s*\(",
        scan,
        re.I,
    ):
        call = m.group(0).rstrip("(").strip(".")
        if call not in info["controller_hints"] and len(info["controller_hints"]) < 8:
            info["controller_hints"].append(f"mutation-ish call: {call}")
    return info


def human_title(symbol: str, purpose: str) -> str:
    if ":" in purpose:
        short = purpose.split(":", 1)[1].strip()
        short = re.sub(r"\s*\([^)]*\)\s*$", "", short)
        if short:
            return short
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
            "Raw Material dialog API detected in the symbol region — migrate to "
            "`AppDialog` / `showAppDialog` (or approved workspace helpers)."
        )
    if not peek["uses_app_dialog"] and not peek["uses_show_app_dialog"]:
        gaps.append(
            "No clear `AppDialog` / `showAppDialog` / workspace-helper usage found "
            "near the symbol — verify the shell and migrate if needed."
        )
    if peek["uses_circular_progress"]:
        gaps.append(
            "`CircularProgressIndicator` detected — replace with "
            "`AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading` only."
        )
    if peek["button_snippets"]:
        order = peek["button_snippets"]
        # Contract order (L→R): secondary actions, Cancel, primary commit.
        # Established clinical helper: Cancel as secondary, then primary.
        if "primary" in order:
            try:
                pi = order.index("primary")
                # If a secondary/tertiary appears after primary, Cancel may be misplaced.
                later = order[pi + 1 :]
                if any(v in later for v in ("secondary", "tertiary")):
                    gaps.append(
                        "Footer button order may place Cancel/secondary after primary — "
                        f"`{CONTRACT}` requires left→right: secondary actions, **Cancel**, "
                        "primary commit."
                    )
            except ValueError:
                pass
    if not peek["barrier_false"]:
        gaps.append(
            "Confirm mutating openers set `barrierDismissible: false` for mutating "
            "dialogs / while submit is in flight."
        )
    if not peek["close_enabled_false"] and peek["is_loading"]:
        gaps.append(
            "Loading path exists — ensure `closeEnabled: false` and disabled Cancel/"
            "competing actions while mutation/load is in flight."
        )
    if not peek["is_loading"]:
        gaps.append(
            "No obvious loading primitive (`isLoading` / `AppLoadingIndicator` / "
            "`AppLoadingSurface`) near the symbol — add shared loading UX for async "
            "open/submit."
        )
    if (
        not peek["uses_clinical_actions"]
        and not peek["uses_form_actions"]
        and not peek["uses_wizard_actions"]
        and peek["button_snippets"]
    ):
        gaps.append(
            "Footer may be hand-rolled — prefer `clinicalActionDialogActions`, "
            "`buildAppDialogFormActions`, or `buildAppDialogWizardActions` when they fit."
        )
    return gaps


def build_prompt(idx: int, row: dict, peek: dict) -> str:
    symbol = row["symbol"]
    purpose = row["purpose"]
    path = row["path"] or "(locate in inventory / codebase — path missing from inventory cell)"
    line = row["line"] if row["line"] is not None else "?"
    kind = row["kind"]
    extends = row["extends"]
    openers = row["openers"]
    used = row["used"]
    title = human_title(symbol, purpose)
    module = module_hint(row["path"])
    slug = slugify(symbol, module)
    gaps = gap_notes(peek)

    defined_loc = f"`{path}:{line}`" if line != "?" else f"`{path}`"
    opener_md = (
        ", ".join(f"`{o}`" for o in openers)
        if openers
        else "_none listed — discover call sites from *Used from* and keep them working_"
    )
    used_md = (
        "\n".join(f"- `{u}`" for u in used)
        if used
        else "- _Inventory lists no *Used from* sites — keep existing private openers reachable._"
    )
    title_snip = (
        ", ".join(f"`{t}`" for t in peek["title_snippets"][:4])
        if peek["title_snippets"]
        else "_not detected in peek — inspect source_"
    )
    buttons = (
        " -> ".join(peek["button_snippets"][:8])
        if peek["button_snippets"]
        else "_not detected — inspect `AppDialog.actions`_"
    )
    gap_md = (
        "\n".join(f"- {g}" for g in gaps)
        if gaps
        else "- Peek did not flag obvious gaps; still run the full acceptance checklist — peeks are heuristic."
    )
    reuse_md = "\n".join(f"- **{k}:** {v}" for k, v in SHARED_REUSE)
    controller_md = (
        ", ".join(f"`{h}`" for h in peek["controller_hints"][:6])
        if peek["controller_hints"]
        else "_not detected in peek — trace widget → workspace controller → repository → backend route_"
    )
    action_helper_md = ", ".join(
        label
        for label, flag in (
            ("`clinicalActionDialogActions`", peek["uses_clinical_actions"]),
            ("`buildAppDialogFormActions`", peek["uses_form_actions"]),
            ("`buildAppDialogWizardActions`", peek["uses_wizard_actions"]),
        )
        if flag
    ) or "_none detected — adopt an approved action helper when the footer fits_"

    return f"""# Standardize `{symbol}` — {title}

## Objective

Deeply refactor **`{symbol}`** ({purpose}) so it **100% complies** with [`{CONTRACT}`](../{CONTRACT}) — the patient-encounter dialog standardization contract. This is structural, not cosmetic: consolidate onto the established product surface used by the rest of [`dialog-inventory/02-patient-encounter-flow.md`](../dialog-inventory/02-patient-encounter-flow.md). UI state and backend persistence must stay aligned per [`{SYNC_RULE}`](../{SYNC_RULE}) and [`.cursor/api-contract.mdc`](../{API_CONTRACT}).

## Compliance checklist (from `{CONTRACT}` — this dialog only)

### 1. Established shells
- [ ] Composed through `AppDialog` and opened with `showAppDialog`, or an approved helper: `showAppWorkspaceMutationDialog`, `showAppWorkspaceActionDialog`, `AppConfirmActionDialog` variants, or an existing `show*` / `open*` encounter helper.
- [ ] **No** raw `AlertDialog` / `showDialog` on this dialog's presentation path.
- [ ] Purpose, listed call sites, resolved contextual IDs, and permission wrappers are preserved.

### 2. Reuse before creating
- [ ] Repeated shells, sections, rows, forms, states, and action groups use one canonical implementation; superseded local copies are removed.
- [ ] Shared barrels and encounter flows were searched before adding widgets; canonical APIs are extended, not copied or trivially wrapped.
- [ ] Body uses shared details/layout, action-group, and clinical UI primitives listed under **Shared building blocks** when equivalents exist.
- [ ] If no shared primitive exists and another inventory dialog needs the same UI, create one configurable, domain-neutral primitive under `frontend/lib/shared/`; keep domain behavior in controllers.

### 3. Loading and actions
- [ ] Loading uses only `AppLoadingIndicator` or `AppLoadingSurface`; submission uses `AppButton.isLoading`. **No** `CircularProgressIndicator` or other loaders.
- [ ] While loading or saving: Cancel, close, and competing actions are disabled; `closeEnabled: false`; mutating openers use `barrierDismissible: false`.
- [ ] Footer order left→right: dialog-specific **secondary** actions, then **Cancel**, then the **primary** commit. Prefer one commit; use Create → Edit → Delete only when multiple mutations are essential.
- [ ] Actions use `AppButton` + `AppActionIcons` + localized labels. Label is **Cancel** (not Close) and **Edit** (not Update). Confirmation dialogs: one domain verb/Confirm + Cancel.
- [ ] Prefer `clinicalActionDialogActions` / `buildAppDialogFormActions` / `buildAppDialogWizardActions` when they fit instead of a hand-rolled footer.

### 4. Titles
- [ ] Title is general / role-based — **never** the patient's personal name.
- [ ] Title is passed through `AppDialog` for uppercase normalization; icon matches sibling conventions in this flow when peers already use icons.

### 5. Backend correctness and sync
- [ ] Every load/mutation is traced end-to-end: dialog → workspace controller → repository/DTO → real backend route/schema/service.
- [ ] IDs, `snake_case` payloads, auth, envelopes, and response decoding match [`{API_CONTRACT}`](../{API_CONTRACT}); either side is fixed when mismatched.
- [ ] Widgets never call APIs or own competing server data. Mutations go over HTTP; WebSockets only reconcile ([`{SYNC_RULE}`](../{SYNC_RULE})).
- [ ] On failure: dialog stays open, `AppFailure` is shown through shared failure UI, and **nothing** is patched. No fake or silently ignored success.
- [ ] On persisted success only: immediately patch every affected Riverpod slice, then apply the smallest targeted refresh/realtime reconciliation. Dialog, parent workspaces, pinned views, lists, details, and badges agree with backend truth without a full reload.
- [ ] Cancel / failure neither patches nor dismisses as if saved.

### 6. Reachability and verification
- [ ] Still reachable from every paired opener and *Used from* site listed below.
- [ ] `{PATTERN_TEST}` stays green. Add focused widget, controller, DTO, and (when the stack is touched) backend route/schema/service tests for this dialog's path.

## Context for the executing agent

You are a coding AI agent with full read/write access to this Flutter HMS repo. Execute every step below. Do not ask for clarification. Treat [`{CONTRACT}`](../{CONTRACT}) as normative for dialog structure/UX, [`{API_CONTRACT}`](../{API_CONTRACT}) as normative for HTTP contracts, and [`{SYNC_RULE}`](../{SYNC_RULE}) as normative for Riverpod/realtime sync.

**Scope:** only `{symbol}` and the minimum call-site / shared-helper edits required for compilation and compliance. Do **not** expand to unrelated inventory rows or invent a new dialog shell. Do not retain duplication merely to minimize the diff.

**Module / surface:** `{module}`  
**Inventory kind:** `{kind}`  
**Extends / uses (inventory):** {extends}  
**Action helper peek:** {action_helper_md}  
**Controller / mutation peek:** {controller_md}

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

### Source peek (heuristic — verify in code)

| Signal | Observation |
| --- | --- |
| `AppDialog` in region | {"yes" if peek["uses_app_dialog"] else "no / unclear"} |
| `showAppDialog` / workspace helpers | {"yes" if peek["uses_show_app_dialog"] else "no / unclear"} |
| Raw `showDialog` / `AlertDialog` | {"yes — migrate" if peek["uses_raw_show_dialog"] or peek["uses_alert_dialog"] else "not seen in peek"} |
| `CircularProgressIndicator` | {"yes — replace" if peek["uses_circular_progress"] else "not seen"} |
| Title snippets | {title_snip} |
| `AppButton` variants (order seen) | {buttons} |
| `barrierDismissible: false` | {"yes" if peek["barrier_false"] else "not seen"} |
| `closeEnabled: false` | {"yes" if peek["close_enabled_false"] else "not seen"} |
| Loading primitives | {"seen" if peek["is_loading"] else "not seen"} |

### Likely gaps vs `{CONTRACT}`

{gap_md}

## Shared building blocks (mandatory reuse)

Prefer these over new one-offs (from `{CONTRACT}` Requirement 2):

{reuse_md}

Shell / chrome references:

- `AppDialog` — `{SHELL_REFS["AppDialog"]}`
- `AppButton` — `{SHELL_REFS["AppButton"]}`
- `AppActionIcons` — `{SHELL_REFS["AppActionIcons"]}`
- Loading — `{SHELL_REFS["AppLoadingIndicator"]}` (+ `AppLoadingSurface` if used by siblings)
- Title casing — `{SHELL_REFS["toDialogTitleUppercase"]}`
- Clinical footer helper — `{SHELL_REFS["clinicalActionDialogActions"]}`
- Form footer helper — `{SHELL_REFS["buildAppDialogFormActions"]}`

Prefer existing openers in `shared/opd_actions`, `shared/patient_actions`, `shared/clinical_actions`, and `shared/components` over copying chrome into a feature folder.

## Implementation steps

1. **Read contract + source**
   - Read [`{CONTRACT}`](../{CONTRACT}) end-to-end (Scope + Requirements 1–5 + Verification).
   - Skim [`{API_CONTRACT}`](../{API_CONTRACT}) and [`{SYNC_RULE}`](../{SYNC_RULE}) for payload/envelope and patch/reconcile rules.
   - Read `{symbol}` at {defined_loc} and every paired opener / *Used from* call site above.
   - Trace each load and mutation: dialog → workspace controller → repository/DTO → backend route/schema/service → response decode → Riverpod patch.

2. **Normalize shell (Requirement 1)**
   - Compose with `AppDialog` (or an approved higher helper) and open with `showAppDialog` / `showAppWorkspaceMutationDialog` / `showAppWorkspaceActionDialog` / confirm helpers as appropriate.
   - Remove any raw `AlertDialog` / `showDialog` on this presentation path.
   - Keep maximize/resize/close behavior consistent with sibling encounter dialogs unless the helper already owns it.
   - Preserve purpose, contextual IDs, and permission wrappers.

3. **Normalize title + icon (Requirement 4)**
   - Use a general, role-based title for **{title}** (flow/action name — never the patient display name as `AppDialog` title).
   - Pass the title through the shell so uppercase normalization applies.
   - Add/keep a meaningful `icon` if peer dialogs in `{module}` already use icons.

4. **Normalize loading + footer actions (Requirement 3)**
   - Use only `AppLoadingIndicator` / `AppLoadingSurface` / `AppButton.isLoading`.
   - Rebuild `actions` with `AppButton` + `AppActionIcons` + `context.l10n`, or an approved action helper.
   - Enforce left→right order: secondary actions → **Cancel** → primary commit. Cancel aborts without committing and is never labeled Close. Edit is never labeled Update.
   - While in flight: disable Cancel/close/competing actions; `closeEnabled: false`; `barrierDismissible: false` on mutating openers.
   - Confirm dialogs: one domain verb/Confirm + Cancel.

5. **Component reuse (Requirement 2)**
   - Replace bespoke patient/encounter/triage/vitals/status/section/action blocks with the shared primitives listed above when equivalents exist.
   - Inventory duplicates across encounter dialogs; migrate every applicable flow to the canonical implementation and delete superseded locals.
   - If this dialog duplicates UI also needed by another inventory row and no shared primitive exists, extract once under `frontend/lib/shared/` (domain-neutral, configurable) and reuse. Keep domain logic in controllers.

6. **Behavior + permissions**
   - Openers must pass already-resolved contextual IDs (patient, encounter, queue item, bed, appointment, etc.); do not re-derive identity with blocking logic inside the dialog body.
   - Preserve permission wrappers already used by the parent workspace.

7. **Backend / frontend sync (Requirement 5 — hard requirement)**
   - Widgets read from Riverpod and delegate to controllers; widgets never call APIs.
   - Mutations go through repositories over existing REST APIs only; WebSockets reconcile only.
   - Happy path: every load/mutation API used by this dialog must succeed against the real contract; fix DTO/route/schema/call site if broken.
   - On `AppFailure` / non-success: show shared failure UI, leave data unpatched, keep the dialog open for retry or Cancel.
   - On persisted success only (`saved == true` or equivalent): patch every affected Riverpod slice (encounter, queue, bed, appointment, patient, badges, lists, details) from the response or a typed delta, then apply the smallest targeted refresh/realtime reconciliation.
   - After close, parent workspaces / pinned encounter surfaces must reflect backend truth without a full-app reload.
   - Cancel and failure must neither patch nor present a false success.

8. **Preserve reachability**
   - Do not break {opener_md} or the *Used from* sites. Update signatures only when required; fix all call sites in the same change.

9. **Verify (Verification section of `{CONTRACT}`)**
   - Run analyzer on touched files.
   - Keep `{PATTERN_TEST}` green.
   - Add or update focused widget, controller, DTO, and (if touched) backend route/schema/service tests.
   - Confirm happy-path APIs succeed; cancel/failure neither patches nor dismisses as saved.
   - Confirm equivalent flows share primitives, spacing, sections, actions, loading/error behavior, and responsive layout without duplicate UI.
   - Walk the acceptance checklist below and fix any miss before finishing.

## Acceptance criteria (must all pass)

1. `{symbol}` opens only through `AppDialog` / approved helpers — no raw Material dialog APIs.
2. Footer order is secondary → Cancel → primary; labels are Cancel/Edit (not Close/Update); confirmations are one domain verb + Cancel.
3. Loading uses only shared spinner primitives; dismiss and competing actions are blocked while in flight.
4. Title is general, uppercase-normalized, and never a patient name.
5. Body sections and action groups reuse canonical shared primitives; no unjustified local forks.
6. Still reachable from inventory openers / *Used from* sites with contextual IDs and permissions intact.
7. Every load and mutation API succeeds on the happy path against the real backend contract; failures surface via `AppFailure` UI and patch nothing.
8. After persisted success only, Riverpod + targeted reconciliation make dialog and parent surfaces match backend truth (no stale encounter/queue/bed/patient/badge data; no full reload required).
9. `{PATTERN_TEST}` remains green; focused tests cover this dialog's critical path.

## Out of scope

- Other inventory rows (unless a shared extract is required for reuse — then keep the extract minimal, shared, and domain-neutral).
- New dialog frameworks, redesigns unrelated to compliance, or drive-by refactors outside `{symbol}`'s path.
- Inventing client-only "saved" state that is not backed by HTTP success.
- Retaining duplicate local UI solely to shrink the diff.

## Deliverable

Implement the compliance fixes in the repo. Summarize: files changed; shell/title/footer/loading/reuse/sync fixes; any shared extracts; API/DTO/route fixes; tests added or run; and how verification was performed.

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
        "# Patient encounter flow — dialog prompts",
        "",
        "One actionable agent prompt per inventory row in "
        "[`02-patient-encounter-flow.md`](02-patient-encounter-flow.md).",
        f"Normative contract: [`../{CONTRACT}`](../{CONTRACT}) "
        f"(also [`../{API_CONTRACT}`](../{API_CONTRACT}), "
        f"[`../{SYNC_RULE}`](../{SYNC_RULE})).",
        "",
        "Prompt files live in [`../prompts/`](../prompts/) "
        "(named `NN-<dialog-slug>.md`). "
        "`run_prompts.py` executes every `prompts/*.md` — keep this index here "
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
        peek = peek_dialog_context(
            row["path"],
            row["symbol"],
            row["line"],
            row["openers"],
            row["used"],
        )
        body = build_prompt(i, row, peek)
        module = module_hint(row["path"])
        slug = slugify(row["symbol"], module)
        name = f"{i:02d}-{slug}.md"
        if name in used_names:
            raise SystemExit(f"Duplicate prompt filename: {name}")
        used_names.add(name)
        (PROMPTS / name).write_text(body, encoding="utf-8", newline="\n")
        index_lines.append(
            f"| {i:02d} | [`../prompts/{name}`](../prompts/{name}) | "
            f"`{row['symbol']}` | {row['purpose']} |"
        )
        print(f"wrote {name}")

    index_path = ROOT / "dialog-inventory" / "02-patient-encounter-flow-prompts.md"
    index_path.write_text("\n".join(index_lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote index {index_path.name} ({len(rows)} prompts)")


if __name__ == "__main__":
    main()
