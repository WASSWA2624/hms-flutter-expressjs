import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_registry.dart';

/// Result of executing a workflow action.
enum WorkflowActionResult {
  /// The action was successfully started (navigation or dialog opened).
  started,

  /// The action completed successfully via inline dialog.
  completedViaDialog,

  /// The action's dialog was cancelled by the user.
  cancelledByUser,

  /// The action was denied due to permissions.
  denied,

  /// The action is unavailable (module not active, unsupported, etc.).
  unavailable,

  /// The action was already in progress (duplicate execution prevented).
  alreadyInProgress,

  /// The action's target was not found or stale.
  stale,
}

/// Shared orchestration service for executing workflow actions.
///
/// 1. Receives the action context.
/// 2. Resolves the canonical action via the registry.
/// 3. Checks permissions and module entitlement.
/// 4. Opens the correct dialog/form or performs a targeted handoff.
/// 5. Handles loading, success, cancellation, conflict, and failure states.
/// 6. Refreshes/invalidates affected providers after success.
/// 7. Prevents duplicate execution while an action is in progress.
final class WorkflowActionExecutor {
  WorkflowActionExecutor._();

  static final WorkflowActionExecutor instance = WorkflowActionExecutor._();

  bool _isExecuting = false;

  /// Whether an action is currently being executed.
  bool get isExecuting => _isExecuting;

  /// Execute a resolved [WorkflowAction].
  ///
  /// When [ref] is provided and the action has [WorkflowActionMode.dialog]
  /// with a registered [WorkflowActionDefinition.dialogOpener], the dialog
  /// is opened inline. On success, [WorkflowActionDefinition.onSuccess] is
  /// called to invalidate affected providers. Falls back to route-based
  /// navigation when no dialog opener is registered or when it returns `null`.
  ///
  /// Returns the result of the execution attempt. Feature tables should call
  /// this instead of implementing their own navigation/dialog logic.
  Future<WorkflowActionResult> execute(
    BuildContext context,
    WorkflowAction action, {
    WidgetRef? ref,
    VoidCallback? onBeforeNavigate,
  }) async {
    if (_isExecuting) {
      return WorkflowActionResult.alreadyInProgress;
    }

    if (!action.isAvailable) {
      if (action.isPermissionDenied) {
        _showUnavailableSnackBar(context, action);
        return WorkflowActionResult.denied;
      }
      if (action.isUnsupported) {
        _showUnsupportedSnackBar(context, action);
      }
      return WorkflowActionResult.unavailable;
    }

    _isExecuting = true;

    try {
      onBeforeNavigate?.call();

      switch (action.mode) {
        case WorkflowActionMode.dialog:
          return await _executeDialogAction(context, ref, action);
        case WorkflowActionMode.route:
        case WorkflowActionMode.inlineCommand:
        case WorkflowActionMode.readOnly:
          _executeRouteAction(context, action);
          return WorkflowActionResult.started;
      }
    } finally {
      _isExecuting = false;
    }
  }

  /// Resolve context and execute in one step. Convenience for widgets.
  Future<WorkflowActionResult> resolveAndExecute(
    BuildContext context,
    WidgetRef ref,
    WorkflowActionContext actionContext, {
    VoidCallback? onBeforeNavigate,
  }) async {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final WorkflowAction? action = WorkflowActionRegistry.instance.resolve(
      context,
      actionContext,
      policy: policy,
    );

    if (action == null) {
      return WorkflowActionResult.unavailable;
    }

    return execute(
      context,
      action,
      ref: ref,
      onBeforeNavigate: onBeforeNavigate,
    );
  }

  /// Attempts dialog-first execution for actions with [WorkflowActionMode.dialog].
  ///
  /// Checks both the definition's [WorkflowActionDefinition.dialogOpener] field
  /// and the registry's separately-registered dialog openers. On success,
  /// fires the post-success callback to invalidate affected providers.
  /// Falls back to route-based navigation when no opener is registered or
  /// when the opener returns `null`.
  Future<WorkflowActionResult> _executeDialogAction(
    BuildContext context,
    WidgetRef? ref,
    WorkflowAction action,
  ) async {
    if (ref != null) {
      final WorkflowActionRegistry registry = WorkflowActionRegistry.instance;
      final WorkflowDialogOpener? opener =
          registry.dialogOpenerFor(action.code);

      if (opener != null) {
        final bool? result = await opener(context, ref, action);

        if (result == true) {
          registry.postSuccessCallbackFor(action.code)?.call(ref);
          return WorkflowActionResult.completedViaDialog;
        }

        if (result == false) {
          return WorkflowActionResult.cancelledByUser;
        }
        // result == null → dialog couldn't open, fall through to route
      }
    }

    if (!context.mounted) return WorkflowActionResult.stale;
    _executeRouteAction(context, action);
    return WorkflowActionResult.started;
  }

  void _executeRouteAction(BuildContext context, WorkflowAction action) {
    if (action.route != null) {
      GoRouter.of(context).go(action.route!);
    }
  }

  void _showUnavailableSnackBar(BuildContext context, WorkflowAction action) {
    final String reason =
        action.unavailableReason ?? context.l10n.profileUnknownValue;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showUnsupportedSnackBar(BuildContext context, WorkflowAction action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action.unavailableReason ?? 'Action not yet supported',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
