import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/shared/actions/app_action_panel.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

enum AppWorkflowStepState {
  current,
  completed,
  upcoming,
  skipped,
  reverted,
  unavailable,
}

/// Presentation-only workflow step model. Capabilities come from the backend.
@immutable
final class AppWorkflowStepItem {
  const AppWorkflowStepItem({
    required this.id,
    required this.label,
    required this.state,
    this.description,
    this.icon,
    this.helpText,
    this.blockedReason,
    this.actions = const <AppWorkflowStepAction>[],
  });

  final Object id;
  final String label;
  final AppWorkflowStepState state;
  final String? description;
  final IconData? icon;
  final String? helpText;
  final String? blockedReason;
  final List<AppWorkflowStepAction> actions;
}

@immutable
final class AppWorkflowStepAction {
  const AppWorkflowStepAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.requirement,
    this.enabled = true,
    this.isLoading = false,
    this.hideWhenDenied = true,
    this.variant = AppButtonVariant.secondary,
    this.tooltip,
    this.blockedReason,
    this.capabilityAllowed = true,
  });

  final Object id;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final AccessRequirement? requirement;
  final bool enabled;
  final bool isLoading;
  final bool hideWhenDenied;
  final AppButtonVariant variant;
  final String? tooltip;
  final String? blockedReason;
  final bool capabilityAllowed;
}

/// Reusable workflow progress stepper for encounter/request/task progressions.
class AppWorkflowStepper extends StatelessWidget {
  const AppWorkflowStepper({
    required this.steps,
    this.compactBreakpoint = 640,
    this.showDescriptions = true,
    this.semanticLabel,
    super.key,
  });

  final List<AppWorkflowStepItem> steps;
  final double compactBreakpoint;
  final bool showDescriptions;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final bool compact = maxWidth < compactBreakpoint;
        AppWorkflowStepItem? current;
        for (final AppWorkflowStepItem step in steps) {
          if (step.state == AppWorkflowStepState.current) {
            current = step;
            break;
          }
        }

        final Widget track = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (var index = 0; index < steps.length; index += 1) ...<Widget>[
                if (index > 0)
                  Container(
                    width: compact ? 16 : 24,
                    height: 2,
                    color: _connectorColor(theme, steps[index - 1], steps[index]),
                  ),
                _WorkflowStepNode(
                  step: steps[index],
                  compact: compact,
                  showDescription: showDescriptions && !compact,
                ),
              ],
            ],
          ),
        );

        final List<AppWorkflowStepAction> activeActions =
            current?.actions ?? const <AppWorkflowStepAction>[];

        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            track,
            if (current?.description != null &&
                current!.description!.trim().isNotEmpty &&
                compact) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Text(
                current.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (current?.blockedReason != null &&
                current!.blockedReason!.trim().isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Text(
                current.blockedReason!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.statusColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (activeActions.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              _WorkflowStepActions(actions: activeActions),
            ],
          ],
        );

        if (semanticLabel != null) {
          content = Semantics(
            container: true,
            label: semanticLabel,
            child: content,
          );
        }

        return content;
      },
    );
  }

  static Color _connectorColor(
    ThemeData theme,
    AppWorkflowStepItem previous,
    AppWorkflowStepItem next,
  ) {
    final bool filled =
        previous.state == AppWorkflowStepState.completed ||
        previous.state == AppWorkflowStepState.current ||
        next.state == AppWorkflowStepState.completed ||
        next.state == AppWorkflowStepState.current;
    return filled
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
  }
}

class _WorkflowStepNode extends StatelessWidget {
  const _WorkflowStepNode({
    required this.step,
    required this.compact,
    required this.showDescription,
  });

  final AppWorkflowStepItem step;
  final bool compact;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final IconData icon = step.icon ?? _defaultIcon(step.state);
    final Color fill = _fillColor(theme, step.state);
    final Color foreground = _foregroundColor(theme, step.state);
    final String help = <String>[
      step.label,
      if (step.description != null && step.description!.isNotEmpty)
        step.description!,
      if (step.helpText != null && step.helpText!.isNotEmpty) step.helpText!,
      if (step.blockedReason != null && step.blockedReason!.isNotEmpty)
        step.blockedReason!,
      step.state.name,
    ].join('. ');

    final Widget node = Semantics(
      label: help,
      child: Tooltip(
        message: step.helpText ?? step.blockedReason ?? step.description ?? step.label,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: compact ? 72 : 104),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: compact ? 28 : 36,
                height: compact ? 28 : 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: step.state == AppWorkflowStepState.current
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: step.state == AppWorkflowStepState.current ? 2 : 1,
                  ),
                ),
                child: Icon(icon, size: compact ? 14 : 18, color: foreground),
              ),
              SizedBox(height: theme.spacing.xs),
              SizedBox(
                width: compact ? 80 : 112,
                child: Text(
                  step.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: step.state == AppWorkflowStepState.current
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: step.state == AppWorkflowStepState.unavailable
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                        : null,
                  ),
                ),
              ),
              if (showDescription &&
                  step.description != null &&
                  step.description!.trim().isNotEmpty)
                SizedBox(
                  width: 112,
                  child: Text(
                    step.description!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return node;
  }

  static IconData _defaultIcon(AppWorkflowStepState state) {
    return switch (state) {
      AppWorkflowStepState.current => Icons.radio_button_checked,
      AppWorkflowStepState.completed => Icons.check,
      AppWorkflowStepState.upcoming => Icons.radio_button_unchecked,
      AppWorkflowStepState.skipped => Icons.skip_next_outlined,
      AppWorkflowStepState.reverted => Icons.undo_outlined,
      AppWorkflowStepState.unavailable => Icons.lock_outline,
    };
  }

  static Color _fillColor(ThemeData theme, AppWorkflowStepState state) {
    final ColorScheme scheme = theme.colorScheme;
    return switch (state) {
      AppWorkflowStepState.current => scheme.primaryContainer,
      AppWorkflowStepState.completed => scheme.primary,
      AppWorkflowStepState.upcoming => scheme.surfaceContainerHighest,
      AppWorkflowStepState.skipped => scheme.surfaceContainerHighest,
      AppWorkflowStepState.reverted => theme.statusColors.warning.withValues(
        alpha: 0.18,
      ),
      AppWorkflowStepState.unavailable =>
        scheme.surfaceContainerHighest.withValues(alpha: 0.55),
    };
  }

  static Color _foregroundColor(ThemeData theme, AppWorkflowStepState state) {
    final ColorScheme scheme = theme.colorScheme;
    return switch (state) {
      AppWorkflowStepState.current => scheme.onPrimaryContainer,
      AppWorkflowStepState.completed => scheme.onPrimary,
      AppWorkflowStepState.upcoming => scheme.onSurfaceVariant,
      AppWorkflowStepState.skipped => scheme.onSurfaceVariant,
      AppWorkflowStepState.reverted => theme.statusColors.warning,
      AppWorkflowStepState.unavailable =>
        scheme.onSurfaceVariant.withValues(alpha: 0.45),
    };
  }
}

class _WorkflowStepActions extends StatelessWidget {
  const _WorkflowStepActions({required this.actions});

  final List<AppWorkflowStepAction> actions;

  @override
  Widget build(BuildContext context) {
    final List<AppPermissionActionItem> permissionActions =
        <AppPermissionActionItem>[];
    final List<Widget> plainActions = <Widget>[];

    for (final AppWorkflowStepAction action in actions) {
      if (action.requirement != null) {
        permissionActions.add(
          AppPermissionActionItem(
            requirement: action.requirement!,
            label: action.label,
            icon: action.icon,
            onPressed: action.onPressed,
            variant: action.variant,
            enabled: action.enabled && action.capabilityAllowed,
            isLoading: action.isLoading,
            hideWhenDenied: action.hideWhenDenied,
            tooltip: action.blockedReason ?? action.tooltip,
            blockedReason: action.blockedReason,
            capabilityAllowed: action.capabilityAllowed,
          ),
        );
      } else {
        plainActions.add(
          AppButton(
            label: action.label,
            leadingIcon: action.icon,
            variant: action.variant,
            enabled: action.enabled && action.capabilityAllowed,
            isLoading: action.isLoading,
            tooltip: action.blockedReason ?? action.tooltip ?? action.label,
            onPressed: action.enabled && action.capabilityAllowed
                ? action.onPressed
                : null,
          ),
        );
      }
    }

    if (permissionActions.isNotEmpty) {
      return AppPermissionActionList(
        actions: permissionActions,
        extraActions: plainActions,
      );
    }

    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      children: plainActions,
    );
  }
}
