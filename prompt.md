# Clinical Request & Radiology Workflow — UI/UX Refinement Prompt

## Objective

Refine **clinical request dialogs** and the **Radiology workflow detail view** so staff can see and confirm service prices **at the moment a request is made**, and so the radiology floor/reporter experience is clearer and more polished.

**Core billing principle:** Billing is incorporated **inside the requesting module's modal dialog**—not as a separate step in the lab, radiology, or pharmacy workbench. When someone orders a lab test, imaging study, or prescription, they see per-item pricing and a running total before submitting.

Preserve existing architecture (`Clinical*ActionDialog`, `RadiologyWorkspaceController`, `AppWorkspace*` components, l10n keys). Extend rather than replace unless a component clearly blocks the goals below.

---

## Scope

| In scope | Out of scope |
|----------|--------------|
| Shared clinical request dialogs (lab, radiology, pharmacy/prescription) | Unrelated modules (IPD admissions, referrals, etc.) unless they share the same request-dialog pattern |
| Radiology workspace create-order dialog (`_CreateOrderForm`) | Standalone billing-workspace-only flows as the primary entry point |
| Radiology workflow detail panel and operational dialogs | Backend API redesign unless required for catalog pricing or charge creation |
| Read-only payment status on order/workflow detail views | New branding or color palette outside the app theme |

---

## 1. Request-Time Billing — Lab, Radiology & Pharmacy

**Problem:** Request dialogs let users select tests, studies, or medicines but show **no pricing**. Workflow detail views then display a passive **"Billing gate unavailable"** alert with no cost context. Staff cannot tell patients what they will pay before the request is placed.

**Principle:** Price visibility and charge initiation belong in the **request modal**, at order creation time, regardless of which module opened the dialog (Clinical workspace, OPD flow actions, Lab workspace, Radiology workspace).

### 1.1 Shared billing panel (new shared component)

Introduce a reusable **`ClinicalRequestBillingPanel`** (or equivalent) modelled on `OpdConsultationBillingBreakdownPanel` (`shared/opd_actions/opd_consultation_billing_breakdown.dart`):

| Element | Behaviour |
|---------|-----------|
| **Line items** | One row per selected test, study, or medicine: name, quantity, unit price, line total |
| **Subtotal / total** | Running total updates as items are added or removed |
| **Currency** | Use tenant/facility currency from catalog or billing API |
| **Payment status** | On edit flows: show Paid / Partial / Unpaid / Not billed |
| **Pay now (optional)** | When permissions allow (`AppPermissions.billingWrite` or equivalent), expose **Record payment** inline before submit |
| **Submit without payment** | Allow request submission with **Bill later** when policy permits; persist `paymentStatus` on the order |

Panel placement: **sticky footer or right column** inside each request dialog, always visible while selecting items.

### 1.2 Laboratory — `ClinicalLabOrderActionDialog`

**Entry points:** Clinical workspace (`_openLabDialog`), Lab workspace (`_openCreateLabOrderDialog` / `_openEditLabOrderDialog`), OPD flow actions.

**Requirements:**

- Show **unit price** beside each test/panel in the catalog picker and in the selected-items list.
- Display **`ClinicalRequestBillingPanel`** with line totals for all selected `labTestIds` and `labPanelIds`.
- On submit (`onRequest` / `onUpdate`), include billing payload in `orderContext.toPayload(...)` when payment is recorded (amount, method, reference)—coordinate with backend contract.
- When editing an existing order, pre-populate billing panel from order payment fields.

**Acceptance criteria:**

- [ ] Clinician sees total lab cost before confirming the request.
- [ ] Per-test and per-panel prices are visible in both catalog and selected lists.
- [ ] Payment can be captured in-dialog or deferred with explicit status.

### 1.3 Radiology — `ClinicalRadiologyOrderActionDialog` & `_CreateOrderForm`

**Entry points:** Clinical workspace (`_openRadiologyDialog`), Radiology workspace (`_showCreateOrderDialog` / `_CreateOrderForm`).

**Requirements:**

- Show **study price** from radiology catalog (`ClinicalActionCatalogOption`) when adding to `_RadiologySelectedRequestsPanel`.
- Add **`ClinicalRequestBillingPanel`** to both dialogs; total reflects all pending studies.
- On submit, attach billing/charge data to the create-order payload so `order.hasBillingGate` and `paymentStatus` are populated immediately.
- In the radiology workflow detail view, **display** payment status read-only in `_WorkflowSummarySection`—do **not** add a separate "Bill procedure" action; link to edit order only if amendment is supported.

**Acceptance criteria:**

- [ ] Requester sees imaging cost before the order is created.
- [ ] "Billing gate unavailable" no longer appears for orders created through the updated dialog.
- [ ] Workflow detail reflects payment status without requiring a second billing visit.

### 1.4 Pharmacy — `ClinicalPrescriptionActionDialog`

**Entry points:** Clinical workspace (`_openPrescriptionDialog`), OPD flow actions.

**Requirements:**

- Show **unit price** per drug in the catalog dropdown and on each `_PrescriptionLineFormState` card (quantity × unit price = line total).
- Add **`ClinicalRequestBillingPanel`** summarizing all prescription lines.
- Support billing at prescribe time (pay now) or bill-on-dispense if that matches pharmacy workflow—surface the chosen mode clearly in the dialog.
- Include billing fields in `controller.prescribe` payload when payment is taken upfront.

**Acceptance criteria:**

- [ ] Prescriber or clerk sees medicine costs before submitting the prescription.
- [ ] Multi-line prescriptions show an accurate running total.
- [ ] Pharmacy dispense workflow can read existing payment status when applicable.

### 1.5 Catalog pricing data

- Resolve prices from catalog entities (`LabCatalogItem`, radiology catalog options, drug reference data) or a lightweight **price lookup API** if not yet on catalog DTOs.
- Handle **missing price** gracefully: show "Price not set" with a warning badge; block submit or allow override per tenant policy.
- Reuse `billing_entities.dart` / `unitPrice` conventions where charges are persisted.

### 1.6 Workflow detail views (read-only reflection)

Lab order detail, radiology workflow detail, and pharmacy dispense views should **reflect** billing state created at request time:

- Human-readable **Paid / Partial / Unpaid / Not billed** in summary sections.
- No primary "Bill tests" / "Bill procedure" buttons on detail panels—the request dialog is the billing entry point.
- Optional **Amend charges** only when editing an open order through the same request dialog pattern.

---

## 2. Perform Study — Simplify & Auto-fill

**Problem:** The **Perform imaging study** dialog (`_showStudyDialog` / `_StudyForm`) asks for optional modality, performed-at, and notes, but technologists mainly need a one-step **mark as performed** action. Performed date/time does not auto-populate.

**Requirements:**

- Default **Performed at** to the current local date/time on dialog open; still allow override.
- Pre-fill **Modality** from the order (`order.normalizedModality`); hide or collapse the field when it matches the order.
- Reduce visual noise: do not repeat "(optional)" on every label—use helper text or section description once.
- After save, the **Studies and assets** section must show the new study immediately (controller refresh already exists—verify UI reflects it without manual reload).

**Acceptance criteria:**

- [ ] Single-click **Perform study** flow with sensible defaults.
- [ ] Performed timestamp appears in Studies section and workflow timeline without page refresh.

---

## 3. Workflow Progress — Clarity & Navigation

**Problem:** `_WorkflowProgressSection` displays six steps in a static grid. Steps are not clickable, the active step is only mildly distinct, and users cannot return to an earlier step.

**Requirements:**

- Make each `_WorkflowStepTile` **interactive** when the user has permission for that step:
  - Clicking a completed or current step scrolls to—or expands—the relevant section (Request details, Studies and assets, Report, Doctor review).
  - Visually distinguish **completed**, **current**, and **upcoming** states (stronger border/weight on current; connecting vertical timeline line on compact layouts).
- Add short **step descriptions** (tooltip or subtitle) so "Review study details" vs "Perform imaging study" is unambiguous.
- Collapse completed steps on wide layouts into a compact summary row to reduce vertical space; expand on demand.

**Acceptance criteria:**

- [ ] User can navigate back to any completed step from the progress strip.
- [ ] Current step is immediately obvious at a glance.
- [ ] Progress section uses less vertical space on desktop when steps are complete.

---

## 4. Workflow Summary — Purpose & Layout

**Problem:** `_WorkflowSummarySection` sits between progress and request details without clear purpose; metadata (ordered at, modality, payment) feels disconnected from actions.

**Requirements:**

- Rename or subtitle the section to **Order metadata** (or merge into the patient context header) so its role is obvious.
- Display only high-signal fields in the summary; move duplicate fields (order ID, study name already in header) out.
- Use a responsive **key-value grid** with consistent label/value typography: muted labels, semibold values.
- Style **"Not available"** placeholders (`profileUnknownValue`) as subdued italic secondary text—not the same weight as real data.
- Show **payment status** set at request time (from §1.6); no duplicate billing actions here.

**Acceptance criteria:**

- [ ] No duplicate order/study info between header and summary.
- [ ] Summary reads as contextual metadata, not a second header.

---

## 5. Report Section — Real-time Updates & Inline Editing

**Problem:** Saving a draft via **Draft radiology report** (`_showReportDialog`) does not update `_ReportingSection` in real time; users must dismiss and re-open to see changes. Report actions are icon-only and hard to discover. The report preview is read-only.

**Requirements:**

- After `createDraft` / `updateDraft` succeeds, **immediately refresh** `selectedWorkflow` in `RadiologyWorkspaceController` and rebuild `_ReportingSection` without closing the detail panel.
- Add **inline edit** for draft reports directly in the Report panel (expand `AppReportPreviewPanel` or replace with an editable area when `latestDraftResult` exists and `canCreateDraftResult`).
- Promote primary actions from icon-only to labeled buttons where space allows: **Draft report**, **Release report**, **Request finalization**.
- Remove redundant default text in **Report narrative** (e.g. stray `"Findings:"` prefix when a dedicated Findings field exists).
- Show **live preview** of formatted report (findings + impression + narrative) as the user types in the draft dialog.

**Acceptance criteria:**

- [ ] Saving draft updates the Report section content within 1 render cycle.
- [ ] Draft text is editable from the main panel without opening the dialog (dialog remains for focused entry).
- [ ] Released vs draft status badges update immediately after save/release.

---

## 6. Studies & Assets — Upload & Preview

**Problem:** When no study exists, `_StudiesSection` shows an empty state with no upload affordance. After perform study, there is no obvious way to add images. Technologists cannot preview the report while working.

**Requirements:**

- In the empty state, show a **Perform study** or **Upload images** CTA (disabled with explanation if prerequisites are not met).
- After a study exists, surface `_StudyBlock` upload controls prominently (drag-and-drop zone, file picker, supported formats already defined: JPEG/PNG/WebP).
- Add a **Report preview** collapsible panel in the Studies section (read-only) so floor staff can see draft/released report text without scrolling to the Report section.
- Thumbnail grid for uploaded assets with remove/sync actions visible without extra clicks.

**Acceptance criteria:**

- [ ] User can upload images immediately after study is performed.
- [ ] Empty state includes a clear next action.
- [ ] Technologist can view current report preview from Studies section.

---

## 7. Role Separation — Technologist vs Reporter

**Problem:** One flat layout serves both the person who performs imaging and the person who writes the report.

**Requirements:**

- Introduce a **role toggle** or **view mode** (persisted per session) with two presets:
  - **Imaging floor:** emphasizes Workflow progress (perform + upload steps), Studies and assets, billing status, report preview. De-emphasizes or hides release/finalization actions.
  - **Reporting:** emphasizes Request details, Report section (draft/edit/release), references, doctor review. De-emphasizes perform-study controls.
- Default view inferred from permissions (`canWork`, `canRequest`) when possible.
- Section order in `_RadiologyDetailBody` should reorder based on active view mode.

**Acceptance criteria:**

- [ ] Each role lands on a focused layout within 0 extra clicks when permissions allow.
- [ ] Actions irrelevant to the current role are hidden, not merely disabled.

---

## 8. Doctor Review & Timeline

**Problem:** `_DoctorReviewPanel` shows status only—no action. `_TimelineSection` uses plain radio icons with no connector line; events may appear out of chronological order.

**Requirements:**

- Add **Open report** and **Acknowledge review** (or equivalent) buttons to `_DoctorReviewPanel` when `canRequestFinalization` / attestation applies.
- Render timeline as a **vertical connected timeline** (line + nodes); sort events **newest first** or **oldest first** consistently (pick one, document in UI).
- Timestamp formatting via existing `_formatDateTime` / `AppFormatters.dateTime`.

**Acceptance criteria:**

- [ ] Doctor review panel has at least one clear call-to-action.
- [ ] Timeline is visually connected and chronologically consistent.

---

## 9. Visual Polish (Look & Feel)

Apply across request dialogs, radiology detail view, and operational dialogs:

| Area | Improvement |
|------|-------------|
| **Request dialogs** | Two-column layout on wide screens: item picker left, selected items + billing panel right; single column on compact |
| **Billing panel** | Inset `surfaceContainerLowest` background, bold total row, aligned currency formatting via `AppFormatters` |
| **Section cards** | Subtle elevation or `surfaceContainerLow` background; consistent `borderRadius` and padding via theme spacing |
| **Patient context header** | Harmonize status chips (Completed, Billing, Ready for review)—consistent icon size, tone, and wrap behavior |
| **Typography** | Stronger label/value hierarchy in `_DetailLine`; reduce wide label-value gaps on desktop |
| **Modals** | Increase vertical spacing between fields; labels above inputs for multi-line fields; primary action right-aligned in footer |
| **Empty states** | Illustration + title + body + CTA button; `minHeight` without excessive whitespace |
| **Action buttons** | Group header actions (Perform study, Draft report, Release report) with spacing; primary action visually dominant |
| **Workflow step tiles** | Rounded corners, clearer active-state ring, optional step number badge |
| **Report preview box** | Light inset background, monospace or body-large for clinical text, max-height with scroll |

Do not introduce one-off colors; use `Theme.of(context).colorScheme` and existing `AppWorkspaceStatusTone` values.

---

## 10. Dialog-Specific Fixes

### Perform imaging study (`_StudyForm`)
- Auto-fill performed-at; collapse optional fields.
- Footer: Cancel (text) + **Perform study** (primary with icon).

### Draft radiology report (`_ReportForm` / `_showReportDialog`)
- Increase spacing between Findings, Impression, and Report narrative fields.
- Sync narrative field with findings/impression on save.
- On successful save: close dialog **and** refresh detail panel.

### Release report (`_showFinalizeDialog`)
- Show read-only summary of findings/impression above release notes.
- Disable release if draft is empty or unchanged from last release.

---

## Implementation Notes

### Request dialogs (billing)
- `shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`
- `shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart`
- `shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart`
- `features/radiology/presentation/pages/radiology_workspace_page.dart` (`_CreateOrderForm`)
- Call sites: `clinical_workspace_page.dart`, `lab_workspace_page.dart`, `opd_flow_actions_dialog.dart`

### Radiology workflow (operations)
- Primary file: `radiology_workspace_page.dart` (~5k lines)—extract sub-widgets only when it improves readability.
- Controller: `radiology_workspace_controller.dart` — ensure all mutations call `_refreshSelectedWorkflow()` or equivalent.

### Billing reference
- `shared/opd_actions/opd_consultation_billing_breakdown.dart` — UI pattern for totals panel
- `features/billing/domain/entities/billing_entities.dart` — `unitPrice` conventions

- All user-visible strings via `app_en.arb` (and sibling locale files).
- Test on **web desktop** (~1280px) and **compact** (<640px) per existing `LayoutBuilder` breakpoints.

---

## Definition of Done

1. Lab, radiology, and pharmacy **request dialogs** show per-item prices and a running total; payment can be captured or deferred at submit.
2. Workflow detail views display payment status read-only—no separate billing step required after a properly submitted request.
3. Perform study is a fast, defaulted action; assets upload is discoverable.
4. Workflow steps are navigable; summary/metadata section is purposeful.
5. Report drafts update the UI immediately; inline editing is available.
6. Technologist and reporter views are distinguishable.
7. Doctor review and timeline are actionable and visually coherent.
8. Overall UI feels intentional: spacing, hierarchy, empty states, and modals match the quality of other HOSSPI workspace modules.
