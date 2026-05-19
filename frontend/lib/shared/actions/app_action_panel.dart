import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/actions/app_action_item.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Renders a consistent responsive row/wrap of app actions.
class AppActionList extends StatelessWidget {
  const AppActionList({
    required this.actions,
    this.extraActions = const <Widget>[],
    this.spacing,
    this.runSpacing,
    super.key,
  });

  final List<AppActionItem> actions;
  final List<Widget> extraActions;
  final double? spacing;
  final double? runSpacing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: spacing ?? theme.spacing.xs,
      runSpacing: runSpacing ?? theme.spacing.xs,
      children: <Widget>[
        for (final AppActionItem action in actions) _ActionButton(action),
        ...extraActions,
      ],
    );
  }
}

/// Standard detail-panel container for module action bars.
class AppActionPanel extends StatelessWidget {
  const AppActionPanel({
    required this.title,
    required this.actions,
    this.description,
    this.extraActions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? description;
  final List<AppActionItem> actions;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: title,
      description: description,
      child: AppActionList(actions: actions, extraActions: extraActions),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.action);

  final AppActionItem action;

  @override
  Widget build(BuildContext context) {
    return switch (action.variant) {
      AppActionVariant.primary => AppButton.primary(
        label: action.label,
        leadingIcon: action.leadingIcon,
        enabled: action.enabled,
        isLoading: action.isLoading,
        tooltip: action.tooltip,
        semanticLabel: action.semanticLabel,
        onPressed: action.onPressed,
      ),
      AppActionVariant.secondary => AppButton.secondary(
        label: action.label,
        leadingIcon: action.leadingIcon,
        enabled: action.enabled,
        isLoading: action.isLoading,
        tooltip: action.tooltip,
        semanticLabel: action.semanticLabel,
        onPressed: action.onPressed,
      ),
      AppActionVariant.tertiary => AppButton.tertiary(
        label: action.label,
        leadingIcon: action.leadingIcon,
        enabled: action.enabled,
        isLoading: action.isLoading,
        tooltip: action.tooltip,
        semanticLabel: action.semanticLabel,
        onPressed: action.onPressed,
      ),
    };
  }
}
