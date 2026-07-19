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
/// This component owns only the shared presentation and layout: buttons are
/// sized to their content, left-aligned, and wrap onto the next row when
/// horizontal space runs out.
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
  final double? spacing;
  final double? runSpacing;
  final String? overflowLabel;
  final bool hideWhenEmpty;

  bool get _isEmpty =>
      actions.isEmpty && permissionActions.isEmpty && extraActions.isEmpty;

  /// Buttons must hug their content so rows pack from the left; a stretched
  /// button would otherwise claim the entire wrap run.
  List<AppPermissionActionItem> get _contentSizedPermissionActions {
    return <AppPermissionActionItem>[
      for (final AppPermissionActionItem action in permissionActions)
        if (!action.fullWidth) action else _withoutFullWidth(action),
    ];
  }

  static AppPermissionActionItem _withoutFullWidth(
    AppPermissionActionItem action,
  ) {
    return AppPermissionActionItem(
      requirement: action.requirement,
      label: action.label,
      icon: action.icon,
      onPressed: action.onPressed,
      mutate: action.mutate,
      onSuccess: action.onSuccess,
      variant: action.variant,
      enabled: action.enabled,
      isLoading: action.isLoading,
      hideWhenDenied: action.hideWhenDenied,
      capabilityAllowed: action.capabilityAllowed,
      blockedReason: action.blockedReason,
      tooltip: action.tooltip,
      semanticLabel: action.semanticLabel,
      placement: action.placement,
      confirmTitle: action.confirmTitle,
      confirmBody: action.confirmBody,
      confirmSubmitLabel: action.confirmSubmitLabel,
      destructive: action.destructive,
      onlineOnly: action.onlineOnly,
      showFailureFeedback: action.showFailureFeedback,
    );
  }

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
            actions: _contentSizedPermissionActions,
            extraActions: extraActions,
            spacing: spacing ?? theme.spacing.sm,
            runSpacing: runSpacing ?? spacing ?? theme.spacing.sm,
            overflowLabel: overflowLabel,
          )
        : AppActionList(
            actions: actions,
            extraActions: extraActions,
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
