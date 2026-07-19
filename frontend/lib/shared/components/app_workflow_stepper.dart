import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/actions/app_quick_actions.dart';
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

  bool get hasHelpActionContent {
    final String? help = helpText?.trim();
    final String? blocked = blockedReason?.trim();
    return (help != null && help.isNotEmpty) ||
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

/// Reusable breadcrumb-style workflow progress strip for encounter/request/
/// task progressions.
///
/// Steps render on a single compact line (wrapping when narrow), separated by
/// chevrons:
/// - completed steps show a green check and green label;
/// - the current step shows a filled dot, bold underlined label, and its
///   description as a caption underneath;
/// - upcoming steps show a muted label with the description as an outlined
///   pill tag (e.g. "Next action").
///
/// The stepper draws its own shared panel (a pale tinted band) so it looks
/// identical everywhere in the app. Set [showPanel] to false when a caller
/// needs to embed the bare strip in custom chrome.
class AppWorkflowStepper extends StatelessWidget {
  const AppWorkflowStepper({
    required this.steps,
    this.compactBreakpoint = 640,
    this.showDescriptions = true,
    this.semanticLabel,
    this.helpActionLabel,
    this.guidance,
    this.showPanel = true,
    this.panelPadding,
    super.key,
  });

  final List<AppWorkflowStepItem> steps;

  /// Retained for API compatibility; the breadcrumb layout wraps
  /// automatically, so no explicit breakpoint is needed.
  final double compactBreakpoint;
  final bool showDescriptions;
  final String? semanticLabel;

  /// Localized label for the touch/keyboard help affordance.
  /// Defaults to a generic "Help" string when omitted.
  final String? helpActionLabel;
  final String? guidance;

  /// Whether to wrap the stepper contents in the shared grouping panel.
  final bool showPanel;

  /// Padding inside the grouping panel. Ignored when [showPanel] is false.
  final EdgeInsetsGeometry? panelPadding;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final String resolvedHelpLabel =
        helpActionLabel ?? l10n.workflowStepHelpActionLabel;

    AppWorkflowStepItem? current;
    for (final AppWorkflowStepItem step in steps) {
      if (step.state == AppWorkflowStepState.current) {
        current = step;
        break;
      }
    }

    final Widget track = FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maxStepWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          return Wrap(
            key: const ValueKey<String>('workflowStepTrackWrapped'),
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (var index = 0; index < steps.length; index += 1) ...<Widget>[
                if (index > 0)
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxStepWidth),
                  child: _WorkflowStepEntry(
                    step: steps[index],
                    showDescription: showDescriptions,
                    helpActionLabel: resolvedHelpLabel,
                    focusOrder: index.toDouble(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    final List<AppWorkflowStepAction> activeActions =
        current?.actions ?? const <AppWorkflowStepAction>[];

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        track,
        if (guidance != null && guidance!.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: theme.spacing.xs),
              Expanded(
                child: Text(
                  guidance!.trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
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

    if (showPanel) {
      content = _WorkflowStepperPanel(padding: panelPadding, child: content);
    }

    if (semanticLabel != null) {
      content = Semantics(container: true, label: semanticLabel, child: content);
    }

    return content;
  }
}

/// Shared grouping panel for stepper content: a pale primary-tinted band with
/// a soft border, consistent wherever the stepper appears in the app.
class _WorkflowStepperPanel extends StatelessWidget {
  const _WorkflowStepperPanel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      key: const ValueKey<String>('workflowStepperPanel'),
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm,
          ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.05),
          scheme.surfaceContainerLow,
        ),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: child,
    );
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

/// One breadcrumb entry: state indicator, label (underlined when current),
/// caption or pill tag for the description, and optional help affordance.
class _WorkflowStepEntry extends StatelessWidget {
  const _WorkflowStepEntry({
    required this.step,
    required this.showDescription,
    required this.helpActionLabel,
    required this.focusOrder,
  });

  final AppWorkflowStepItem step;
  final bool showDescription;
  final String helpActionLabel;
  final double focusOrder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isCurrent = step.state == AppWorkflowStepState.current;
    final Color labelColor = _labelColor(theme, step.state);
    final String stateLabel = _stateLabel(context.l10n, step.state);
    final String? description = (step.description?.trim().isEmpty ?? true)
        ? null
        : step.description!.trim();
    final String help = <String>[
      step.label,
      if (description != null) description,
      if (step.helpText != null && step.helpText!.isNotEmpty) step.helpText!,
      if (step.blockedReason != null && step.blockedReason!.isNotEmpty)
        step.blockedReason!,
      stateLabel,
    ].join('. ');
    final String tooltipMessage =
        step.helpText ?? step.blockedReason ?? step.description ?? step.label;
    final bool interactive = step.onTap != null || step.hasHelpActionContent;

    final TextStyle labelStyle = (theme.textTheme.labelMedium ??
            const TextStyle())
        .copyWith(
          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
          color: labelColor,
          decoration: isCurrent ? TextDecoration.underline : TextDecoration.none,
          decorationColor: isCurrent ? colorScheme.primary : null,
          decorationThickness: isCurrent ? 2.5 : null,
        );

    Widget labelBlock = Text(
      step.label,
      softWrap: true,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: labelStyle,
    );

    if (isCurrent && showDescription && description != null) {
      labelBlock = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          labelBlock,
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              description,
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    final Widget? indicator = _indicator(theme);

    final Widget entryBody = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (indicator != null) ...<Widget>[
          indicator,
          SizedBox(width: theme.spacing.xs),
        ],
        Flexible(child: labelBlock),
        if (!isCurrent && showDescription && description != null) ...<Widget>[
          SizedBox(width: theme.spacing.xs),
          _WorkflowStepTag(text: description, state: step.state),
        ],
        if (step.hasHelpActionContent) ...<Widget>[
          SizedBox(width: theme.spacing.xs),
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
    );

    final Widget node = Semantics(
      button: interactive,
      enabled: interactive,
      label: help,
      child: Tooltip(
        message: tooltipMessage,
        waitDuration: const Duration(milliseconds: 400),
        child: entryBody,
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
    if (step.hasHelpActionContent) {
      showAppWorkflowStepHelp(
        context: context,
        step: step,
        helpActionLabel: helpActionLabel,
      );
    }
  }

  Widget? _indicator(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    if (step.icon != null) {
      return Icon(step.icon, size: 16, color: _labelColor(theme, step.state));
    }
    return switch (step.state) {
      AppWorkflowStepState.completed => Icon(
        Icons.check_circle,
        size: 16,
        color: theme.statusColors.success,
      ),
      AppWorkflowStepState.current => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      AppWorkflowStepState.upcoming => null,
      AppWorkflowStepState.skipped => Icon(
        Icons.skip_next_outlined,
        size: 16,
        color: scheme.onSurfaceVariant,
      ),
      AppWorkflowStepState.reverted => Icon(
        Icons.undo_outlined,
        size: 16,
        color: theme.statusColors.warning,
      ),
      AppWorkflowStepState.unavailable => Icon(
        Icons.lock_outline,
        size: 16,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
      ),
    };
  }

  static String _stateLabel(AppLocalizations l10n, AppWorkflowStepState state) {
    return switch (state) {
      AppWorkflowStepState.current => l10n.workflowStepStateCurrent,
      AppWorkflowStepState.completed => l10n.workflowStepStateCompleted,
      AppWorkflowStepState.upcoming => l10n.workflowStepStateUpcoming,
      AppWorkflowStepState.skipped => l10n.workflowStepStateSkipped,
      AppWorkflowStepState.reverted => l10n.workflowStepStateReverted,
      AppWorkflowStepState.unavailable => l10n.workflowStepStateUnavailable,
    };
  }

  static Color _labelColor(ThemeData theme, AppWorkflowStepState state) {
    final ColorScheme scheme = theme.colorScheme;
    return switch (state) {
      AppWorkflowStepState.current => scheme.primary,
      AppWorkflowStepState.completed => theme.statusColors.success,
      AppWorkflowStepState.upcoming => scheme.onSurfaceVariant,
      AppWorkflowStepState.skipped => scheme.onSurfaceVariant,
      AppWorkflowStepState.reverted => theme.statusColors.warning,
      AppWorkflowStepState.unavailable => scheme.onSurfaceVariant.withValues(
        alpha: 0.55,
      ),
    };
  }
}

/// Small outlined pill used for non-current step descriptions
/// (e.g. the "Next action" tag on upcoming steps).
class _WorkflowStepTag extends StatelessWidget {
  const _WorkflowStepTag({required this.text, required this.state});

  final String text;
  final AppWorkflowStepState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color color = switch (state) {
      AppWorkflowStepState.upcoming => scheme.primary,
      AppWorkflowStepState.reverted => theme.statusColors.warning,
      AppWorkflowStepState.completed => theme.statusColors.success,
      _ => scheme.onSurfaceVariant,
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.65)),
        color: state == AppWorkflowStepState.upcoming
            ? scheme.primary.withValues(alpha: 0.06)
            : null,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
      return AppQuickActions(
        presentation: AppQuickActionsPresentation.buttonsOnly,
        permissionActions: permissionActions,
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
