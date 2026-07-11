import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

@immutable
final class AppWizardStepItem {
  const AppWizardStepItem({
    required this.id,
    required this.label,
    this.shortLabel,
    this.optional = false,
    this.completed = false,
    this.enabled = true,
  });

  final Object id;
  final String label;
  final String? shortLabel;
  final bool optional;
  final bool completed;
  final bool enabled;
}

/// Horizontal progress stepper for multi-step dialogs and wizards.
class AppWizardStepper extends StatelessWidget {
  const AppWizardStepper({
    required this.steps,
    required this.currentIndex,
    this.onStepSelected,
    this.onDisabledStepSelected,
    this.showCurrentTitle = true,
    this.progressCaption,
    this.optionalBadgeLabel = 'Optional',
    this.compactBreakpoint = 640,
    super.key,
  }) : assert(currentIndex >= 0);

  final List<AppWizardStepItem> steps;
  final int currentIndex;
  final ValueChanged<int>? onStepSelected;
  /// Called when a locked/disabled step is tapped (e.g. show a prerequisite hint).
  final ValueChanged<int>? onDisabledStepSelected;
  final bool showCurrentTitle;
  final String? progressCaption;
  final String optionalBadgeLabel;
  final double compactBreakpoint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final int safeIndex = currentIndex.clamp(0, steps.length - 1);
    final AppWizardStepItem current = steps[safeIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (progressCaption != null) ...<Widget>[
          Text(
            progressCaption!,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
        ],
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final bool compact = maxWidth < compactBreakpoint;
            final double nodeSize = compact ? 32 : 40;
            final double connectorWidth = compact
                ? theme.spacing.sm
                : theme.spacing.lg;

            final Widget track = Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int index = 0; index < steps.length; index += 1) ...<Widget>[
                  if (index > 0)
                    Padding(
                      padding: EdgeInsets.only(top: (nodeSize / 2) - 2),
                      child: _StepConnector(
                        completed:
                            index <= safeIndex || steps[index - 1].completed,
                        colorScheme: colorScheme,
                        width: connectorWidth,
                      ),
                    ),
                  _StepNode(
                    index: index + 1,
                    label: compact
                        ? (steps[index].shortLabel ?? steps[index].label)
                        : steps[index].label,
                    active: index == safeIndex,
                    completed: steps[index].completed,
                    optional: steps[index].optional,
                    optionalBadgeLabel: optionalBadgeLabel,
                    enabled: steps[index].enabled,
                    nodeSize: nodeSize,
                    compact: compact,
                    onTap: () {
                      if (steps[index].enabled) {
                        onStepSelected?.call(index);
                        return;
                      }
                      onDisabledStepSelected?.call(index);
                    },
                    interactive: steps[index].enabled
                        ? onStepSelected != null
                        : onDisabledStepSelected != null,
                  ),
                ],
              ],
            );

            return Padding(
              padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
              child: Align(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: track,
                ),
              ),
            );
          },
        ),
        if (showCurrentTitle) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          Text(
            current.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          if (current.optional)
            Padding(
              padding: EdgeInsets.only(top: theme.spacing.xs),
              child: Text(
                optionalBadgeLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({
    required this.completed,
    required this.colorScheme,
    required this.width,
  });

  final bool completed;
  final ColorScheme colorScheme;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: completed
            ? colorScheme.primary
            : colorScheme.outlineVariant.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _StepNode extends StatefulWidget {
  const _StepNode({
    required this.index,
    required this.label,
    required this.active,
    required this.completed,
    required this.optional,
    required this.optionalBadgeLabel,
    required this.enabled,
    required this.nodeSize,
    required this.compact,
    this.onTap,
    this.interactive = false,
  });

  final int index;
  final String label;
  final bool active;
  final bool completed;
  final bool optional;
  final String optionalBadgeLabel;
  final bool enabled;
  final double nodeSize;
  final bool compact;
  final VoidCallback? onTap;
  final bool interactive;

  @override
  State<_StepNode> createState() => _StepNodeState();
}

class _StepNodeState extends State<_StepNode> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool interactive = widget.interactive && widget.onTap != null;
    final bool highlight = widget.active || _hovered || _focused;

    final Color circleFill;
    final Color circleFg;
    final Color labelColor;
    final Color borderColor;

    if (!widget.enabled) {
      circleFill = colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
      circleFg = colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
      labelColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
      borderColor = colorScheme.outlineVariant.withValues(alpha: 0.5);
    } else if (widget.active || widget.completed) {
      circleFill = colorScheme.primary;
      circleFg = colorScheme.onPrimary;
      labelColor = widget.active
          ? colorScheme.primary
          : colorScheme.onSurface;
      borderColor = colorScheme.primary;
    } else {
      circleFill = highlight
          ? colorScheme.primary.withValues(alpha: 0.12)
          : colorScheme.surfaceContainerHighest;
      circleFg = highlight
          ? colorScheme.primary
          : colorScheme.onSurfaceVariant;
      labelColor = highlight
          ? colorScheme.primary
          : colorScheme.onSurfaceVariant;
      borderColor = highlight
          ? colorScheme.primary
          : colorScheme.outlineVariant;
    }

    final Widget node = Semantics(
      button: interactive,
      enabled: interactive,
      selected: widget.active,
      label: 'Step ${widget.index}: ${widget.label}'
          '${widget.optional ? ' (optional)' : ''}'
          '${widget.completed ? ', completed' : ''}'
          '${!widget.enabled ? ', locked' : ''}',
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: widget.compact ? 68 : 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: widget.nodeSize,
              height: widget.nodeSize,
              alignment: Alignment.center,
              transform: (_hovered || _focused) && widget.enabled
                  ? (Matrix4.identity()..scaleByDouble(1.08, 1.08, 1.0, 1.0))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: circleFill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: widget.active ? 3 : 1.5,
                ),
                boxShadow: highlight && widget.enabled
                    ? <BoxShadow>[
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: widget.completed && !widget.active
                  ? Icon(
                      Icons.check_rounded,
                      size: widget.nodeSize * 0.48,
                      color: circleFg,
                    )
                  : !widget.enabled
                  ? Icon(
                      Icons.lock_outline,
                      size: widget.nodeSize * 0.42,
                      color: circleFg,
                    )
                  : Text(
                      '${widget.index}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: circleFg,
                        fontWeight: FontWeight.w800,
                        fontSize: widget.compact ? 12 : 14,
                        height: 1,
                      ),
                    ),
            ),
            SizedBox(height: theme.spacing.sm),
            SizedBox(
              width: widget.compact ? 76 : 108,
              child: Column(
                children: <Widget>[
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: labelColor,
                      fontWeight: widget.active
                          ? FontWeight.w800
                          : FontWeight.w600,
                      height: 1.15,
                      fontSize: widget.compact ? 11 : 12,
                    ),
                  ),
                  if (widget.optional)
                    Text(
                      widget.optionalBadgeLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: labelColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: widget.compact ? 9 : 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!interactive) {
      return node;
    }

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: node,
        ),
      ),
    );
  }
}
