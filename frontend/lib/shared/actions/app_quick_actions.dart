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
    this.description,
    this.emptyState,
    this.presentation = AppQuickActionsPresentation.section,
    this.leadingIcon = Icons.bolt_outlined,
    this.minItemWidth,
    this.maxColumns = 4,
    this.overflowLabel,
    this.hideWhenEmpty = true,
    super.key,
  }) : assert(
         actions.length == 0 || permissionActions.length == 0,
         'Use either actions or permissionActions in one quick-actions group.',
       );

  final String title;
  final String? description;
  final List<AppActionItem> actions;
  final List<AppPermissionActionItem> permissionActions;
  final Widget? emptyState;
  final AppQuickActionsPresentation presentation;
  final IconData? leadingIcon;
  final double? minItemWidth;
  final int maxColumns;
  final String? overflowLabel;
  final bool hideWhenEmpty;

  bool get _isEmpty => actions.isEmpty && permissionActions.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isEmpty && emptyState == null && hideWhenEmpty) {
      return const SizedBox.shrink();
    }

    final Widget content = _isEmpty
        ? emptyState!
        : permissionActions.isNotEmpty
        ? AppPermissionActionList(
            actions: permissionActions,
            minItemWidth: minItemWidth,
            maxColumns: maxColumns,
            overflowLabel: overflowLabel,
          )
        : AppActionList(
            actions: actions,
            minItemWidth: minItemWidth,
            maxColumns: maxColumns,
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
