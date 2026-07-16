# Dialog inventory audit

Audit every dialog in this Flutter HMS app (`frontend/`). Cover all features, shared modules, and workspaces—do not skip areas.

## Scope — what counts as a dialog

Include anything that presents a modal overlay, for example:
- `showDialog` / `showGeneralDialog` / `showModalBottomSheet` (if used as a dialog-like sheet)
- Wrappers such as `showAppDialog`, `AppDialog`, confirm/alert helpers, and similar shared APIs
- Feature-specific `show*Dialog` entry points and custom dialog widgets

Exclude non-modal surfaces (full pages, drawers, inline panels) unless they are implemented as dialogs.

## Deliverables

1. **Inventory** — Complete list of dialogs (definitions, not call sites as separate entries).
2. **Grouping** — Organize by primary purpose, e.g.:
   - Patient / encounter flow
   - Detail viewers (patient, encounter, notification, etc.)
   - Actions / confirmations
   - Forms / editors
   - Alerts / errors / system
   - Other (name the group)
3. **Definition site** — For each dialog, note where it is defined (shared component vs feature/workspace-local).
4. **Base / root dialogs** — Identify reusable bases (e.g. `AppDialog`) and which dialogs extend or compose them.
5. **Reuse** — If a dialog is used in multiple places, keep **one** inventory entry and list all call sites under it. Do not duplicate definitions.

## Per-dialog fields

For each entry, capture:
- Name / symbol (widget or `show*` function)
- Purpose (one short sentence)
- Category (from grouping above)
- Defined in (file path)
- Base / shared vs custom
- Extends / uses (base dialog or helper, if any)
- Used from (file paths or screens; “—” if only defined)

## Goal

Answer: how many dialogs exist, what each is for, where each is defined and used, and which are shared, custom, or base components.
