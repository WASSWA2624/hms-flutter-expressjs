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
/// 5. Prevents duplicate execution while an action is in progress.
final class WorkflowActionExecutor {
  WorkflowActionExecutor._();

  static final WorkflowActionExecutor instance = WorkflowActionExecutor._();

  bool _isExecuting = false;

  /// Whether an action is currently being executed.
  bool get isExecuting => _isExecuting;

  /// Execute a resolved [WorkflowAction].
  ///
  /// Returns the result of the execution attempt. Feature tables should call
  /// this instead of implementing their own navigation/dialog logic.
  WorkflowActionResult execute(
    BuildContext context,
    WorkflowAction action, {
    VoidCallback? onBeforeNavigate,
  }) {
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
          _executeDialogAction(context, action);
        case WorkflowActionMode.route:
          _executeRouteAction(context, action);
        case WorkflowActionMode.inlineCommand:
          _executeRouteAction(context, action);
        case WorkflowActionMode.readOnly:
          _executeRouteAction(context, action);
      }

      return WorkflowActionResult.started;
    } finally {
      _isExecuting = false;
    }
  }

  /// Resolve context and execute in one step. Convenience for widgets.
  WorkflowActionResult resolveAndExecute(
    BuildContext context,
    WidgetRef ref,
    WorkflowActionContext actionContext, {
    VoidCallback? onBeforeNavigate,
  }) {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final WorkflowAction? action = WorkflowActionRegistry.instance.resolve(
      context,
      actionContext,
      policy: policy,
    );

    if (action == null) {
      return WorkflowActionResult.unavailable;
    }

    return execute(context, action, onBeforeNavigate: onBeforeNavigate);
  }

  void _executeDialogAction(BuildContext context, WorkflowAction action) {
    // For dialog-mode actions, we still navigate to the target route which
    // should auto-open the appropriate dialog via query parameters.
    // The target module is responsible for interpreting the 'action' query param.
    if (action.route != null) {
      GoRouter.of(context).go(action.route!);
    }
  }

  void _executeRouteAction(BuildContext context, WorkflowAction action) {
    if (action.route != null) {
      GoRouter.of(context).go(action.route!);
    }
  }

  void _showUnavailableSnackBar(BuildContext context, WorkflowAction action) {
    final String reason =
        action.unavailableReason ??
        context.l10n.profileUnknownValue;
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
