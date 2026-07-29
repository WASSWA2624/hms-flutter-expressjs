"""Generate prompts/billing-and-sections/** from ui-permissions tab inventory."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "prompts" / "ui-permissions"
DST = ROOT / "prompts" / "billing-and-sections"

# Per-folder financial focus (module-level defaults).
MODULE_FOCUS: dict[str, str] = {
    "patients": (
        "Patient registration itself is free, but nested quick actions that "
        "request consults, labs, imaging, pharmacy, procedures, admission, "
        "insurance enrollment, deposits, or collect balances must create or "
        "update Billing records. Balance-due surfaces must reflect live "
        "outstanding balances from Billing."
    ),
    "reception": (
        "Desk flows often gate clinical progress on payment. Appointments, "
        "queue, visits, and payment-gate actions that collect fees, deposits, "
        "or clear holds must settle through Billing—not local-only flags."
    ),
    "billing": (
        "This is the Billing system of record. Validate issue, receive payment, "
        "refund, adjust, waive, void, credit note, claim handoff, approval, "
        "dunning, shift/day close, ledger, and reconciliation end-to-end with "
        "supported payment methods and realtime UI sync."
    ),
    "claims": (
        "Authorizations, claim prep/submit/amend, settlement, co-pay, and "
        "insurance catalog pricing must keep patient invoices, coverage splits, "
        "and remittances synchronized with Billing."
    ),
    "subscriptions": (
        "Tenant/facility subscription invoices, plan charges, license fees, "
        "and payment collection are commercial billing—ensure they use the "
        "subscriptions invoice path without corrupting patient Billing ledgers, "
        "and that patient Billing remains the clinical revenue path."
    ),
    "opd": (
        "Consultation fees, triage-linked services, and payment gates "
        "(WAITING_CONSULTATION_PAYMENT) must bill via clinical-request / OPD "
        "billing sync. Completing consult must not skip unpaid required charges "
        "unless policy explicitly defers and records the deferral in Billing."
    ),
    "emergency": (
        "Urgent care may defer payment when policy allows, but deferred, "
        "ambulance, procedure, and consumable charges must still create "
        "Billing records (including deferred/outstanding status) and later "
        "settlement must reconcile them."
    ),
    "ipd": (
        "Admission deposits, bed/day charges, transfers that change rate, "
        "consumables, and discharge financial clearance must post to Billing. "
        "Do not clear discharge without settling or explicitly recording "
        "outstanding balances."
    ),
    "rooms-beds": (
        "Bed assignment/turnover that incurs room or bed charges must update "
        "Billing line items; out-of-service must not silently drop billable "
        "occupancy charges already accrued."
    ),
    "icu": (
        "ICU bed/day, critical-care packages, transfers, and discharge-ready "
        "financial gates must integrate with Billing the same way as IPD, "
        "without cashier workflows owning clinical actions."
    ),
    "nursing": (
        "Billable nursing procedures, consumables, medication administrations "
        "tied to chargeable items, and discharge-pending financial checks must "
        "post through Billing / clinical-request billing—not nurse-local tallies."
    ),
    "clinical": (
        "Orders and completed services (procedures, follow-up visits, results "
        "that unlock chargeable acts) must ensure request-time or completion-time "
        "billing hooks fire; unpaid required charges must surface consistently."
    ),
    "physiotherapy": (
        "Therapy session packs, individual sessions, missed-session fees (if "
        "policy), and referral acceptance that starts a paid plan must create "
        "Billing records and settle before or per package rules."
    ),
    "lab": (
        "Every lab order/request must create billable lines via clinical-request "
        "billing; verification/release must not orphan unpaid required tests "
        "unless NOT_REQUIRED / NO_CHARGE is explicit and audited."
    ),
    "radiology": (
        "Imaging orders must bill at request (or documented exception); "
        "reporting/release must keep payment status consistent with Billing."
    ),
    "pharmacy": (
        "Dispense, partial fill, and pending-payment gates must collect or "
        "confirm settlement through Billing before stock leaves; returns/refunds "
        "must reverse or credit Billing lines without duplicate charges."
    ),
    "operations": (
        "Chargeable facility/service requests and billable asset services must "
        "post to Billing when they have a patient/encounter payer context; "
        "internal-only work must be explicitly NOT_BILLED."
    ),
    "housekeeping": (
        "Patient-billable room turnover or private-room cleaning surcharges (if "
        "configured) must hit Billing; staff-only tasks must remain NOT_BILLED."
    ),
    "hr": (
        "Payroll drafts are staff compensation, not patient Billing. Ensure "
        "no patient revenue path is mixed in; if any staff-paid clinic service "
        "appears, route it through Billing correctly and keep payroll separate."
    ),
    "biomedical": (
        "Patient-billable device usage or implantable/consumable charges must "
        "post to Billing; internal maintenance work orders must stay NOT_BILLED."
    ),
    "communications": (
        "Paid notification/SMS packages are tenant commercial charges if "
        "present; patient clinical Billing must not be bypassed by message "
        "send actions that imply paid care delivery."
    ),
    "integrations": (
        "Interop payloads that create orders or payments must invoke the same "
        "Billing engine/idempotency paths as UI; webhooks must not acknowledge "
        "settlement without a Billing ledger entry."
    ),
    "discharge": (
        "Financial clearance, pharmacy returns, outstanding balances, waivers, "
        "and final invoices must complete via Billing before discharge closure; "
        "link to Billing workspace instead of duplicating payment logic."
    ),
    "theater": (
        "Theatre/procedure packages, consumables, implants, and pre-op billing "
        "gates must create Billing lines; recovery completion must not skip "
        "unsettled required charges without documented deferral."
    ),
    "mortuary": (
        "Intake storage fees, embalming, viewing, and release charges must "
        "create Billing invoices; custody transfers must preserve payer and "
        "balance continuity."
    ),
    "admin-access": (
        "Role/entitlement changes that grant billing permissions must not "
        "alter historical ledgers. Demo/seed financial data must use Billing "
        "factories, not orphan amounts."
    ),
    "settings": (
        "Price lists, payment-method enablement, tax, waiver policies, and "
        "billing configuration must apply through shared Billing price-resolver "
        "and payment-method validators; preference screens must not hardcode "
        "bypass flags."
    ),
    "_screens": (
        "Home/reports/profile may surface balances, payment shortcuts, or "
        "financial KPIs—these must read live Billing state and open canonical "
        "Billing/reception flows, never shadow ledgers."
    ),
}

# Extra per-tab focus overrides (folder/slug -> sentence).
TAB_FOCUS: dict[str, str] = {
    "reception/payment-gate": (
        "Primary focus: collect or clear payment holds so clinical progress "
        "can continue; every clearance must settle or defer via Billing."
    ),
    "patients/balance-due": (
        "Primary focus: outstanding balances, partial payments, deposits, and "
        "quick-pay actions must mutate Billing and refresh balances immediately."
    ),
    "pharmacy/pending-payment": (
        "Primary focus: block dispense until Billing shows required lines paid "
        "or explicitly waived/deferred with audit."
    ),
    "billing/awaiting-payment": (
        "Primary focus: receive payment across all supported methods, partial "
        "payments, and realtime balance updates."
    ),
    "billing/needs-issue": (
        "Primary focus: invoice issuance from draft/unbilled clinical charges "
        "without losing line provenance or creating duplicates."
    ),
    "billing/overdue": (
        "Primary focus: dunning, adjustments, waivers, and collections that "
        "keep overdue balances reconciled."
    ),
    "billing/approval-required": (
        "Primary focus: financial approvals for write-offs, large discounts, "
        "refunds, and voids with audit trail."
    ),
    "billing/claims-pending": (
        "Primary focus: insurance claim handoff, co-pay remaining, and "
        "remittance reconciliation back into Billing."
    ),
    "claims/settled": (
        "Primary focus: remittance settlement must close or adjust patient "
        "responsibility lines in Billing without duplicate receipts."
    ),
    "claims/authorizations": (
        "Primary focus: pre-auth limits and covered amounts must constrain "
        "Billing coverage splits."
    ),
    "opd/arrivals": (
        "Primary focus: arrival registration fees and consult payment gate "
        "entry into Billing."
    ),
    "discharge/pending-clearance": (
        "Primary focus: billing clearance checklist must reflect live "
        "outstanding invoices and block unsafe closure."
    ),
    "ipd/admission-queue": (
        "Primary focus: admission deposits/prepayments and bed-rate setup "
        "must create Billing records at admit."
    ),
    "ipd/discharge": (
        "Primary focus: final bill, refunds of unused deposits, and "
        "outstanding balance handling before discharge."
    ),
    "subscriptions/invoices": (
        "Primary focus: commercial subscription invoicing and payment—"
        "keep separate from patient clinical Billing ledgers."
    ),
    "hr/payroll-drafts": (
        "Primary focus: confirm payroll is isolated from patient Billing; "
        "fix any misplaced patient charges."
    ),
}


def _parse_source(path: Path) -> dict[str, str] | None:
    if path.name in {"README.md", "_shared-rules.md"}:
        return None
    text = path.read_text(encoding="utf-8")
    title = re.search(
        r"^# UI Permission Scan — (.+?) / (.+?) \(`([^`]+)`\)\s*$",
        text,
        re.M,
    )
    if not title:
        return None
    screen_name, tab_label, route = title.group(1), title.group(2), title.group(3)
    tab = re.search(
        r"Target tab: \*\*(.+?)\*\* \(`([^`]+)`\)\.\s*(.*)",
        text,
    )
    feature = re.search(r"Feature code: `([^`]+)`", text)
    module = re.search(r"Module entitlement: `([^`]+)`", text)
    screen_inv = re.search(r"Screen inventory: `([^`]+)`", text)
    tab_slug = tab.group(2) if tab else path.stem
    tab_blurb = (tab.group(3).strip() if tab else "").rstrip(".")
    return {
        "rel": path.relative_to(SRC).as_posix(),
        "folder": path.parent.name,
        "stem": path.stem,
        "screen_name": screen_name,
        "tab_label": tab_label,
        "route": route,
        "tab_slug": tab_slug,
        "tab_blurb": tab_blurb,
        "feature": feature.group(1) if feature else f"frontend/lib/features/{path.parent.name}/",
        "module": module.group(1) if module else path.parent.name,
        "screen_inv": screen_inv.group(1) if screen_inv else f"screens/{path.parent.name}.md",
    }


def _backend_paths(folder: str) -> list[str]:
    mapping: dict[str, list[str]] = {
        "patients": ["backend/src/modules/patients/", "backend/src/lib/billing/"],
        "reception": ["backend/src/modules/reception/", "backend/src/lib/billing/"],
        "billing": [
            "backend/src/modules/billing/",
            "backend/src/modules/billing-adjustment/",
            "backend/src/lib/billing/",
        ],
        "claims": ["backend/src/modules/claims/", "backend/src/lib/billing/"],
        "subscriptions": ["backend/src/modules/subscriptions/"],
        "opd": ["backend/src/modules/opd-flow/", "backend/src/lib/billing/"],
        "emergency": ["backend/src/modules/emergency/", "backend/src/lib/billing/"],
        "ipd": ["backend/src/modules/ipd/", "backend/src/lib/billing/"],
        "rooms-beds": ["backend/src/modules/rooms-beds/", "backend/src/lib/billing/"],
        "icu": ["backend/src/modules/icu/", "backend/src/lib/billing/"],
        "nursing": ["backend/src/modules/nursing/", "backend/src/lib/billing/"],
        "clinical": ["backend/src/modules/clinical/", "backend/src/lib/billing/"],
        "physiotherapy": ["backend/src/modules/physiotherapy/", "backend/src/lib/billing/"],
        "lab": ["backend/src/modules/lab/", "backend/src/lib/billing/"],
        "radiology": ["backend/src/modules/radiology/", "backend/src/lib/billing/"],
        "pharmacy": ["backend/src/modules/pharmacy/", "backend/src/lib/billing/"],
        "operations": ["backend/src/modules/operations/", "backend/src/lib/billing/"],
        "housekeeping": ["backend/src/modules/housekeeping/", "backend/src/lib/billing/"],
        "hr": ["backend/src/modules/hr/"],
        "biomedical": ["backend/src/modules/biomedical/", "backend/src/lib/billing/"],
        "communications": ["backend/src/modules/communications/"],
        "integrations": ["backend/src/modules/integrations/", "backend/src/lib/billing/"],
        "discharge": ["backend/src/modules/discharge/", "backend/src/lib/billing/"],
        "theater": ["backend/src/modules/theater/", "backend/src/lib/billing/"],
        "mortuary": ["backend/src/modules/mortuary/", "backend/src/lib/billing/"],
        "admin-access": ["backend/src/modules/access/"],
        "settings": [
            "backend/src/modules/settings/",
            "backend/src/lib/billing/price-resolver.js",
        ],
        "_screens": ["backend/src/modules/billing/", "backend/src/lib/billing/"],
    }
    return mapping.get(folder, ["backend/src/lib/billing/", "backend/src/modules/billing/"])


def _focus(meta: dict[str, str]) -> str:
    key = f"{meta['folder']}/{meta['stem']}"
    parts = []
    if key in TAB_FOCUS:
        parts.append(TAB_FOCUS[key])
    parts.append(MODULE_FOCUS.get(meta["folder"], MODULE_FOCUS["_screens"]))
    if meta["tab_blurb"]:
        parts.append(f"Tab role: {meta['tab_blurb']}.")
    return " ".join(parts)


def render_prompt(meta: dict[str, str]) -> str:
    screen = meta["screen_name"]
    tab = meta["tab_label"]
    route = meta["route"]
    slug = meta["tab_slug"]
    focus = _focus(meta)
    backend_lines = "\n".join(f"- `{p}`" for p in _backend_paths(meta["folder"]))
    feature = meta["feature"]
    screen_inv = meta["screen_inv"]
    module = meta["module"]
    test_feature = feature.replace("frontend/lib/features/", "frontend/test/features/").rstrip("/")

    relevant = [
        screen_inv,
        feature,
        "frontend/lib/features/billing/",
        "frontend/lib/shared/clinical_actions/clinical_request_billing_state.dart",
        "frontend/lib/shared/patient_actions/patient_billing_quick_dialog.dart",
        "frontend/lib/shared/layout/app_screen_section.dart",
        "frontend/lib/shared/components/app_content_panel.dart",
        "frontend/lib/shared/layout/app_workspace.dart",
        *_backend_paths(meta["folder"]),
        "backend/src/lib/billing/clinical-request-billing.js",
        "backend/src/lib/billing/financials.js",
        "prompts/billing-and-sections/_shared-rules.md",
        "prompts/.cursor/prompt.mdc",
        f"{test_feature}/",
    ]
    # Preserve order, drop duplicates (e.g. billing feature path listed twice).
    seen: set[str] = set()
    relevant_unique: list[str] = []
    for item in relevant:
        if item in seen:
            continue
        seen.add(item)
        relevant_unique.append(item)
    relevant_lines = "\n".join(f"- `{p}`" for p in relevant_unique)

    return f"""# Billing & Sections Scan — {screen} / {tab} (`{route}`)

Deep-scan this tab for billing leakage and nested section chrome: wire every financial action into Billing, and keep titled sections flat (siblings only—never nested).

## Context

- Screen inventory: `{screen_inv}` (read-only reference for reachable controls; do not modify).
- Target tab: **{tab}** (`{slug}`).
- Feature code: `{feature}`
- Module entitlement: `{module}`
- Billing system of record: `frontend/lib/features/billing/`, `backend/src/modules/billing/`, `backend/src/lib/billing/` (clinical-request billing, price-resolver, coverage-split, financials, realtime).
- Payment methods: facility-enabled subset of shared validators (`billingPaymentMethods`); full set in shared rules.
- Section chrome: `AppScreenSection`, titled `AppSectionPanel`, `AppWorkspaceDetailPanel` (and wrappers). Flat-section rules in shared rules.
- Financial focus for this tab: {focus}
- Shared rules: `prompts/billing-and-sections/_shared-rules.md`. Follow `prompts/.cursor/prompt.mdc`.
- Permissions remain enforced (`prompts/ui-permissions/`); do not weaken gates while wiring Billing or flattening sections.

## Requirements

1. Inventory every action reachable from this tab (chrome, rows, next-actions, detail, nested dialogs/workflows) that can request a paid service/product, collect payment, issue/generate an invoice, take a deposit/prepayment, refund, reverse, adjust, write off, waive, discount, issue a credit note, split insurance/co-pay, or change an outstanding balance. Classify each as create-charge, settle, adjust, reverse, defer, or not-billable (explicit `NOT_BILLED` / `NOT_REQUIRED` / `NO_CHARGE` with audit).
2. For each billable action, verify frontend and backend both call shared Billing APIs/services (no parallel cash ledgers, local-only paid flags, or module-private amount fields that never post). Wire gaps through existing billing controllers, clinical-request billing, receive-payment, adjustment, and claims handoff paths—reuse, do not fork.
3. Enforce realtime consistency: successful mutations must create/update Billing records immediately; UI lists, badges, payment gates, and balances on this tab must reflect backend state without manual refresh (providers/realtime/invalidation already used by Billing).
4. Apply supported payment methods end-to-end where collection occurs: validate method, amount, idempotency keys, partial payments, refunds/reversals, and reconciliation so duplicates and orphan receipts cannot occur.
5. Close leakage classes on this tab: missing invoices, unbilled fulfilled services, double charges, unpaid required care progressing when policy forbids, discharge/dispense without clearance, and claim settlements that never update patient responsibility.
6. UX: keep payment/billing affordances clean—minimal copy, only task-needed amounts/status/method, progressive disclosure for ledger detail, consistent design-system payment dialogs; remove redundant pay/issue entry points that duplicate Billing.
7. Preserve authorized UI states: permission-filtered chrome, loading, empty, error/retry, validation, success, and visible feedback. Honor RBAC ∩ subscription ∩ ABAC; unauthorized financial controls must not render.
8. Flat sections: inventory every section on this tab and dialogs from it; un-nest so no section contains another—siblings only under non-section parents (`Column`/`Row`/`Wrap`/`Flex`/workspace body). Identify content that needs sectioning; wrap each group without nesting; prefer promoting nested sections to siblings.
9. Add/update tests under `{test_feature}/` and `backend/src/tests/` proving (a) billable action posts a Billing record, (b) no bypass, (c) payment status parity with Billing, (d) idempotent replay, (e) unauthorized users cannot collect/adjust, (f) no section-in-section nesting on authorized UI. Cover integration, reuse, authorization, sync, UI states, one mobile + one desktop viewport, light + dark.

## Constraints

- Scope: this tab’s UI tree, nested dialogs opened from it, and the backend handlers those actions call. Do not redesign unrelated workspaces.
- Do not create, edit, delete, or regenerate any file under `screens/` (read-only inventory).
- Reuse Billing module services, clinical-request billing, price-resolver, coverage-split, receive-payment/adjustment dialogs, and feature billing helpers; no second billing engine.
- Reuse existing section chrome (`AppScreenSection`, titled `AppSectionPanel`, `AppWorkspaceDetailPanel`); do not invent a parallel section widget.
- Optional enhancements: none. Do not expand into unrelated refactors.
- Theme tokens; responsive mobile/tablet/desktop; backend RBAC/ABAC authoritative; no secrets in tests.
- Follow `.cursor/flows/*` ownership: Billing owns payment; clinical modules must not invent cashier logic.

## Acceptance Criteria

- AC1 (Req 1): Every financially relevant atom on this tab is inventoried and classified (billable vs explicit not-billable).
- AC2 (Req 2-5): No billable action bypasses Billing; fulfilled paid services have traceable invoice/payment/adjustment rows; duplicates and leakage paths identified in the scan are fixed.
- AC3 (Req 3-4): After mutations, this tab and Billing show the same payment/balance status without manual refresh; supported methods work for collect/refund/reconcile where applicable.
- AC4 (Req 6-7): Payment UX stays minimal and consistent; unauthorized financial controls absent; loading/empty/error/success/validation/feedback remain observable.
- AC5 (Req 8): No nested sections on this tab; content that needs sectioning lives in sibling sections under non-section layout parents.
- AC6 (Req 9): Frontend and backend tests prove posting, no-bypass, cross-module status parity, idempotency, authorization, and flat (non-nested) section layout for representative flows on this tab.

## Relevant Files

{relevant_lines}
- Matching `backend/src/tests/` for handlers touched by this tab
"""


SHARED_RULES = """# Billing & Sections — Shared Rules

Canonical rules for every prompt under `prompts/billing-and-sections/`. Tab prompts refine financial and section focus; they must not contradict this file or `prompts/.cursor/prompt.mdc`.

## Prompt compliance (`prompts/.cursor/prompt.mdc`)

Every tab prompt must:

- Stay under 1001 words; begin with an H1 and a one-sentence objective.
- Include `Context`, `Requirements`, `Constraints`, `Acceptance Criteria`, and `Relevant Files`.
- Number requirements; make acceptance criteria observable and trace each to numbered requirements (e.g. `AC2 (Req 3)`).
- Use imperative language; put shared definitions here—tab prompts reference this file instead of restating everything.
- State `Optional enhancements: none` unless a tab truly needs a named, non-blocking enhancement.
- Name permission, loading, empty, error, success, validation, and visible-feedback states for authorized paths.
- Name verification: frontend + backend tests covering integration, reuse, authorization, synchronization, UI states, viewports, themes, and flat sections.

## Objectives

1. Every financially relevant action across HMS must create, update, settle, or reconcile a record in the **Billing** module. Module-local “paid” flags without a Billing ledger entry are defects.
2. Titled **section** chrome must stay flat: sections may be siblings under a layout parent, never nested inside another section.

## Financial action classes

| Class | Examples | Must result in |
| --- | --- | --- |
| Create charge | Order lab/radiology/pharmacy/consult/procedure/bed/day, mortuary fees | Invoice line(s) via Billing / clinical-request billing |
| Settle | Receive payment, co-pay collect, deposit apply | Payment row + recalculated balances |
| Adjust | Discount, waive, write-off, credit note, price correction | Adjustment with approval when required |
| Reverse | Refund, payment reversal, void invoice, dispense return | Reversal/credit linked to original; no orphan negatives |
| Defer | Emergency deferral, pay-later gate | Explicit outstanding / deferred status still in Billing |
| Not billable | True no-charge protocol, internal ops | Audited `NOT_BILLED` / `NOT_REQUIRED` / `NO_CHARGE` |

## System of record

- Patient/clinical revenue: `backend/src/modules/billing/` + `backend/src/lib/billing/*`.
- Request-time clinical charges: `clinical-request-billing.js` (idempotent).
- Pricing: `price-resolver.js`. Insurance splits: `coverage-split.js`. Money math: `financials.js`.
- Frontend canonical UX: billing workspace dialogs + shared helpers (`clinical_request_billing_*`, `patient_billing_quick_dialog`, pharmacy/OPD billing helpers).
- Commercial SaaS invoices (subscriptions) stay on the subscriptions invoice path and must not corrupt patient ledgers.

## Payment methods

Normalize with shared validators. Full set: `CASH`, `CREDIT_CARD`, `DEBIT_CARD`, `PREPAID_CARD`, `GIFT_CARD`, `VOUCHER`, `BANK_CHECK`, `MOBILE_MONEY`, `BANK_TRANSFER`, `INSURANCE`, `OTHER`. UI exposes facility-enabled subset (`billingPaymentMethods`). Collection, refund, and reconciliation must accept the same normalized methods.

## Consistency rules

- Backend remains authoritative; frontend hides unauthorized financial controls (see `prompts/ui-permissions/_shared-rules.md`).
- Post-mutation sync is mandatory: lists, gates, badges, and balances update without manual refresh.
- Idempotency keys required on payment and charge creation to prevent duplicates.
- Do not duplicate Billing logic inside clinical modules; call shared services.
- Flow ownership in `.cursor/flows/*` still applies (e.g. Billing owns payment gates; ICU clinical actions are not cashier-driven).

## Screen inventories (read-only)

- `screens/*.md` are read-only inventories of reachable controls.
- Do **not** create, edit, delete, rename, or regenerate any file under `screens/`.
- Implement billing and section-layout changes in frontend/backend/tests only; leave inventories unchanged even if they look stale.

## Leakage checklist (every tab)

1. Fulfilled service with no invoice line
2. Payment taken outside Billing
3. Refund/adjustment without ledger row
4. Insurance remittance not applied to patient balance
5. Discharge/dispense/proceed despite unpaid required charges (unless deferred in Billing)
6. Double charge from retry or dual UI entry points
7. Balance shown in module UI ≠ Billing balance

## Flat sections (no nesting)

Section components are titled chrome that wraps a content region:

- `AppScreenSection`
- Titled `AppSectionPanel` (title set)
- `AppWorkspaceDetailPanel`
- Feature wrappers that build any of the above

Rules:

- A section’s child tree must **not** contain another section component.
- Sibling sections may align vertically, horizontally, in grids, or responsive wraps under a **non-section** parent (`Column`, `Row`, `Wrap`, `Flex`, workspace/dialog body).
- Inventory untitled content groups that deserve titled chrome; wrap each in one section without nesting.
- Prefer promoting nested sections to siblings over collapsing distinct groups into one opaque section.
- Lists, tables, form fields, chips, and untitled `AppContentPanel` / tone panels inside a section are fine; nested *sections* are not.
- Untitled `AppSectionPanel` / `AppContentPanel` used only as tone/padding chrome (no title) are not sections for nesting rules—but do not use them to smuggle nested titled sections.

## Verification (every tab prompt)

Tests must prove posting, no-bypass, status parity, idempotency, authorization, and flat sections, plus:

- Integration with Billing routes/services
- Reuse of shared billing helpers (no second engine)
- Authorization (RBAC ∩ subscription ∩ ABAC)
- Post-mutation synchronization / realtime
- Authorized UI states
- Representative mobile and desktop viewports
- Light and dark themes
- Widget-tree / finder checks that no section contains another section on this tab

## Related

- `prompts/.cursor/prompt.mdc`
- `prompts/ui-permissions/_shared-rules.md`
- `.cursor/api-contract.mdc`, `.cursor/flows/*`
- `backend/src/lib/billing/`
- `frontend/lib/features/billing/`
- `frontend/lib/shared/layout/app_screen_section.dart`
- `frontend/lib/shared/components/app_content_panel.dart`
- `frontend/lib/shared/layout/app_workspace.dart`
"""


def main() -> None:
    metas: list[dict[str, str]] = []
    for path in sorted(SRC.rglob("*.md")):
        meta = _parse_source(path)
        if meta:
            metas.append(meta)

    if len(metas) < 100:
        raise SystemExit(f"Expected ~154 tabs, found {len(metas)}")

    # Clean destination tab files but keep structure rebuildable.
    if DST.exists():
        for old in DST.rglob("*.md"):
            old.unlink()

    DST.mkdir(parents=True, exist_ok=True)
    (DST / "_shared-rules.md").write_text(SHARED_RULES, encoding="utf-8")

    readme_rows: list[tuple[str, str, str]] = []
    for meta in metas:
        out_dir = DST / meta["folder"]
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{meta['stem']}.md"
        body = render_prompt(meta)
        words = len(re.findall(r"\b\w+\b", body))
        if words > 1000:
            raise SystemExit(f"{out_path} is {words} words (>1000)")
        out_path.write_text(body, encoding="utf-8")
        readme_rows.append((meta["screen_name"], meta["tab_label"], meta["rel"]))

    # Prefer the curated ui-permissions README order when available.
    order_path = SRC / "README.md"
    order: list[str] = []
    if order_path.exists():
        for line in order_path.read_text(encoding="utf-8").splitlines():
            m = re.search(r"\| `([^`]+)` \|", line)
            if m:
                order.append(m.group(1))
    rank = {rel: i for i, rel in enumerate(order)}
    readme_rows.sort(key=lambda row: (rank.get(row[2], 10_000), row[2]))

    readme = [
        "# Billing & Sections Prompts",
        "",
        "Per-tab prompts that (1) deep-scan payment and billing workflows and",
        "wire every financially relevant action into the Billing module, and",
        "(2) keep titled UI sections flat—siblings only, never nested.",
        "Shared rules: [`_shared-rules.md`](_shared-rules.md).",
        "Every prompt must follow [`../.cursor/prompt.mdc`](../.cursor/prompt.mdc).",
        "",
        "Mirror of the `prompts/ui-permissions/` tab inventory. Run via",
        "`python run_billing_and_sections_prompts.py` (one folder at a time,",
        "up to 10 concurrent prompts, 2 iterations per folder), or one prompt",
        "at a time with the target tab’s file as the agent instruction.",
        "",
        "## Index",
        "",
        "| Screen | Tab / surface | Prompt |",
        "| --- | --- | --- |",
    ]
    for screen, tab, rel in readme_rows:
        readme.append(f"| {screen} | {tab} | `{rel}` |")
    readme.append("")
    readme.append(f"Total prompts: **{len(readme_rows)}**")
    readme.append("")
    (DST / "README.md").write_text("\n".join(readme) + "\n", encoding="utf-8")
    print(f"Wrote {len(metas)} tab prompts + shared rules + README -> {DST}")


if __name__ == "__main__":
    main()
