# Dialog inventory — Summary

[Index](README.md) · Source: [../prompt.md](../prompt.md)

## Summary

| Metric | Count |
| --- | ---: |
| **Unique dialog definitions** | **304** |
| Dialog widget classes (`*Dialog`, excl. bases) | 173 |
| Standalone openers (inline modal, no feature Dialog ctor) | 130 |
| Dialog-like modal bottom sheets | 1 |
| Shared (non-base) | 57 |
| Feature-custom | 247 |
| Named openers scanned (`show*` / `open*` / `_show*` / `_open*`) | 337 |
| Openers paired to a Dialog class (not double-counted) | 158 |

### By category

| Category | Count |
| --- | ---: |
| Forms / editors | 201 |
| Detail viewers | 52 |
| Patient / encounter flow | 41 |
| Actions / confirmations | 8 |
| Alerts / errors / system | 2 |

### By feature / shared area

| Area | Count |
| --- | ---: |
| `hr` | 42 |
| `billing` | 16 |
| `shared/clinical_actions` | 16 |
| `subscriptions` | 16 |
| `shared/opd_actions` | 15 |
| `shared/components` | 14 |
| `tenant_facility` | 14 |
| `claims` | 12 |
| `pharmacy` | 12 |
| `patients` | 11 |
| `radiology` | 11 |
| `nursing` | 10 |
| `access_admin` | 9 |
| `ipd` | 9 |
| `theater` | 9 |
| `icu` | 8 |
| `lab` | 8 |
| `communications` | 6 |
| `emergency` | 6 |
| `housekeeping` | 6 |
| `integrations` | 6 |
| `operations` | 6 |
| `physiotherapy` | 6 |
| `shared/lab_catalog` | 6 |
| `discharge` | 5 |
| `rooms_beds` | 5 |
| `reports` | 4 |
| `shared/radiology_catalog` | 3 |
| `biomedical` | 2 |
| `opd` | 2 |
| `reception` | 2 |
| `shared/actions` | 2 |
| `auth` | 1 |
| `clinical` | 1 |
| `mortuary` | 1 |
| `profile` | 1 |
| `shared/patient_actions` | 1 |

## Counting method

1. **Include** `*Dialog` widget classes and `show*` / `open*` / `_show*` / `_open*` openers that call `showAppDialog`, `showAppWorkspaceActionDialog`, `showAppWorkspaceMutationDialog`, `showGeneralDialog`, `showDialog`, or `showModalBottomSheet`.
2. **One inventory entry per definition.** If an opener constructs a feature `*Dialog` widget, only the class is counted; the opener is listed in that row's *Paired opener(s)*.
3. **Standalone openers** (inline `AppDialog` / confirm helpers with no feature Dialog constructor) are counted as their own entries.
4. **Base / root** primitives are documented separately and excluded from the unique-definition total.
5. Duplicate opener symbols across files keep the richest definition site (prefer `widgets/` / `*dialog*.dart`).
