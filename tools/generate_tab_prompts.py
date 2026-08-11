#!/usr/bin/env python3
"""Generate prompts/.cursor-compliant remediation prompts from tabs/ inventories."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TABS = ROOT / "tabs"
PROMPTS = ROOT / "prompts"

RULE_LINKS = """\
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`"""

SKIP_FOLDERS = {"01-reception"}  # already authored to gold standard


def title_case_slug(slug: str) -> str:
    parts = re.split(r"[-_]", slug)
    return " ".join(p[:1].upper() + p[1:] if p else "" for p in parts)


def module_display_name(folder: str) -> str:
    # 02-patients -> Patients; 20-admin-setup -> Admin setup
    rest = folder.split("-", 1)[1] if "-" in folder else folder
    return title_case_slug(rest)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_bold_field(text: str, label: str) -> str | None:
    m = re.search(rf"\*\*{re.escape(label)}:\*\*\s*(.+)", text)
    return m.group(1).strip() if m else None


def extract_code_paths(text: str) -> list[str]:
    return re.findall(r"`(frontend/[^`]+)`", text)


def extract_tab_rows(overview: str) -> list[dict]:
    rows = []
    in_table = False
    for line in overview.splitlines():
        if line.startswith("| Enum") or line.startswith("| Enum /"):
            in_table = True
            continue
        if in_table:
            if not line.startswith("|"):
                break
            if re.match(r"\|\s*---", line):
                continue
            cells = [c.strip() for c in line.strip("|").split("|")]
            if len(cells) < 4:
                continue
            file_cell = cells[3]
            fm = re.search(r"\[([^\]]+)\]\(([^)]+)\)", file_cell)
            rows.append(
                {
                    "enum": cells[0].strip("`"),
                    "query": cells[1].strip("`"),
                    "aliases": cells[2],
                    "file": fm.group(2) if fm else file_cell,
                    "label_file": fm.group(1) if fm else file_cell,
                }
            )
    return rows


def extract_source_files(overview: str) -> list[str]:
    paths = []
    in_sources = False
    for line in overview.splitlines():
        if line.startswith("## Source files"):
            in_sources = True
            continue
        if in_sources:
            if line.startswith("##"):
                break
            m = re.match(r"- `(frontend/[^`]+)`", line)
            if m:
                paths.append(m.group(1))
    return paths


def extract_residual_gaps(gaps_text: str) -> list[str]:
    gaps = []
    for line in gaps_text.splitlines():
        m = re.match(r"^\d+\.\s+\*\*(.+?)\*\*\s*(.*)$", line.strip())
        if m:
            gaps.append(f"{m.group(1)} {m.group(2)}".strip())
            continue
        m2 = re.match(r"^-\s+\*\*(.+?)\*\*\s*(.*)$", line.strip())
        if m2 and "Residual" not in m2.group(1):
            gaps.append(f"{m2.group(1)} {m2.group(2)}".strip())
            continue
        m3 = re.match(r"^-\s+(.+)$", line.strip())
        if m3 and "Residual" not in line and "Per-tab" not in line and "Historical" not in line:
            # Keep bullet notes that look like gaps
            body = m3.group(1).strip()
            if any(
                k in body.lower()
                for k in (
                    "print",
                    "export",
                    "filter",
                    "count",
                    "tone",
                    "absent",
                    "missing",
                    "rather than",
                    "does **not**",
                    "does not",
                    "no explicit",
                    "client",
                    "omitted",
                )
            ):
                gaps.append(body)
    # Dedupe while preserving order
    seen = set()
    out = []
    for g in gaps:
        key = g.lower()
        if key not in seen:
            seen.add(key)
            out.append(g)
    return out


def extract_toolbar_order(text: str) -> str | None:
    m = re.search(r"Order(?: on search bar)?:\s*\*\*(.+?)\*\*", text)
    if m:
        return m.group(1).strip()
    m = re.search(r"Order on search bar:\s*\*\*(.+?)\*\*", text)
    return m.group(1).strip() if m else None


def has_table_print(text: str) -> bool | None:
    if re.search(
        r"(Print \(table\)|Print \(toolbar\)|table Print|Export / table Print)[^\n]*\*\*absent\*\*",
        text,
        re.I,
    ):
        return False
    if re.search(r"table Print\s+\*\*absent\*\*|no table Print|Print:\s*\*\*absent\*\*", text, re.I):
        return False
    if re.search(r"Print \(table\)[^\n]*`Print`", text) or re.search(
        r"enablePrint|preview-first|commonPrintActionLabel", text
    ):
        return True
    order = extract_toolbar_order(text) or ""
    if re.search(r"→\s*Print(\s*→|$)", order):
        return True
    return None


def extract_tab_gate(text: str) -> str | None:
    m = re.search(r"Tab gate:\s*(.+)", text)
    return m.group(1).strip() if m else None


def extract_dialog_names(text: str) -> list[str]:
    names: list[str] = []
    in_dialogs = False
    for line in text.splitlines():
        if line.startswith("## 6. Dialogs"):
            in_dialogs = True
            continue
        if in_dialogs:
            if line.startswith("## "):
                break
            if line.startswith("|") and "Dialog" not in line and not re.match(r"\|\s*---", line):
                cells = [c.strip() for c in line.strip("|").split("|")]
                if cells:
                    # Strip backticks / owner notes in first cell
                    name = re.sub(r"`([^`]+)`", r"\1", cells[0])
                    name = re.sub(r"\s*\(.*$", "", name).strip()
                    if name and name.lower() != "dialog":
                        names.append(name)
    return names[:12]


def first_backtick(text: str | None) -> str | None:
    if not text:
        return None
    m = re.search(r"`([^`]+)`", text)
    return m.group(1) if m else text.strip("`")


def extract_count_tone(text: str) -> str | None:
    m = re.search(r"Count tone:\s*`AppTabCountTone\.(\w+)`", text)
    return m.group(1) if m else None


def extract_label_key(text: str) -> str | None:
    m = re.search(r"Label:\s*`([^`]+)`", text)
    return m.group(1) if m else None


def extract_section_query(text: str) -> str | None:
    m = re.search(r"Deep-link `section`:\s*(.+)", text)
    if not m:
        return None
    return m.group(1).strip()


def extract_count_source(text: str) -> str | None:
    m = re.search(r"Count source:\s*(.+)", text)
    return m.group(1).strip() if m else None


def feature_test_dir(sources: list[str]) -> str:
    for p in sources:
        if p.startswith("frontend/test/features/"):
            return p if p.endswith("/") else (p if Path(p).suffix == "" else str(Path(p).parent) + "/")
    for p in sources:
        m = re.match(r"frontend/lib/features/([^/]+)/", p)
        if m:
            return f"frontend/test/features/{m.group(1)}/"
    return "frontend/test/features/"


def page_path(sources: list[str], overview: str) -> str | None:
    page = extract_bold_field(overview, "Page")
    if page:
        m = re.search(r"`([^`]+)`", page)
        if m:
            return m.group(1)
    for p in sources:
        if p.endswith("_page.dart") or p.endswith("_workspace_page.dart"):
            return p
    return None


def access_path(sources: list[str], overview: str) -> str | None:
    access = extract_bold_field(overview, "Access")
    if access:
        m = re.search(r"`([^`]+)`", access)
        if m:
            return m.group(1)
    for p in sources:
        if p.endswith("_access.dart"):
            return p
    return None


def workspace_label(overview: str, folder: str) -> str:
    # First H1
    for line in overview.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            title = re.sub(r"\s+UI inventory$", "", title, flags=re.I)
            title = re.sub(r"\s+workspace$", "", title, flags=re.I)
            return title
    return module_display_name(folder)


def enum_name(overview: str) -> str | None:
    e = extract_bold_field(overview, "Sections enum") or extract_bold_field(overview, "Queue enum")
    return first_backtick(e)


def slug_from_filename(name: str) -> str:
    # 01-all.md -> all
    stem = Path(name).stem
    return re.sub(r"^\d+-", "", stem)


def build_overview_prompt(
    folder: str,
    overview: str,
    tab_rows: list[dict],
    sources: list[str],
) -> str:
    display = workspace_label(overview, folder)
    enum = enum_name(overview) or "desk section enum"
    page = page_path(sources, overview) or "frontend/lib/features/"
    access = access_path(sources, overview)
    test_dir = feature_test_dir(sources)
    per_tab = [r["file"] for r in tab_rows]
    per_tab_prompt_list = "\n".join(f"   - `prompts/{folder}/{f}`" for f in per_tab)
    inventory_prompt_list = "\n".join(f"- `prompts/{folder}/{f}`" for f in per_tab)

    return f"""# {display} overview — workspace compliance program

## Context

Bring the {display} desk to **100% compliance** with `prompts/.cursor` rules: `prompt.mdc`, `screens.mdc`, `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, and `printing.mdc`.

Inventory baseline (do not reinvent atoms): `tabs/{folder}/`. Per-surface remediation prompts live beside this file under `prompts/{folder}/`. Execute this overview first only for shared infrastructure; otherwise implement the matching per-tab / shared-chrome / gaps prompts.

**Compliance** means every acceptance criterion in this program is proven in code and tests. Do not leave “documented exceptions” for required rule clauses unless a numbered requirement here explicitly marks a justified product exception and records the justification in code comments plus tests.

## Requirements

1. Treat `tabs/{folder}/00-overview.md` as the authoritative tab index (`{enum}` order, query values, aliases). Keep deep-link helpers aligned with that index.
2. Implement remediation in this order so shared chrome lands once:
   1. `00-shared-chrome.md`
   2. `99-convention-gaps.md` (cross-cutting count/print/export/tone/filter fixes)
   3. Per-tab prompts:
{per_tab_prompt_list}
3. Keep all operator flows **in-desk** per `screens.mdc`: dialogs / tabs / panels only; no nested feature `GoRoute` pages for multi-step desk work. Module switches stay shell-owned; only use allowed ownership handoffs from `screens.mdc`.
4. Reuse shared components under `frontend/lib/shared/` and existing feature hubs; extend shared primitives when this desk lacks a required shared capability (notably list-table Print, Export gating, authoritative counts). Do not fork parallel tab, table, dialog, form, or print chrome.
5. Preserve RBAC/ABAC: omit unauthorized tabs/actions; never render disabled “no access” placeholders for routine unauthorized scopes. Cover loading, empty, error, success, validation, and visible feedback on every remediated surface.
6. After each remediation, update the matching inventory file under `tabs/{folder}/` so the catalog matches shipped behavior (still not under a restored `screens/` folder).
7. Add or extend automated tests under `{test_dir}` proving authorized atoms remain available and unauthorized atoms are absent.

## Constraints

- Do not recreate `screens/` inventory paths.
- Do not broaden scope into unrelated workspace redesigns except shared primitive extensions required for this desk’s compliance and reuse.
- Do not invent tabs, dialogs, or print templates that are unreachable from this desk after remediation.
- Separate optional polish from required compliance; only required items appear under Requirements.

## Acceptance Criteria

- [ ] Every desk section in `tabs/{folder}/00-overview.md` has a completed remediation prompt under `prompts/{folder}/` and a matching updated inventory under `tabs/{folder}/`.
- [ ] Shared chrome and convention-gap prompts are implemented before claiming per-tab completion for Print, Export gating, authoritative counts, and count tones.
- [ ] No mid-flow navigation to another feature page except allowed ownership handoffs (`screens.mdc`).
- [ ] Tests prove unauthorized UI is absent and authorized UI remains for representative roles.
- [ ] No new markdown inventories under `screens/`.

## Verification

- Trace `{page}`{f", `{access}`" if access else ""}, and widgets listed in `tabs/{folder}/00-overview.md`.
- Run feature tests under `{test_dir}`; add cases for omit-when-unauthorized, count badges, toolbar order Filters → Settings → Export → Print → context (when Print applies), and print-preview-before-print.
- Spot-check mobile / tablet / desktop and light / dark themes on the desk shell.
- Confirm inventory files were updated to match post-remediation UI.

## Relevant Files

- `tabs/{folder}/00-overview.md`
- `prompts/{folder}/00-shared-chrome.md`
- `prompts/{folder}/99-convention-gaps.md`
{inventory_prompt_list}
{RULE_LINKS}
- `{page}`
{f"- `{access}`" if access else ""}
- `{test_dir}`
"""


def build_shared_chrome_prompt(
    folder: str,
    overview: str,
    chrome: str,
    sources: list[str],
) -> str:
    display = workspace_label(overview, folder)
    page = page_path(sources, overview) or "frontend/lib/features/"
    access = access_path(sources, overview)
    test_dir = feature_test_dir(sources)
    toolbar = extract_toolbar_order(chrome) or "Filters → Settings → Export → Print → context"
    print_present = has_table_print(chrome)
    print_req = (
        "Mount **Print** after Export when printing is allowed for that table. Print must open a shared preview-first path (`showAppPrintPreviewDialog` and/or `PrintDocumentTemplates` / existing preview stack) with section and column options aligned to exportable fields (`printing.mdc`, `tables.mdc`). Omit Print when unauthorized; do not show disabled Print."
        if print_present is not False
        else "Where the inventory currently omits table Print, **add** preview-first Print after Export on every printable list table unless a numbered product exception is recorded in tests (`tables.mdc`, `printing.mdc`). Omit Print when unauthorized."
    )

    return f"""# {display} shared chrome — rule compliance

## Context

Remediate cross-tab {display} chrome so it fully complies with `screens.mdc`, `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, and `printing.mdc`. Inventory baseline: `tabs/{folder}/00-shared-chrome.md`. Gaps detail: `tabs/{folder}/99-convention-gaps.md`.

**Shared chrome** means: shell entry, workspace scaffold, `AppTabStrip`, shared `AppListTable` / `AppSearchBar` toolbar wiring, strip primary/secondary actions, and shared dialog hubs opened from multiple tabs.

## Requirements

1. Keep the desk on `AppTabStrip` + `AppTabItem` with unauthorized sections **omitted** — never disabled placeholders (`tabs.mdc`, `prompt.mdc`). Use `AppTabStripVariant.nested` only for subordinate category tabs already modeled by the feature.
2. Implement **authoritative tab counts** for every countable visible tab per `tabs.mdc`: prefer server / workspace summary totals; do not badge from painted page length alone. When Advanced filters or search narrow the active tab, the active badge must show the filtered total for that query; sibling badges must follow one consistent workspace model (shared filter context **or** dedicated scope totals — pick one model and apply it uniformly).
3. Assign `AppTabCountTone` per urgency: use `warning` / `danger` only for queues that need attention; use `info` for non-urgent scopes unless a test-documented product exception justifies otherwise (`tabs.mdc`).
4. Keep table trailing action order exactly: **{toolbar}** (normalize to Filters → Settings → Export → Print → context when Print applies). Use shared labels that resolve to `Filters`, `Settings`, `Export`, and `Print` (`tables.mdc`, `printing.mdc`). Prefer `commonFiltersActionLabel` / `commonPrintActionLabel` (or equivalent keys that resolve to those strings).
5. {print_req}
6. Gate Export with an explicit desk permission check via `canExport` (prefer ∩ `evidence:export` or the feature’s documented export atom); omit Export when unauthorized (`tables.mdc`).
7. Keep strip / context actions after Print (or after Export when Print is omitted by justified exception); omit when unauthorized. Preserve in-desk create/edit/detail flows; reuse shared fields/forms (`forms.mdc`); hide tenant/facility/session context fields the operator already knows.
8. Ensure dialogs opened from shared chrome use **generic titles**, flat bodies, pinned footers, and maximized defaults per `dialogs.mdc`. Identity stays in the body. Do not nest `AppCollapsibleSection` inside another.
9. Any Print trigger reachable from this desk (table toolbar or nested hubs) must use trigger label exactly `Print` and shared preview-first flow (`printing.mdc`).
10. Cover loading, empty, error, success, and retry for workspace load, tab switch, filter apply, export, and print. Synchronize table + all affected tab counts after mutations (`tabs.mdc`, `prompt.mdc`).
11. Preserve deep-link `section` / search / id / action behavior and `syncWorkspaceLocation` in-desk URL sync (`screens.mdc`).

## Constraints

- Prefer extending `AppListTable` / `AppSearchBar` / shared printing once; do not invent a feature-only Print button row.
- Do not add nested feature routes for multi-step desk work.
- Do not restate rule text in code comments; reference the rule file name when a justified exception is unavoidable.
- Do not fork parallel tab, table, dialog, form, or print chrome when a shared path exists or can be extended.

## Acceptance Criteria

- [ ] Every visible countable tab shows a count badge sourced per Requirements 2–3; tones match the urgency policy.
- [ ] Toolbar order on every printable table tab matches Requirement 4 (with unauthorized controls omitted).
- [ ] Print always opens shared preview before device print when present; trigger label is `Print`.
- [ ] Export is omitted when the export gate denies; present when allowed.
- [ ] Unauthorized tabs and strip actions are absent (not disabled).
- [ ] Dialogs opened from shared chrome keep generic titles and reuse shared form/dialog primitives.
- [ ] Mutations refresh table rows and all visible tab counts that can change.
- [ ] `tabs/{folder}/00-shared-chrome.md` updated to match.

## Verification

- Widget / golden or integration tests for toolbar order and omit-when-unauthorized Export / Print / context actions.
- Unit or controller tests for authoritative counts and filtered active-tab badge.
- Manual: light/dark + narrow viewport strip overflow; print preview section/column toggles update live preview when Print applies.
- Regression: deep links for `section=` / search / action still open the correct in-desk surfaces.

## Relevant Files

- `tabs/{folder}/00-shared-chrome.md`
- `tabs/{folder}/99-convention-gaps.md`
- `{page}`
{f"- `{access}`" if access else ""}
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/components/app_tab_strip.dart`
- `frontend/lib/shared/printing/`
- `{test_dir}`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/screens.mdc`
"""


def build_gaps_prompt(
    folder: str,
    overview: str,
    gaps_text: str,
    tab_rows: list[dict],
    sources: list[str],
) -> str:
    display = workspace_label(overview, folder)
    page = page_path(sources, overview) or "frontend/lib/features/"
    test_dir = feature_test_dir(sources)
    residuals = extract_residual_gaps(gaps_text)
    inventory_tabs = "\n".join(f"- `tabs/{folder}/{r['file']}`" for r in tab_rows)

    if residuals:
        gap_reqs = []
        n = 1
        gap_reqs.append("### Inventory residual gaps\n")
        for g in residuals:
            gap_reqs.append(f"{n}. Close this inventory gap: {g}")
            n += 1
        residual_block = "\n".join(gap_reqs)
        residual_ac = "- [ ] Every residual gap listed in Requirements (Inventory residual gaps) is closed or recorded as a justified, tested product exception.\n"
    else:
        residual_block = (
            "### Inventory residual gaps\n\n"
            f"1. Confirm `tabs/{folder}/99-convention-gaps.md` residual list remains empty "
            "after remediation; reopen and fix any regression found during implementation."
        )
        residual_ac = (
            f"- [ ] `tabs/{folder}/99-convention-gaps.md` shows no open required gaps.\n"
        )

    return f"""# {display} convention gaps — cross-cutting remediation

## Context

Close every compliance gap listed in `tabs/{folder}/99-convention-gaps.md` against `prompts/.cursor` rules. This prompt is the cross-cutting checklist; per-tab prompts consume its outcomes. Completing this file is required before claiming {display} **100%** rule compliance.

## Requirements

{residual_block}

### tabs.mdc

{len(residuals) + 1}. Replace client `items.length` / painted-page badge sources with authoritative totals (workspace summary / server `totalItemCount` / controller totals) wherever a total is available.
{len(residuals) + 2}. Define one sibling-count model for this desk and apply it on every tab: either (a) each tab’s scope total under the **same** shared filter/search context, or (b) each tab’s dedicated unfiltered scope total from a workspace summary. Do not mix filtered page length on one tab with raw loaded length on another.
{len(residuals) + 3}. When the active tab’s filters/search change, refresh that tab’s badge to the filtered total and refresh any sibling badges required by the chosen model (`tabs.mdc` sync rules).
{len(residuals) + 4}. Set count tones explicitly: `warning`/`danger` only for attention queues; other tabs default to `info` unless a test-documented exception applies.

### tables.mdc

{len(residuals) + 5}. Extend shared `AppListTable` / search trailing actions so **Print** can mount after Export when printing is allowed. Wire this desk’s printable tables to that API.
{len(residuals) + 6}. Ensure trailing order is exactly Filters → Settings → Export → Print → context actions on every printable table.
{len(residuals) + 7}. Add Export authorization via `canExport` (omit when denied); prefer an explicit ∩ `evidence:export` (or documented export atom) in the feature access map.
{len(residuals) + 8}. Normalize default visible column counts to prefer **5**, or record justified exceptions per tab in tests.
{len(residuals) + 9}. Confirm Advanced filters footers/labels and Table Settings footers match shared copy (`Filters` / `Advanced filters`; `Clear filters` / `Apply filters` / `Close`; `Reset columns` / `Apply columns` / `Close`).

### printing.mdc

{len(residuals) + 10}. Every Print trigger (table toolbar and nested hubs opened from this desk) must use the label **`Print`**, not content-specific strings.
{len(residuals) + 11}. Every Print path must open shared preview before device print, with selectable sections/columns/fields and live preview updates; disable final Print when selection yields an empty document.
{len(residuals) + 12}. Prefer `showAppPrintPreviewDialog` / `AppPrintPreview*` / `PrintDocumentTemplates` — extend shared preview helpers rather than forking.

### dialogs.mdc / forms.mdc / screens.mdc

{len(residuals) + 13}. Audit feature-owned and wrapper dialogs for generic titles, flat layout, no nested `AppCollapsibleSection`, maximized defaults, and shared field reuse; fix any violations found during remediation.
{len(residuals) + 14}. Keep flows in-desk; no nested feature routes for desk tasks; only allowed ownership handoffs per `screens.mdc`.

### Program hygiene

{len(residuals) + 15}. After fixes, rewrite `tabs/{folder}/99-convention-gaps.md` to an empty residual list (or “none”) and refresh each tab inventory file to match shipped behavior.
{len(residuals) + 16}. Add tests that fail if gaps regress (count authority, tone policy, toolbar order, Print label, Export omit, filter/footer labels).

## Constraints

- Shared primitive changes must remain reusable by other workspaces; do not hard-code feature-only Print chrome inside `AppListTable` without a clean API.
- Do not treat inventory “intentional omissions” as compliance when rules require Filters/Print/date/counts—record a justified tested exception or implement the required control.
- Optional enhancements outside the gap list stay out of this prompt.

## Acceptance Criteria

{residual_ac}- [ ] tabs.mdc count/tone/sync requirements verified.
- [ ] tables.mdc Print/Export/column/filter-footer requirements verified.
- [ ] printing.mdc Print label + preview-first + shared templates verified.
- [ ] dialog/form/screen boundaries hold.
- [ ] `tabs/{folder}/99-convention-gaps.md` shows no open required gaps.
- [ ] Regression tests listed in Program hygiene exist and pass.

## Verification

- Run `{test_dir}` plus any new shared `app_list_table` print/export tests.
- Code search: no printable toolbar missing Print when policy allows; no content-specific Print trigger labels; no `items.length` badge sources for tabs that have totals.
- Manual matrix: privileged vs under-privileged user across desk tabs for omit-when-unauthorized Export/Print/context actions.

## Relevant Files

- `tabs/{folder}/99-convention-gaps.md`
- `tabs/{folder}/00-shared-chrome.md`
{inventory_tabs}
- `prompts/{folder}/00-shared-chrome.md`
- `{page}`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/printing/`
- `{test_dir}`
{RULE_LINKS}
"""


def build_tab_prompt(
    folder: str,
    overview: str,
    tab_file: Path,
    tab_text: str,
    sources: list[str],
) -> str:
    display = workspace_label(overview, folder)
    stem = tab_file.stem  # e.g. 01-all
    tab_slug = slug_from_filename(tab_file.name)
    tab_title = title_case_slug(tab_slug)
    label = extract_label_key(tab_text) or f"{display} {tab_title}"
    query = extract_section_query(tab_text) or "`section` per inventory"
    count_source = extract_count_source(tab_text) or "authoritative scope total for this tab"
    tone = extract_count_tone(tab_text)
    toolbar = extract_toolbar_order(tab_text) or extract_toolbar_order(
        read(TABS / folder / "00-shared-chrome.md")
    ) or "Filters → Settings → Export → Print → context"
    print_present = has_table_print(tab_text)
    gate = extract_tab_gate(tab_text)
    dialogs = extract_dialog_names(tab_text)
    page = page_path(sources, overview) or "frontend/lib/features/"
    access = access_path(sources, overview)
    test_dir = feature_test_dir(sources)
    enum = enum_name(overview) or "desk section"

    has_row_select = "Row select" in tab_text or "row select" in tab_text
    attention = tone in {"warning", "danger"} if tone else (
        any(k in tab_slug for k in ("urgent", "critical", "priority", "queue", "due", "pending", "overdue"))
    )
    tone_req = (
        f"Use `AppTabCountTone.{tone}` as inventoried, or escalate to `danger` only when product policy requires (`tabs.mdc`)."
        if tone
        else (
            "Use `AppTabCountTone.warning` or `danger` — this is an attention queue (`tabs.mdc`)."
            if attention
            else "Use an urgency-appropriate `AppTabCountTone` (default `info` unless product-justified `warning`/`danger` is documented in test) (`tabs.mdc`)."
        )
    )

    if print_present is False:
        print_req = (
            "Inventory shows table Print **absent**. Add preview-first Print after Export on this list table "
            "(or record a justified tested product exception if Print must stay off). "
            "Omit Print/Export when unauthorized (`printing.mdc`, `tables.mdc`)."
        )
        toolbar_req = (
            f"Target trailing order Filters → Settings → Export → Print → context actions. "
            f"Inventory today: **{toolbar}**. Normalize shared labels to `Filters`, `Settings`, `Export`, and `Print` "
            f"when those controls apply; keep inventoried context actions after Print (`tables.mdc`, `printing.mdc`)."
        )
    else:
        print_req = (
            "Mount table Print with preview-first shared printing and column/section options aligned to this tab’s "
            "exportable fields. Omit Print/Export/context actions when unauthorized (`printing.mdc`, `tables.mdc`)."
        )
        toolbar_req = (
            f"Toolbar order: **{toolbar}** — normalize shared labels to `Filters`, `Settings`, `Export`, and `Print` "
            f"when those controls apply (`tables.mdc`, `printing.mdc`)."
        )

    row_req = (
        "Preserve row-select → detail/actions hub with **generic titles**; keep nested mutations in-desk via shared "
        "dialogs/forms; omit unauthorized nested actions (`dialogs.mdc`, `forms.mdc`, `screens.mdc`)."
        if has_row_select
        else "Preserve in-desk actions for this surface via shared dialogs/forms; omit unauthorized actions "
        "(`dialogs.mdc`, `forms.mdc`, `screens.mdc`)."
    )
    if dialogs:
        row_req += " Inventoried dialogs to keep compliant: " + "; ".join(dialogs) + "."

    gate_clause = (
        f"omit the tab when gate denies access ({gate})"
        if gate
        else "omit the tab when its inventoried gate denies access"
    )

    local_paths = extract_code_paths(tab_text)
    local_paths = [p for p in local_paths if not p.startswith("frontend/test/")][:8]
    local_block = ("\n" + "\n".join(f"- `{p}`" for p in local_paths)) if local_paths else ""

    return f"""# {display} {tab_title} tab — rule compliance

## Context

Make the {tab_title} desk section fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`. Inventory baseline: `tabs/{folder}/{tab_file.name}`. Apply shared chrome fixes from `prompts/{folder}/00-shared-chrome.md` first when this tab depends on them (counts, Print, Export gate, tones, shared filter labels).

## Requirements

1. Keep strip label `{label}`, deep-link {query}, and {gate_clause} — never show a disabled placeholder (`tabs.mdc`). Align `{enum}` / query helpers with `tabs/{folder}/00-overview.md`.
2. Badge count must be the authoritative total for this tab’s scope ({count_source}). When Filters/search/date narrow the active tab, the **active** badge must reflect the filtered total (`tabs.mdc`). Stop using painted-row length alone when a total is available or can be derived from the same filter model.
3. {tone_req}
4. {toolbar_req}
5. {print_req}
6. Keep default visible columns at **5** unless a justified exception is recorded (always-visible keys / regulatory minimums / explicit default set in code + test). Settings must list every available column; Reset restores the default set (`tables.mdc`).
7. Advanced filters must be comprehensive for this tab’s domain and edit the **same** filter model as the table and active count. Footer actions: **Clear filters** → **Apply filters** → **Close** (`tabs.mdc`, `tables.mdc`, `dialogs.mdc`).
8. {row_req}
9. Reuse shared form fields and validators; hide tenant/facility/session context the operator already knows; reset dependent fields when parents change (`forms.mdc`).
10. Any print entry from this tab (toolbar or nested hub) must use trigger label `Print` and shared preview (`printing.mdc`).
11. Cover empty, loading, error/retry, success, and validation feedback. Refresh table + all affected tab counts after mutations (`prompt.mdc`, `tabs.mdc`).

## Constraints

- Do not fork parallel table/tab/dialog/print chrome when a shared path exists or can be extended.
- Do not add nested feature routes for multi-step work on this tab.
- Do not invent columns that duplicate the same fact (`tables.mdc`).
- Do not broaden into unrelated modules except allowed ownership handoffs (`screens.mdc`).

## Acceptance Criteria

- [ ] Tab count matches authoritative / filtered rules in Requirements 2–3.
- [ ] Toolbar order and labels match Requirement 4; Print preview opens before print when Print applies.
- [ ] Default column policy satisfies Requirement 6; Settings exposes all columns.
- [ ] Advanced filters share the table/count model and include Close (`Requirement 7`).
- [ ] Unauthorized tab and actions are absent (not disabled).
- [ ] Dialogs/forms keep generic titles and shared field reuse.
- [ ] `tabs/{folder}/{tab_file.name}` updated to match.

## Verification

- Tests: tab omit gate; filtered/authoritative count; toolbar Print/Export presence matrix; omit-when-unauthorized for strip and row actions.
- Manual: primary happy-path mutation(s) remain in-desk; light/dark + narrow viewport.

## Relevant Files

- `tabs/{folder}/{tab_file.name}`
- `prompts/{folder}/00-shared-chrome.md`
- `{page}`
{f"- `{access}`" if access else ""}{local_block}
- `{test_dir}`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
"""


def process_folder(folder: str) -> list[Path]:
    tab_dir = TABS / folder
    out_dir = PROMPTS / folder
    out_dir.mkdir(parents=True, exist_ok=True)

    overview_path = tab_dir / "00-overview.md"
    chrome_path = tab_dir / "00-shared-chrome.md"
    gaps_path = tab_dir / "99-convention-gaps.md"

    overview = read(overview_path)
    chrome = read(chrome_path) if chrome_path.exists() else ""
    gaps = read(gaps_path) if gaps_path.exists() else ""
    tab_rows = extract_tab_rows(overview)
    sources = extract_source_files(overview)

    written: list[Path] = []

    overview_out = out_dir / "00-overview.md"
    overview_out.write_text(
        build_overview_prompt(folder, overview, tab_rows, sources), encoding="utf-8"
    )
    written.append(overview_out)

    if chrome_path.exists():
        chrome_out = out_dir / "00-shared-chrome.md"
        chrome_out.write_text(
            build_shared_chrome_prompt(folder, overview, chrome, sources), encoding="utf-8"
        )
        written.append(chrome_out)

    if gaps_path.exists():
        gaps_out = out_dir / "99-convention-gaps.md"
        gaps_out.write_text(
            build_gaps_prompt(folder, overview, gaps, tab_rows, sources), encoding="utf-8"
        )
        written.append(gaps_out)

    for md in sorted(tab_dir.glob("*.md")):
        if md.name in {"00-overview.md", "00-shared-chrome.md", "99-convention-gaps.md"}:
            continue
        tab_text = read(md)
        out = out_dir / md.name
        out.write_text(
            build_tab_prompt(folder, overview, md, tab_text, sources), encoding="utf-8"
        )
        written.append(out)

    return written


def main() -> None:
    folders = sorted(
        p.name for p in TABS.iterdir() if p.is_dir() and p.name not in SKIP_FOLDERS
    )
    all_written: list[Path] = []
    for folder in folders:
        written = process_folder(folder)
        all_written.extend(written)
        print(f"{folder}: {len(written)} prompts")

    # Validate structure
    required_headers = [
        "## Context",
        "## Requirements",
        "## Constraints",
        "## Acceptance Criteria",
        "## Relevant Files",
    ]
    bad = []
    for path in all_written:
        text = path.read_text(encoding="utf-8")
        missing = [h for h in required_headers if h not in text]
        if missing:
            bad.append((path, missing))
        if "## Verification" not in text:
            bad.append((path, ["## Verification"]))

    print(f"Total written: {len(all_written)}")
    if bad:
        print(f"Structure issues: {len(bad)}")
        for path, missing in bad[:20]:
            print(f"  {path.relative_to(ROOT)}: missing {missing}")
        raise SystemExit(1)
    print("All prompts have required sections.")


if __name__ == "__main__":
    main()
