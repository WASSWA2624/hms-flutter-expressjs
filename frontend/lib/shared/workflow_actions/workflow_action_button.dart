import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_executor.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_registry.dart';

/// A clickable action button that executes the next workflow step.
///
/// Used in all module tables that display a "next step" or "current step" column.
/// Resolves the action via [WorkflowActionRegistry], checks authorization via
/// [AppAccessPolicy], and executes via [WorkflowActionExecutor].
///
/// Features:
/// - Actionable appearance distinct from status text
/// - Localized label and icon
/// - Loading and disabled states
/// - Tooltip naming the destination module
/// - Keyboard accessible with semantic label
/// - Stops row-click propagation
/// - Works in desktop tables, compact/mobile rows, cards, and dialogs
/// - Shows disabled state with reason when user lacks permission
class WorkflowActionButton extends ConsumerWidget {
  const WorkflowActionButton({
    required this.encounterId,
    this.patientId,
    this.admissionId,
    this.orderId,
    this.invoiceId,
    this.queueEntryId,
    this.stage,
    this.nextStep,
    this.displayNextStep,
    this.assignedStaffId,
    this.sourceModule,
    this.compact = false,
    this.onBeforeNavigate,
    super.key,
  });

  final String encounterId;
  final String? patientId;
  final String? admissionId;
  final String? orderId;
  final String? invoiceId;
  final String? queueEntryId;
  final String? stage;
  final String? nextStep;
  final String? displayNextStep;
  final String? assignedStaffId;
  final String? sourceModule;
  final bool compact;
  final VoidCallback? onBeforeNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WorkflowActionContext actionContext = WorkflowActionContext(
      encounterId: encounterId,
      patientId: patientId,
      admissionId: admissionId,
      orderId: orderId,
      invoiceId: invoiceId,
      queueEntryId: queueEntryId,
      stage: stage,
      nextStep: nextStep,
      displayNextStep: displayNextStep,
      assignedStaffId: assignedStaffId,
      sourceModule: sourceModule,
    );

    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final WorkflowAction? action = WorkflowActionRegistry.instance.resolve(
      context,
      actionContext,
      policy: policy,
    );

    if (action == null) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return _CompactActionButton(
        action: action,
        onPressed: () => _execute(context, ref, action),
      );
    }

    return _StandardActionButton(
      action: action,
      onPressed: () => _execute(context, ref, action),
    );
  }

  void _execute(BuildContext context, WidgetRef ref, WorkflowAction action) {
    WorkflowActionExecutor.instance.execute(
      context,
      action,
      ref: ref,
      onBeforeNavigate: onBeforeNavigate,
    );
  }
}

class _StandardActionButton extends StatelessWidget {
  const _StandardActionButton({required this.action, required this.onPressed});

  final WorkflowAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = action.isAvailable;
    final Color primaryColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      hint: action.tooltip,
      child: Tooltip(
        message: _tooltipMessage(context),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(action.icon, size: 16, color: primaryColor),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                        decoration: enabled ? TextDecoration.underline : null,
                        decorationColor: primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Icon(
                    enabled ? Icons.open_in_new : Icons.lock_outlined,
                    size: 12,
                    color: primaryColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _tooltipMessage(BuildContext context) {
    if (!action.isAvailable && action.unavailableReason != null) {
      return action.unavailableReason!;
    }
    return action.tooltip ?? '';
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({required this.action, required this.onPressed});

  final WorkflowAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = action.isAvailable;
    final Color primaryColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      child: Tooltip(
        message: _tooltipMessage(context),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(action.icon, size: 14, color: primaryColor),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!enabled) ...<Widget>[
                    SizedBox(width: theme.spacing.xs),
                    Icon(
                      Icons.lock_outlined,
                      size: 10,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _tooltipMessage(BuildContext context) {
    if (!action.isAvailable && action.unavailableReason != null) {
      return action.unavailableReason!;
    }
    return action.tooltip ?? '';
  }
}

/// Utility to extract the display label for a workflow action without
/// navigation/execution.
String workflowActionLabel(
  BuildContext context,
  WidgetRef ref,
  WorkflowActionContext actionContext,
) {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  final WorkflowAction? action = WorkflowActionRegistry.instance.resolve(
    context,
    actionContext,
    policy: policy,
  );
  if (action == null) {
    return context.l10n.profileUnknownValue;
  }
  return action.label;
}
