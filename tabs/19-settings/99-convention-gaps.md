# Settings inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after code-traced inventory (2026-08-11).

## Residual

1. **Hybrid chrome**: uses `AppTabStrip` **and** accordion panels; strip has no counts/tones.
2. **Account** lacks sibling `AppCollapsibleSection` title/body (`settingsAccountSectionTitle`/`Body` strip-only).
3. **Language prefs** arb (`settingsLanguage*`) and some theme section keys **not mounted**.
4. Preferences/Accessibility **read-only summaries dead** (`update` ≡ `profile:read`).
5. Workspace API **summaryCards / checklist / quickActions** unused in UI (tests assert Quick actions / Setup checklist / Context summary absent).
6. Security workspace modules **unrouted** (Open/Create suppressed; unavailable copy keys unused).
7. Configuration **loading** uses `CircularProgressIndicator`; reset cancel uses Material cancel label.
8. No table toolbar / Export / Print anywhere on Settings (N/A vs `tables.mdc` desk pattern).
9. Leaves/Rosters filters are chips, not `commonAdvancedFilters*`.
10. Section switch clears `panel`; retap does not collapse; unauthorized URL tab silently falls back.
11. Admin navigate gates (`setup:read` / platform / `access_admin:read`) **differ** from tab admin ∪ — intentional, documented in `settings_access.dart`.
12. When workspace visible, Administration **duplicates avoided** (subscriptions only) — verified in tests.
