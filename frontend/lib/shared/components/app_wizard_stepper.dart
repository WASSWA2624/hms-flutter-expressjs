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
    this.compactBreakpoint = 560,
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
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (int index = 0; index < steps.length; index += 1) ...<Widget>[
                    if (index > 0)
                      _StepConnector(
                        completed: index <= safeIndex,
                        colorScheme: colorScheme,
                        theme: theme,
                      ),
                    _StepNode(
                      index: index + 1,
                      label: compact
                          ? (steps[index].shortLabel ?? steps[index].label)
                          : steps[index].label,
                      showLabel: !compact || index == safeIndex,
                      active: index == safeIndex,
                      completed: index < safeIndex,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        if (showCurrentTitle) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          Text(
            current.label,
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
    required this.theme,
  });

  final bool completed;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: theme.spacing.lg,
      height: 2,
      margin: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
      decoration: BoxDecoration(
        color: completed
            ? colorScheme.primary.withValues(alpha: 0.55)
            : colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(theme.radius.full),
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
  });

  final int index;
  final String label;
  final bool showLabel;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color circleFill = active
        ? colorScheme.primary
        : completed
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final Color circleFg = active
        ? colorScheme.onPrimary
        : completed
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final Color labelColor = active || completed
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;

    return Semantics(
      selected: active,
      label: 'Step $index: $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: circleFill,
              shape: BoxShape.circle,
              border: Border.all(
                color: active || completed
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            child: completed && !active
                ? Icon(Icons.check, size: 16, color: circleFg)
                : Text(
                    '$index',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: circleFg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          if (showLabel) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: labelColor,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
