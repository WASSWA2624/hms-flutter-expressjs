# Lab Configurations — fixes and polish

## Context

In **Lab Configurations** (`/lab`), facility admins enable platform lab tests/panels, set unit prices (UGX), and customize reference ranges. Two related surfaces need work:

1. **Lab Configurations** — main Tests/Panels table (tenant + facility context, search, Laboratory filters, Enable test/panel, edit/delete).
2. **Enable lab offering** — modal to pick a platform catalog item and set the facility price before enabling it.

Relevant code: `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`, `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`.

---

## 1. Bug — edited unit prices do not persist

**Observed**

- **Tests:** Edit *Complete Blood Count* (CBC) — change unit price from **UGX 50,000** to **UGX 20**, save, then reopen or refresh. Price reverts to **50,000**.
- **Panels:** Edit *Abdominal Pain Panel* — change price (e.g. to **UGX 7,000**). Value may appear updated in the edit dialog but does not reliably persist after closing the dialog or switching Tests ↔ Panels.

**Expected**

- Saved unit prices persist across dialog close, tab switch (Tests/Panels), and page reload.
- The main table always reflects the last successfully saved price.

**Investigate**

- Edit/update payload and API call in `_LabTestConfigurationDialog` / `_LabPanelConfigurationDialog` (`onUpdate`, `_payload`, `_resolvedOfferingUnitPrice`).
- Whether the workspace controller refreshes stale catalog state after a successful update.
- Whether the table reads cached `unitPrice` instead of the server response.

**Acceptance**

- Edit CBC to UGX 20 → save → table shows UGX 20 → reopen edit dialog → still UGX 20 → reload page → still UGX 20.
- Same flow passes for at least one panel (e.g. Abdominal Pain Panel).

---

## 2. UX — currency display spacing

**Observed:** Unit price renders as `UGX50,000` with no space between the currency code and amount.

**Expected:** Readable spacing, e.g. `UGX 50,000` (consistent with other currency formatting in the app).

**Scope:** Unit price column in Lab Configurations Tests/Panels tables; any other lab-catalog price labels using the same formatter (`_formatCatalogUnitPrice` / `AppFormatters.currency`).

---

## 3. UX — table alignment and horizontal overflow

**Observed**

- **Lab Configurations table:** Extra whitespace before the first column (`#`); cell content is not left-aligned as expected.
- **Enable lab offering table:** Long test names (e.g. LOINC-style names) consume the first column and push other columns off-screen. No horizontal scroll.

**Expected**

- Remove unintended leading padding/margin so the index column and data columns align flush left.
- **Enable lab offering:** Truncate or ellipsis long names in the Test/Panel name column (keep full name in tooltip or on row expand if available).
- Enable **horizontal scrolling** when column content exceeds viewport width (both tables where applicable).

**Reference:** Main Lab Configurations already uses `AppListTable` with search/filters; Enable lab offering table in `_LabEnableOfferingDialog` currently has search only and `NeverScrollableScrollPhysics`.

---

## 4. Feature — Laboratory filters on Enable lab offering

**Observed:** The **Enable lab offering** modal only exposes **Table column settings**. The main Lab Configurations table includes **Laboratory filters** (category, result kind, etc.).

**Expected:** Add the same **Laboratory filters** control to the Enable lab offering dialog so users can narrow the platform catalog by category (e.g. Chemistry, Hematology) and other existing filter dimensions.

**Implementation hint:** Mirror the filter groups already wired in `lab_workspace_page.dart` (`showAdvancedFilterButton`, `filterGroups` for category/result kind) inside `_LabEnableOfferingDialog`’s `AppListTableSearch`, applying filters client-side to `_catalogItems` or server-side if the catalog search API supports filter params.

---

## Test plan

- [ ] Edit test price → persists after save, tab switch, and reload.
- [ ] Edit panel price → persists after save, tab switch, and reload.
- [ ] Currency shows as `UGX 50,000` (space after code).
- [ ] Lab Configurations table: no stray left whitespace; columns align correctly.
- [ ] Enable lab offering: long names truncated; horizontal scroll works; filters reduce rows by category.
- [ ] Existing lab workspace/controller tests updated or added where behavior changed.
