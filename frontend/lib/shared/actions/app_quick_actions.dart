import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/actions/app_action_item.dart';
import 'package:hosspi_hms/shared/actions/app_action_panel.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Controls how a reusable quick-actions group is framed.
enum AppQuickActionsPresentation {
  /// A lightweight title and action list for embedding in existing content.
  plain,

  /// A compact bordered section for workspace-level shortcuts.
  section,

  /// A standard detail panel for record-specific actions.
  detailPanel,
}

/// A consistent, responsive quick-actions group.
///
/// Features own the action labels, eligibility, permissions, and callbacks.
/// This component owns only the shared presentation and responsive layout.
class AppQuickActions extends StatelessWidget {
  const AppQuickActions({
    required this.title,
    this.actions = const <AppActionItem>[],
    this.permissionActions = const <AppPermissionActionItem>[],
    this.extraActions = const <Widget>[],
    this.description,
    this.emptyState,
    this.presentation = AppQuickActionsPresentation.section,
    this.leadingIcon = Icons.bolt_outlined,
    this.minItemWidth,
    this.maxColumns = 4,
    this.spacing,
    this.runSpacing,
    this.overflowLabel,
    this.hideWhenEmpty = true,
    super.key,
  });

  final String title;
  final String? description;
  final List<AppActionItem> actions;
  final List<AppPermissionActionItem> permissionActions;
  final List<Widget> extraActions;
  final Widget? emptyState;
  final AppQuickActionsPresentation presentation;
  final IconData? leadingIcon;
  final double? minItemWidth;
  final int maxColumns;
  final double? spacing;
  final double? runSpacing;
  final String? overflowLabel;
  final bool hideWhenEmpty;

  bool get _isEmpty =>
      actions.isEmpty && permissionActions.isEmpty && extraActions.isEmpty;

  @override
  Widget build(BuildContext context) {
    assert(
      actions.isEmpty || permissionActions.isEmpty,
      'Use either actions or permissionActions in one quick-actions group.',
    );
    if (_isEmpty && emptyState == null && hideWhenEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final Widget content = _isEmpty
        ? emptyState!
        : permissionActions.isNotEmpty
        ? AppPermissionActionList(
            actions: permissionActions,
            extraActions: extraActions,
            minItemWidth: minItemWidth,
            maxColumns: maxColumns,
            spacing: spacing ?? theme.spacing.sm,
            runSpacing: runSpacing ?? spacing ?? theme.spacing.sm,
            overflowLabel: overflowLabel,
          )
        : AppActionList(
            actions: actions,
            extraActions: extraActions,
            minItemWidth: minItemWidth,
            maxColumns: maxColumns,
            spacing: spacing ?? theme.spacing.sm,
            runSpacing: runSpacing ?? spacing ?? theme.spacing.sm,
          );

    return switch (presentation) {
      AppQuickActionsPresentation.plain => _PlainQuickActions(
        title: title,
        description: description,
        child: content,
      ),
      AppQuickActionsPresentation.section => AppSectionPanel(
        title: title,
        description: description,
        leadingIcon: leadingIcon,
        density: AppContentPanelDensity.compact,
        children: <Widget>[content],
      ),
      AppQuickActionsPresentation.detailPanel => AppWorkspaceDetailPanel(
        title: title,
        description: description,
        titleIcon: leadingIcon,
        child: content,
      ),
    };
  }
}

class _PlainQuickActions extends StatelessWidget {
  const _PlainQuickActions({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? detail = description?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: theme.textTheme.titleSmall),
        if (detail != null && detail.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        SizedBox(height: theme.spacing.sm),
        child,
      ],
    );
  }
}
