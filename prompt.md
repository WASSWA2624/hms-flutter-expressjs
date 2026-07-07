# Pharmacy — Catalog and Stock Dialog (Web Testing Prompt)

## Objective

Fix and verify the **Catalog and stock** modal on the Pharmacy workbench (`/pharmacy`) so it opens reliably on **web**, dismisses cleanly, and leaves the queue table interactive. Cover the fix with **unit**, **integration**, and **Patrol E2E** tests run **exclusively on the web platform** (`chrome`).

**Reference:** [prompts/18-pharmacy-module-prompt.md](prompts/18-pharmacy-module-prompt.md) · [frontend/.cursor/testing.mdc](frontend/.cursor/testing.mdc)

---

## Bug Report (from production UI)

| Item | Value |
| ---- | ----- |
| Module | Pharmacy |
| Route | `/pharmacy` |
| Platform | **Web only** (`127.0.0.1:5201/pharmacy`) |
| Trigger | Toolbar action **Catalog and stock** |
| Login | `pharmacy@hosspi.com` (seeded demo) |

### Steps to reproduce

1. Open `/pharmacy` with the order queue loaded (patient rows visible).
2. Click **Catalog and stock** in the workspace toolbar (inline or overflow).
3. Observe the page.

### Actual (broken)

- Workbench becomes inactive (modal barrier / focus trap).
- **Catalog and stock** `AppDialog` does not render.
- Escape may remove the dim overlay but leave a white, non-interactive page.
- Full browser refresh required to recover.

### Expected

- `AppDialog` titled **Catalog and stock** opens with `PharmacyCatalogPanel` (Drugs, Formulary, Inventory, Storage tabs).
- Close via close button, Escape, or barrier tap restores full workbench interactivity.
- Same behavior for all `openPharmacyCatalogDialog` entry points (toolbar, inventory alerts, storage shortcut).

---

## UI Under Test (screenshot)

Pharmacy workbench at desktop width:

- **Toolbar:** primary dispense action + **Catalog and stock** secondary action.
- **Queue:** searchable table (`Patient`, `Order`, `Care location`, `Items`, `Dispense`).
- **Sidebar:** Pharmacy module selected; other modules visible.

---

## Relevant Code

| File | Role |
| ---- | ---- |
| `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` | Toolbar invokes `openPharmacyCatalogDialog` |
| `frontend/lib/features/pharmacy/presentation/pharmacy_catalog_dialog.dart` | `showAppDialog` + `AppDialog` host |
| `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` | Dialog body (tabs + catalog tables) |
| `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` | `prepareCatalogTab` / catalog data refresh |
| `frontend/lib/shared/components/app_dialog.dart` | Shared modal shell, focus restore, barrier |

**Known failure modes:** dialog route pushed but shell has zero size; `prepareCatalogTab` emit during first frame disposes host; `scrollable: true` + fixed-height content mismatch on web; orphaned `ModalRoute` after Escape.

---

## Test Strategy (web platform only)

| Layer | Tool | Target file(s) | What to assert |
| ----- | ---- | -------------- | -------------- |
| Unit | `flutter_test` | `test/features/pharmacy/data/`, `domain/`, helper tests | DTO mapping, query filters, pricing/print helpers |
| Widget | `flutter_test` + mocks | `test/features/pharmacy/presentation/pharmacy_catalog_dialog_test.dart` | `openPharmacyCatalogDialog` renders `CATALOG AND STOCK`, visible shell, close + Escape |
| Widget | `flutter_test` + mocks | `test/features/pharmacy/presentation/pharmacy_workspace_page_test.dart` | Toolbar **Catalog and stock** opens/closes dialog from full page |
| Integration | `integration_test` (desktop runner, web viewport) | `integration_test/pharmacy_catalog_dialog_test.dart` | Dialog open/dismiss on mocked workspace at 1440×900 |
| Web widget | `flutter_test` on **chrome** | `test/features/pharmacy/presentation/` | Same assertions compiled for web (Patrol complement) |
| E2E | **Patrol** on **chrome** | `patrol_test/pharmacy_flow_test.dart` | Real login as `pharmacy@hosspi.com`; catalog dialog open + close on seeded backend |
| Shared | `flutter_test` | `test/shared/components/app_dialog_test.dart` | Desktop scrollable catalog shell height scenario |

**Platform rule:** Flutter `integration_test` does not yet support `-d chrome`. Run integration suites on a desktop device (`-d windows` / `-d macos` / `-d linux`) with a desktop web viewport, and run `test/features/pharmacy/presentation/` with `-d chrome` plus Patrol for true web coverage.

---

## Fix Requirements

1. Restore reliable modal lifecycle in `pharmacy_catalog_dialog.dart` (no invisible barrier).
2. Call `prepareCatalogTab` synchronously in `initState`; watch controller state in `build`.
3. Do **not** set `scrollable: true` on the catalog dialog — use fixed-height `SizedBox` + `fillHeight` panel.
4. Ensure Escape, close, and barrier dismissal fully pop the route and restore focus.
5. Preserve modal-first pattern — no new routes for catalog/stock.

---

## Acceptance Criteria

- [ ] **Catalog and stock** shows dialog with title, tabs, and content on web.
- [ ] Dialog closes cleanly; queue table remains clickable without refresh.
- [ ] No white-screen or frozen state after open or dismiss.
- [ ] All web tests below pass.

---

## Quality Gate (from `frontend/`)

```powershell
# Unit + widget (VM — fast feedback)
flutter test test/features/pharmacy/
flutter test test/shared/components/app_dialog_test.dart

# Web widget compilation
flutter test test/features/pharmacy/presentation/ -d chrome

# Integration (desktop runner; web viewport inside test)
flutter test integration_test/pharmacy_catalog_dialog_test.dart -d windows

# Patrol E2E — web only (seeded backend on :3000 required)
.\tool\run_patrol_tests.ps1 -Target patrol_test/pharmacy_flow_test.dart -Device chrome
```

Manual smoke: open `/pharmacy` → **Catalog and stock** → switch a tab → close → confirm queue interaction.

---

## Deliverables

1. Root-cause fix in pharmacy catalog dialog and related modal code.
2. Widget + integration + Patrol coverage as specified above.
3. All applicable **web** tests green before merge.
