# Pharmacy — Catalog and Stock Dialog Bug Fix

## Objective

Fix a **modal lifecycle bug** on the Pharmacy workbench (`/pharmacy`): clicking **Catalog and stock** leaves the page unresponsive. The dialog does not appear, dismissal leaves a blank white screen, and only a full page refresh restores interactivity.

---

## Bug Report

### Environment

| Item | Value |
| ---- | ----- |
| Module | Pharmacy |
| Route | `/pharmacy` |
| Platform | Web (reproduced at `127.0.0.1:5201/pharmacy`) |
| Trigger | Header action **Catalog and stock** (`pharmacyCatalogPanelTitle`) |

### Steps to reproduce

1. Open the Pharmacy workbench with at least one order visible in the queue table.
2. Click **Catalog and stock** in the workspace toolbar (overflow section or promoted inline action).
3. Observe the page.

### Actual behavior

1. The underlying workbench becomes **inactive** (modal barrier / focus trap engages).
2. The **Catalog and stock** dialog (`AppDialog` titled "Catalog and stock") **does not render**.
3. Pressing **Escape** removes the dimmed overlay but the page turns **white** and remains **non-interactive**.
4. A **full browser refresh** is required to restore the workspace.

### Expected behavior

1. **Catalog and stock** opens an `AppDialog` containing `PharmacyCatalogPanel` (drugs, formulary, inventory, storage tabs).
2. The dialog is visible, scrollable, and closable via the close button, Escape, or barrier tap.
3. After dismissal, the Pharmacy workbench is fully interactive with no orphaned route or barrier.
4. The same fix applies to related entry points that call `openPharmacyCatalogDialog` (e.g. inventory summary alerts, storage tab shortcut).

---

## Relevant Code

| File | Role |
| ---- | ---- |
| `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` | Toolbar action invokes `openPharmacyCatalogDialog` |
| `frontend/lib/features/pharmacy/presentation/pharmacy_catalog_dialog.dart` | `showAppDialog` + `AppDialog` + `Consumer` wrapper |
| `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` | Dialog body |
| `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` | `prepareCatalogTab` / catalog data refresh |
| `frontend/lib/shared/components/app_dialog.dart` | `AppDialog`, `showAppDialog` (focus restore, barrier) |

**Likely failure modes to investigate:**

- Dialog route pushed but content fails to build (silent widget error or zero-size shell).
- `prepareCatalogTab` triggering a controller emit/refresh that disposes or rebuilds the dialog host before first frame.
- `Consumer` inside `showAppDialog` losing provider scope or context on web.
- Escape/barrier popping the route without cleaning up barrier or focus state (orphaned `ModalRoute`).
- Mismatch between `initialMaximized: false`, `scrollable: true`, and desktop shell height (see existing `app_dialog_test.dart` catalog scenario).

---

## Fix Requirements

1. **Root cause** — Identify and fix why the catalog dialog does not render while the modal barrier activates.
2. **Clean dismissal** — Escape, close button, and barrier tap must fully pop the dialog and restore workbench interactivity.
3. **No regressions** — Preserve modal-first pattern per [prompts/18-pharmacy-module-prompt.md](prompts/18-pharmacy-module-prompt.md); do not navigate to a new route for catalog/stock.
4. **All entry points** — Verify toolbar button, overflow **Storage** shortcut, and inventory alert shortcuts.
5. **Responsive** — Dialog works on mobile, tablet, and desktop breakpoints.

---

## Acceptance Criteria

- [ ] Clicking **Catalog and stock** shows the dialog with title, tabs, and content.
- [ ] Dialog can be closed by close button, Escape, and barrier tap; workbench is immediately usable.
- [ ] No white-screen or frozen state after open or dismiss.
- [ ] No full-page refresh needed to recover.
- [ ] Existing `app_dialog_test.dart` scenarios pass; add a widget test for `openPharmacyCatalogDialog` if none exists.

---

## Quality Gate

From `frontend/`:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test test/shared/components/app_dialog_test.dart
flutter test test/features/pharmacy/
```

Manual smoke test on web at `/pharmacy`: open dialog → interact with a tab → close → confirm queue table remains clickable.
