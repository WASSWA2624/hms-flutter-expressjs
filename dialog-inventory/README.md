# Dialog inventory

Source of truth: [`../prompt.md`](../prompt.md). Scope: entire repo. UI dialogs are in `frontend/lib` only (no dialog UI in `backend/`).

## Contents

| File | Contents |
| --- | --- |
| [00-summary.md](00-summary.md) | Counts, category/feature breakdown, counting method |
| [01-base-dialogs.md](01-base-dialogs.md) | Root/shared dialog infrastructure (`AppDialog`, helpers) |
| [02-patient-encounter-flow.md](02-patient-encounter-flow.md) | Patient / encounter flow dialogs |
| [02-patient-encounter-flow-prompts.md](02-patient-encounter-flow-prompts.md) | Agent prompts (one per row) → [`../prompts/NN-*.md`](../prompts/) |
| [03-detail-viewers.md](03-detail-viewers.md) | Detail viewer dialogs |
| [03-detail-viewers-prompts.md](03-detail-viewers-prompts.md) | Agent prompts (one per row) → [`../prompts/detail-viewers/NN-*.md`](../prompts/detail-viewers/) |
| [04-actions-confirmations.md](04-actions-confirmations.md) | Action / confirmation dialogs |
| [05-forms-editors.md](05-forms-editors.md) | Form / editor dialogs |
| [06-alerts-system.md](06-alerts-system.md) | Alerts / errors / system dialogs |
| [07-notes.md](07-notes.md) | Audit notes |

## Quick totals

See [00-summary.md](00-summary.md) for full metrics. Unique definitions: **304**.
