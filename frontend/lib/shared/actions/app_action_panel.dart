import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/actions/app_action_item.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/components/app_info_tile.dart';
import 'package:hosspi_hms/shared/components/app_permission_action.dart';
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

/// Renders a consistent responsive row/wrap of permission-gated actions.
class AppPermissionActionList extends StatelessWidget {
  const AppPermissionActionList({
    required this.actions,
    this.extraActions = const <Widget>[],
    this.spacing,
    this.runSpacing,
    this.minItemWidth,
    this.maxColumns = 3,
    super.key,
  });

  final List<AppPermissionActionItem> actions;
  final List<Widget> extraActions;
  final double? spacing;
  final double? runSpacing;
  final double? minItemWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> children = <Widget>[
      for (final AppPermissionActionItem action in actions)
        AppPermissionActionButton(
          requirement: action.requirement,
          label: action.label,
          icon: action.icon,
          variant: action.variant,
          enabled: action.enabled,
          isLoading: action.isLoading,
          fullWidth: action.fullWidth,
          hideWhenDenied: action.hideWhenDenied,
          semanticLabel: action.semanticLabel,
          tooltip: action.tooltip,
          onPressed: action.onPressed,
        ),
      ...extraActions,
    ];

    if (minItemWidth != null) {
      return AppResponsiveWrap(
        minItemWidth: minItemWidth!,
        maxColumns: maxColumns,
        spacing: spacing ?? theme.spacing.sm,
        runSpacing: runSpacing ?? spacing ?? theme.spacing.sm,
        children: children,
      );
    }

    return Wrap(
      spacing: spacing ?? theme.spacing.xs,
      runSpacing: runSpacing ?? theme.spacing.xs,
      children: children,
    );
  }
}

/// Standard titled action section for dialogs and detail content.
class AppActionSection extends StatelessWidget {
  const AppActionSection({
    required this.title,
    this.actions = const <AppActionItem>[],
    this.permissionActions = const <AppPermissionActionItem>[],
    this.extraActions = const <Widget>[],
    this.minItemWidth,
    this.maxColumns = 3,
    super.key,
  });

  final String title;
  final List<AppActionItem> actions;
  final List<AppPermissionActionItem> permissionActions;
  final List<Widget> extraActions;
  final double? minItemWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget actionList = permissionActions.isEmpty
        ? AppActionList(
            actions: actions,
            extraActions: extraActions,
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
          )
        : AppPermissionActionList(
            actions: permissionActions,
            extraActions: extraActions,
            minItemWidth: minItemWidth,
            maxColumns: maxColumns,
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
          );

    return AppSectionPanel(title: title, children: <Widget>[actionList]);
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
