# Base / root dialogs

[Index](README.md)

Reusable primitives other dialogs compose or call.

| Symbol | Role | Defined in | Extends / uses |
| --- | --- | --- | --- |
| `AppDialog` | Root modal shell (chrome, resize, maximize, actions) | `frontend/lib/shared/components/app_dialog.dart` | Flutter dialog route via `showGeneralDialog` |
| `showAppDialog` | Standard opener for dialog builders | `frontend/lib/shared/components/app_dialog.dart` | `showGeneralDialog` |
| `showAppWorkspaceActionDialog` | Workspace action/form opener | `frontend/lib/shared/layout/app_workspace.dart` | `showAppDialog` |
| `showAppWorkspaceMutationDialog` | Mutation form dialog (save/cancel + failure) | `frontend/lib/shared/layout/app_workspace_mutation_dialog.dart` | `AppDialog` |
| `AppConfirmActionDialog` | Confirm / destructive confirm | `frontend/lib/shared/actions/app_action_dialogs.dart` | `AppDialog` |
| `AppTextActionDialog` | Multi-line text action | `frontend/lib/shared/actions/app_action_dialogs.dart` | `AppDialog` |
| `AppSelectActionDialog` | Single-select action | `frontend/lib/shared/actions/app_action_dialogs.dart` | `AppDialog` |
| `AppTextInputActionDialog` | Single-line text input action | `frontend/lib/shared/actions/app_action_dialogs.dart` | `AppDialog` |
| `_AppWorkspaceMutationDialog` | Internal mutation dialog widget | `frontend/lib/shared/layout/app_workspace_mutation_dialog.dart` | `AppDialog` |
| `_WorkspaceFilterDialog` | Workspace filter shell | `frontend/lib/shared/layout/app_workspace.dart` | `AppDialog` |

Almost all feature dialogs compose **`AppDialog`** (directly or via the action/mutation helpers above). Workspace pattern tests discourage raw `AlertDialog` / `showDialog` in feature code.
