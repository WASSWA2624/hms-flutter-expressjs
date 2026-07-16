import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/presentation/controllers/radiology_workspace_controller.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_registry.dart';

typedef RadiologyDetailDialogOpener =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      RadiologyWorkspaceState state,
      RadiologyOrder order, {
      required bool canWork,
      required bool canRequest,
    });

typedef RadiologyNextActionLabelResolver =
    String Function(BuildContext context, RadiologyOrder order);

String? radiologyWorkflowNextStepCode(RadiologyOrder order) {
  if (order.normalizedStatus == 'CANCELLED') {
    return null;
  }
  if (!order.hasBillingGate) {
    return null;
  }
  if (order.hasDraftResult || order.hasFinalResult) {
    return null;
  }
  if (order.normalizedStatus == 'IN_PROCESS' && order.studyCount == 0) {
    return null;
  }
  return switch (order.normalizedStatus) {
    'ORDERED' => 'RADIOLOGY_REQUESTED',
    'IN_PROCESS' => 'IMAGING_PENDING',
    'COMPLETED' => 'REPORT_PENDING',
    _ => 'REPORT_PENDING',
  };
}

class RadiologyNextActionCell extends ConsumerWidget {
  const RadiologyNextActionCell({
    required this.order,
    required this.state,
    required this.canWork,
    required this.canRequest,
    required this.resolveLabel,
    required this.openDetailDialog,
    this.compact = true,
    super.key,
  });

  final RadiologyOrder order;
  final RadiologyWorkspaceState state;
  final bool canWork;
  final bool canRequest;
  final RadiologyNextActionLabelResolver resolveLabel;
  final RadiologyDetailDialogOpener openDetailDialog;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String label = resolveLabel(context, order);
    if (order.normalizedStatus == 'CANCELLED') {
      return _RadiologyNextActionText(label: label);
    }

    final String? encounterId = order.encounterId?.trim();
    final String? nextStep = radiologyWorkflowNextStepCode(order);
    if (encounterId != null &&
        encounterId.isNotEmpty &&
        nextStep != null &&
        WorkflowActionRegistry.instance.isRegistered(nextStep)) {
      return WorkflowActionButton(
        encounterId: encounterId,
        patientId: order.patientId,
        orderId: order.id,
        stage: order.status,
        nextStep: nextStep,
        displayNextStep: nextStep,
        sourceModule: 'radiology',
        compact: compact,
        onBeforeNavigate: () {
          unawaited(
            ref
                .read(radiologyWorkspaceControllerProvider.notifier)
                .selectOrder(order),
          );
        },
      );
    }

    return _RadiologyCompactNextActionButton(
      label: label,
      compact: compact,
      onPressed: () => openDetailDialog(
        context,
        ref,
        state,
        order,
        canWork: canWork,
        canRequest: canRequest,
      ),
    );
  }
}

class _RadiologyNextActionText extends StatelessWidget {
  const _RadiologyNextActionText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _RadiologyCompactNextActionButton extends StatelessWidget {
  const _RadiologyCompactNextActionButton({
    required this.label,
    required this.onPressed,
    required this.compact,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    return Semantics(
      button: true,
      enabled: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: compact ? 2 : 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.arrow_forward_outlined,
                    size: compact ? 14 : 16,
                    color: primaryColor,
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (compact
                                  ? theme.textTheme.labelSmall
                                  : theme.textTheme.bodySmall)
                              ?.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
