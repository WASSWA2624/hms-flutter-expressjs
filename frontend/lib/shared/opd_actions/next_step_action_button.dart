import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/opd_actions/next_step_resolver.dart';

/// A clickable action button that navigates the user to the module/page where
/// the next workflow step can be completed.
///
/// Used in all module tables that display a "next step" or "current step" column.
/// The button resolves its target via [resolveNextStepTarget] and navigates
/// via [navigateToNextStep] on tap.
class NextStepActionButton extends StatelessWidget {
  const NextStepActionButton({
    required this.encounterId,
    this.patientId,
    this.stage,
    this.nextStep,
    this.displayNextStep,
    this.assignedStaffId,
    this.flow,
    this.compact = false,
    this.onBeforeNavigate,
    super.key,
  });

  final String encounterId;
  final String? patientId;
  final String? stage;
  final String? nextStep;
  final String? displayNextStep;
  final String? assignedStaffId;
  final OpdFlowSummary? flow;
  final bool compact;

  /// Called before navigation, e.g. to close a dialog. Return false to cancel.
  final VoidCallback? onBeforeNavigate;

  @override
  Widget build(BuildContext context) {
    final NextStepContext stepContext = NextStepContext(
      encounterId: encounterId,
      patientId: patientId,
      stage: stage,
      nextStep: nextStep,
      displayNextStep: displayNextStep,
      assignedStaffId: assignedStaffId,
      flow: flow,
    );

    final NextStepTarget? target = resolveNextStepTarget(context, stepContext);
    if (target == null) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);

    if (compact) {
      return _CompactNextStepButton(
        target: target,
        onPressed: () => _navigate(context, target),
      );
    }

    return Tooltip(
      message: target.tooltip ?? '',
      child: InkWell(
        onTap: () => _navigate(context, target),
        borderRadius: BorderRadius.circular(theme.spacing.xs),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.xs,
            vertical: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (target.icon != null) ...<Widget>[
                Icon(
                  target.icon,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: theme.spacing.xs),
              ],
              Flexible(
                child: Text(
                  target.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.primary.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.xs),
              Icon(
                Icons.open_in_new,
                size: 12,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, NextStepTarget target) {
    onBeforeNavigate?.call();
    navigateToNextStep(context, target);
  }
}

class _CompactNextStepButton extends StatelessWidget {
  const _CompactNextStepButton({
    required this.target,
    required this.onPressed,
  });

  final NextStepTarget target;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(theme.spacing.xs),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xs,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              target.icon ?? Icons.arrow_forward_outlined,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            SizedBox(width: theme.spacing.xs),
            Flexible(
              child: Text(
                target.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Utility to extract the display label for a next step without navigation.
String nextStepActionLabel(BuildContext context, NextStepContext stepContext) {
  final NextStepTarget? target = resolveNextStepTarget(context, stepContext);
  if (target == null) {
    return context.l10n.profileUnknownValue;
  }
  return target.label;
}
