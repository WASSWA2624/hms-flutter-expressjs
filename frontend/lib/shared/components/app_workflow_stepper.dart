import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/actions/app_action_panel.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';

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
    this.onTap,
    this.actions = const <AppWorkflowStepAction>[],
  });

  final Object id;
  final String label;
  final AppWorkflowStepState state;
  final String? description;
  final IconData? icon;
  final String? helpText;
  final String? blockedReason;
  final VoidCallback? onTap;
  final List<AppWorkflowStepAction> actions;

  bool get hasHelpContent {
    final String? help = helpText?.trim();
    final String? descriptionText = description?.trim();
    final String? blocked = blockedReason?.trim();
    return (help != null && help.isNotEmpty) ||
        (descriptionText != null && descriptionText.isNotEmpty) ||
        (blocked != null && blocked.isNotEmpty);
  }
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
    this.confirmTitle,
    this.confirmBody,
    this.confirmSubmitLabel,
    this.destructive = false,
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

  /// When set with [confirmBody], the action asks for confirmation before
  /// invoking [onPressed]. Success/failure feedback remains caller-owned.
  final String? confirmTitle;
  final String? confirmBody;
  final String? confirmSubmitLabel;
  final bool destructive;

  bool get requiresConfirmation {
    final String? title = confirmTitle?.trim();
    final String? body = confirmBody?.trim();
    return title != null && title.isNotEmpty && body != null && body.isNotEmpty;
  }
}

/// Reusable workflow progress stepper for encounter/request/task progressions.
class AppWorkflowStepper extends StatelessWidget {
  const AppWorkflowStepper({
    required this.steps,
    this.compactBreakpoint = 640,
    this.showDescriptions = true,
    this.semanticLabel,
    this.helpActionLabel,
    super.key,
  });

  final List<AppWorkflowStepItem> steps;
  final double compactBreakpoint;
  final bool showDescriptions;
  final String? semanticLabel;

  /// Localized label for the touch/keyboard help affordance.
  /// Defaults to a generic "Help" string when omitted.
  final String? helpActionLabel;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final String resolvedHelpLabel =
        helpActionLabel ?? l10n.workflowStepHelpActionLabel;

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

        final Widget track = FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (
                  var index = 0;
                  index < steps.length;
                  index += 1
                ) ...<Widget>[
                  if (index > 0)
                    Container(
                      width: compact ? 16 : 24,
                      height: 2,
                      color: _connectorColor(
                        theme,
                        steps[index - 1],
                        steps[index],
                      ),
                    ),
                  _WorkflowStepNode(
                    step: steps[index],
                    compact: compact,
                    showDescription: showDescriptions && !compact,
                    helpActionLabel: resolvedHelpLabel,
                    focusOrder: index.toDouble(),
                  ),
                ],
              ],
            ),
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

Future<void> showAppWorkflowStepHelp({
  required BuildContext context,
  required AppWorkflowStepItem step,
  required String helpActionLabel,
}) {
  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final List<String> sections = <String>[
    if (step.description != null && step.description!.trim().isNotEmpty)
      step.description!.trim(),
    if (step.helpText != null && step.helpText!.trim().isNotEmpty)
      step.helpText!.trim(),
    if (step.blockedReason != null && step.blockedReason!.trim().isNotEmpty)
      step.blockedReason!.trim(),
  ];

  return showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AppDialog(
        title: Text(step.label),
        icon: Icon(step.icon ?? Icons.info_outline),
        semanticLabel: '$helpActionLabel: ${step.label}',
        maxWidth: 520,
        initialMaximized: false,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (
              var index = 0;
              index < sections.length;
              index += 1
            ) ...<Widget>[
              if (index > 0) SizedBox(height: theme.spacing.sm),
              Text(
                sections[index],
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          AppButton.secondary(
            label: l10n.commonCloseActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}

class _WorkflowStepNode extends StatelessWidget {
  const _WorkflowStepNode({
    required this.step,
    required this.compact,
    required this.showDescription,
    required this.helpActionLabel,
    required this.focusOrder,
  });

  final AppWorkflowStepItem step;
  final bool compact;
  final bool showDescription;
  final String helpActionLabel;
  final double focusOrder;

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
    final String tooltipMessage =
        step.helpText ?? step.blockedReason ?? step.description ?? step.label;
    final bool interactive = step.onTap != null || step.hasHelpContent;

    final Widget nodeBody = ConstrainedBox(
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
          if (step.hasHelpContent) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            AppButton.tertiary(
              iconOnly: true,
              leadingIcon: Icons.help_outline,
              label: helpActionLabel,
              semanticLabel: '$helpActionLabel: ${step.label}',
              tooltip: helpActionLabel,
              onPressed: () {
                showAppWorkflowStepHelp(
                  context: context,
                  step: step,
                  helpActionLabel: helpActionLabel,
                );
              },
            ),
          ],
        ],
      ),
    );

    final Widget node = Semantics(
      button: interactive,
      enabled: interactive,
      label: help,
      child: Tooltip(
        message: tooltipMessage,
        waitDuration: const Duration(milliseconds: 400),
        child: nodeBody,
      ),
    );

    if (!interactive) {
      return FocusTraversalOrder(
        order: NumericFocusOrder(focusOrder),
        child: node,
      );
    }

    return FocusTraversalOrder(
      order: NumericFocusOrder(focusOrder),
      child: FocusableActionDetector(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate(context);
              return null;
            },
          ),
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: Builder(
          builder: (BuildContext context) {
            final bool focused = Focus.of(context).hasFocus;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _activate(context),
                onLongPress: step.hasHelpContent
                    ? () {
                        showAppWorkflowStepHelp(
                          context: context,
                          step: step,
                          helpActionLabel: helpActionLabel,
                        );
                      }
                    : null,
                borderRadius: BorderRadius.circular(theme.radius.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(theme.radius.sm),
                    border: focused
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: node,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _activate(BuildContext context) {
    if (step.onTap != null) {
      step.onTap!();
      return;
    }
    if (step.hasHelpContent) {
      showAppWorkflowStepHelp(
        context: context,
        step: step,
        helpActionLabel: helpActionLabel,
      );
    }
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
      AppWorkflowStepState.skipped => scheme.surfaceContainerHigh,
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
      AppWorkflowStepState.unavailable => scheme.onSurfaceVariant.withValues(
        alpha: 0.45,
      ),
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
      final VoidCallback? wrappedPress = _wrapPress(context, action);
      if (action.requirement != null) {
        permissionActions.add(
          AppPermissionActionItem(
            requirement: action.requirement!,
            label: action.label,
            icon: action.icon,
            onPressed: wrappedPress,
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
                ? wrappedPress
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

  VoidCallback? _wrapPress(BuildContext context, AppWorkflowStepAction action) {
    final VoidCallback? onPressed = action.onPressed;
    if (onPressed == null) {
      return null;
    }
    if (!action.requiresConfirmation) {
      return onPressed;
    }

    return () {
      showAppDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AppConfirmActionDialog(
            title: action.confirmTitle!,
            body: action.confirmBody!,
            submitLabel: action.confirmSubmitLabel ?? action.label,
            destructive: action.destructive,
            icon: Icon(action.icon),
          );
        },
      ).then((bool? confirmed) {
        if (confirmed == true) {
          onPressed();
        }
      });
    };
  }
}
