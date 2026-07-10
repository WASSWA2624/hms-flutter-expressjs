import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

@immutable
final class AppWizardStepItem {
  const AppWizardStepItem({
    required this.id,
    required this.label,
    this.shortLabel,
  });

  final Object id;
  final String label;
  final String? shortLabel;
}

/// Horizontal progress stepper for multi-step dialogs and wizards.
class AppWizardStepper extends StatelessWidget {
  const AppWizardStepper({
    required this.steps,
    required this.currentIndex,
    this.showCurrentTitle = true,
    this.compactBreakpoint = 640,
    super.key,
  }) : assert(currentIndex >= 0);

  final List<AppWizardStepItem> steps;
  final int currentIndex;
  final bool showCurrentTitle;
  final double compactBreakpoint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final int safeIndex = currentIndex.clamp(0, steps.length - 1);
    final AppWizardStepItem current = steps[safeIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < compactBreakpoint;
            final double nodeSize = compact ? 32 : 40;
            final double connectorWidth = compact
                ? theme.spacing.md
                : theme.spacing.xl;

            return Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (int index = 0; index < steps.length; index += 1) ...<Widget>[
                          if (index > 0)
                            Padding(
                              padding: EdgeInsets.only(top: (nodeSize / 2) - 1.5),
                              child: _StepConnector(
                                completed: index <= safeIndex,
                                colorScheme: colorScheme,
                                width: connectorWidth,
                              ),
                            ),
                          _StepNode(
                            index: index + 1,
                            label: compact
                                ? (steps[index].shortLabel ?? steps[index].label)
                                : steps[index].label,
                            showLabel: true,
                            active: index == safeIndex,
                            completed: index < safeIndex,
                            nodeSize: nodeSize,
                            compact: compact,
                          ),
                        ],
                      ],
                    ),
                  ),
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
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: completed
            ? colorScheme.primary
            : colorScheme.outlineVariant.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.label,
    required this.showLabel,
    required this.active,
    required this.completed,
    required this.nodeSize,
    required this.compact,
  });

  final int index;
  final String label;
  final bool showLabel;
  final bool active;
  final bool completed;
  final double nodeSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color circleFill = active
        ? colorScheme.primary
        : completed
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final Color circleFg = active || completed
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    final Color labelColor = active
        ? colorScheme.primary
        : completed
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;

    return Semantics(
      selected: active,
      label: 'Step $index: $label',
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: compact ? 72 : 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: nodeSize,
              height: nodeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: circleFill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active || completed
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: active ? 3 : 1.5,
                ),
              ),
              child: completed && !active
                  ? Icon(Icons.check_rounded, size: nodeSize * 0.48, color: circleFg)
                  : Text(
                      '$index',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: circleFg,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 13 : 15,
                        height: 1,
                      ),
                    ),
            ),
            if (showLabel) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              SizedBox(
                width: compact ? 78 : 108,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: labelColor,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    height: 1.15,
                    fontSize: compact ? 11.5 : 12.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
