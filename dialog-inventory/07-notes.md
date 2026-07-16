# Notes

[Index](README.md)

- Billing bodies in `billing_form_dialogs.dart` (`BillingRefundForm`, etc.) are form content hosted by billing `_show*` dialogs, not standalone dialogs.
- Many workspaces open detail views with an inline `AppDialog` (no dedicated `*Dialog` class); those appear as `open*` / `_open*` / `show*` / `_show*` opener entries.
- `frontend/test/shared/layout/workspace_ui_pattern_test.dart` flags raw `showDialog` / `AlertDialog` usage.
- Scan covers all of `frontend/lib`; `backend/` has no UI dialogs.
