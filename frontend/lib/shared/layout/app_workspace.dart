import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_state_view.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/layout/responsive_spacing.dart';

enum AppWorkspaceStatusTone { neutral, success, warning, error, info }

@immutable
final class AppWorkspaceStatus {
  const AppWorkspaceStatus({
    required this.label,
    this.tone = AppWorkspaceStatusTone.neutral,
    this.icon,
  });

  final String label;
  final AppWorkspaceStatusTone tone;
  final IconData? icon;
}

@immutable
final class AppWorkspaceActivityItem {
  const AppWorkspaceActivityItem({
    required this.title,
    required this.subtitle,
    this.description,
    this.icon,
    this.tone = AppWorkspaceStatusTone.neutral,
  });

  final String title;
  final String subtitle;
  final String? description;
  final IconData? icon;
  final AppWorkspaceStatusTone tone;
}

class AppWorkspace extends StatelessWidget {
  const AppWorkspace({
    required this.title,
    required this.description,
    required this.body,
    this.status,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
    this.summaryCards = const <Widget>[],
    this.filters,
    this.detail,
    this.activity,
    this.maxWidth = PageMaxWidth.dataHeavy,
    this.padding,
    this.scrollable = true,
    super.key,
  });

  final String title;
  final String description;
  final AppWorkspaceStatus? status;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;
  final List<Widget> summaryCards;
  final Widget? filters;
  final Widget body;
  final Widget? detail;
  final Widget? activity;
  final PageMaxWidth maxWidth;
  final EdgeInsets? padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final double contentGap = ResponsiveSpacing.contentGapFor(
      breakpoint,
      spacing: theme.spacing,
    );
    final List<Widget> children = <Widget>[
      AppWorkspaceHeader(
        title: title,
        description: description,
        status: status,
        primaryAction: primaryAction,
        secondaryActions: secondaryActions,
      ),
    ];

    if (summaryCards.isNotEmpty) {
      children
        ..add(SizedBox(height: contentGap))
        ..add(AppWorkspaceSummaryGrid(children: summaryCards));
    }

    if (filters != null) {
      children
        ..add(SizedBox(height: contentGap))
        ..add(filters!);
    }

    children
      ..add(SizedBox(height: contentGap))
      ..add(
        detail == null
            ? body
            : AppWorkspaceSplitContent(primary: body, detail: detail!),
      );

    if (activity != null) {
      children
        ..add(SizedBox(height: contentGap))
        ..add(activity!);
    }

    return ResponsivePage(
      maxWidth: maxWidth,
      padding: padding,
      scrollable: scrollable,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class AppWorkspaceHeader extends StatelessWidget {
  const AppWorkspaceHeader({
    required this.title,
    required this.description,
    this.status,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
    super.key,
  });

  final String title;
  final String description;
  final AppWorkspaceStatus? status;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final List<Widget> actions = <Widget>[...secondaryActions, ?primaryAction];
    final Widget text = _WorkspaceHeaderText(
      title: title,
      description: description,
      status: status,
    );
    final Widget actionBar = _WorkspaceHeaderActions(actions: actions);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.lg),
        child: breakpoint.isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  text,
                  if (actions.isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.spacing.md),
                    actionBar,
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: text),
                  if (actions.isNotEmpty) ...<Widget>[
                    SizedBox(width: theme.spacing.lg),
                    Flexible(child: actionBar),
                  ],
                ],
              ),
      ),
    );
  }
}

class AppWorkspaceStatusBadge extends StatelessWidget {
  const AppWorkspaceStatusBadge({required this.status, super.key});

  final AppWorkspaceStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _WorkspaceToneColors colors = _toneColors(theme, status.tone);
    final IconData icon = status.icon ?? _defaultIcon(status.tone);

    return Semantics(
      label: status.label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.container,
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: theme.appTokens.listIconSize, color: colors.on),
              SizedBox(width: theme.spacing.xs),
              Flexible(
                child: Text(
                  status.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.on,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceSummaryGrid extends StatelessWidget {
  const AppWorkspaceSummaryGrid({
    required this.children,
    this.maxColumns = 4,
    super.key,
  });

  final List<Widget> children;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = _summaryColumnCount(
          constraints.maxWidth,
          maxColumns,
        );
        final double gap = constraints.maxWidth < AppBreakpoints.md
            ? theme.spacing.md
            : theme.spacing.lg;
        final double itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class AppWorkspaceSummaryCard extends StatelessWidget {
  const AppWorkspaceSummaryCard({
    required this.label,
    required this.value,
    this.description,
    this.status,
    this.icon,
    this.onPressed,
    super.key,
  });

  final String label;
  final String value;
  final String? description;
  final AppWorkspaceStatus? status;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Widget cardBody = Padding(
      padding: EdgeInsets.all(theme.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  color: colorScheme.primary,
                  size: theme.appTokens.listIconSize,
                ),
                SizedBox(width: theme.spacing.sm),
              ],
              Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
              if (onPressed != null) ...<Widget>[
                SizedBox(width: theme.spacing.sm),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.primary,
                  size: theme.appTokens.listIconSize,
                ),
              ],
            ],
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (description != null && description!.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (status != null) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppWorkspaceStatusBadge(status: status!),
          ],
        ],
      ),
    );

    return Semantics(
      button: onPressed != null,
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onPressed, child: cardBody),
      ),
    );
  }
}

class AppWorkspaceFilterBar extends StatelessWidget {
  const AppWorkspaceFilterBar({
    this.search,
    this.filters = const <Widget>[],
    this.actions = const <Widget>[],
    this.semanticLabel,
    super.key,
  });

  final Widget? search;
  final List<Widget> filters;
  final List<Widget> actions;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < AppBreakpoints.md) {
                return _MobileFilterBar(
                  search: search,
                  filters: filters,
                  actions: actions,
                );
              }

              return _WideFilterBar(
                search: search,
                filters: filters,
                actions: actions,
              );
            },
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceSplitContent extends StatelessWidget {
  const AppWorkspaceSplitContent({
    required this.primary,
    required this.detail,
    this.detailWidth = 360,
    this.sideBySideBreakpoint = AppBreakpoints.lg,
    super.key,
  });

  final Widget primary;
  final Widget detail;
  final double detailWidth;
  final double sideBySideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < sideBySideBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              primary,
              SizedBox(height: theme.spacing.lg),
              detail,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: primary),
            SizedBox(width: theme.spacing.lg),
            SizedBox(width: detailWidth, child: detail),
          ],
        );
      },
    );
  }
}

class AppWorkspaceDetailPanel extends StatelessWidget {
  const AppWorkspaceDetailPanel({
    required this.title,
    required this.child,
    this.description,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? description;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: theme.textTheme.titleMedium),
                      if (description != null &&
                          description!.isNotEmpty) ...<Widget>[
                        SizedBox(height: theme.spacing.xs),
                        Text(
                          description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...<Widget>[
                  SizedBox(width: theme.spacing.sm),
                  Wrap(spacing: theme.spacing.xs, children: actions),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: EdgeInsets.all(theme.spacing.lg), child: child),
        ],
      ),
    );
  }
}

class AppWorkspaceStatePanel extends StatelessWidget {
  const AppWorkspaceStatePanel({
    required this.child,
    this.minHeight = 280,
    super.key,
  });

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceActivityList extends StatelessWidget {
  const AppWorkspaceActivityList({
    required this.items,
    this.title,
    this.description,
    this.emptyTitle,
    this.emptyBody,
    this.emptyAction,
    super.key,
  });

  final List<AppWorkspaceActivityItem> items;
  final String? title;
  final String? description;
  final String? emptyTitle;
  final String? emptyBody;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null || description != null)
            Padding(
              padding: EdgeInsets.all(theme.spacing.lg),
              child: _ActivityHeader(title: title, description: description),
            ),
          if (title != null || description != null) const Divider(height: 1),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.all(theme.spacing.lg),
              child: AppStateView(
                variant: AppStateViewVariant.empty,
                title: emptyTitle ?? '',
                body: emptyBody ?? '',
                action: emptyAction,
                crossAxisAlignment: CrossAxisAlignment.center,
                textAlign: TextAlign.center,
              ),
            )
          else
            for (var index = 0; index < items.length; index += 1) ...<Widget>[
              _ActivityRow(item: items[index]),
              if (index < items.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class _WorkspaceHeaderText extends StatelessWidget {
  const _WorkspaceHeaderText({
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final AppWorkspaceStatus? status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final TextStyle? titleStyle = switch (breakpoint) {
      AppBreakpoint.xs || AppBreakpoint.sm => textTheme.headlineSmall,
      _ => textTheme.headlineMedium,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: titleStyle),
        SizedBox(height: theme.spacing.sm),
        Text(
          description,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (status != null) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppWorkspaceStatusBadge(status: status!),
        ],
      ],
    );
  }
}

class _WorkspaceHeaderActions extends StatelessWidget {
  const _WorkspaceHeaderActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      alignment: WrapAlignment.end,
      children: actions,
    );
  }
}

class _MobileFilterBar extends StatelessWidget {
  const _MobileFilterBar({
    required this.search,
    required this.filters,
    required this.actions,
  });

  final Widget? search;
  final List<Widget> filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget? searchWidget = search;
    final List<Widget> children = <Widget>[
      ?searchWidget,
      ...filters,
      if (actions.isNotEmpty) _WorkspaceHeaderActions(actions: actions),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < children.length; index += 1) ...<Widget>[
          if (index > 0) SizedBox(height: theme.spacing.sm),
          children[index],
        ],
      ],
    );
  }
}

class _WideFilterBar extends StatelessWidget {
  const _WideFilterBar({
    required this.search,
    required this.filters,
    required this.actions,
  });

  final Widget? search;
  final List<Widget> filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget? searchWidget = search;
    final List<Widget> children = <Widget>[
      if (searchWidget != null)
        SizedBox(width: _searchWidth, child: searchWidget),
      for (final Widget filter in filters)
        SizedBox(width: _filterWidth, child: filter),
      ...actions,
    ];

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({required this.title, required this.description});

  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null && title!.isNotEmpty)
          Text(title!, style: theme.textTheme.titleMedium),
        if (description != null && description!.isNotEmpty) ...<Widget>[
          if (title != null && title!.isNotEmpty)
            SizedBox(height: theme.spacing.xs),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final AppWorkspaceActivityItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final _WorkspaceToneColors colors = _toneColors(theme, item.tone);

    return Padding(
      padding: EdgeInsets.all(theme.spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            item.icon ?? _defaultIcon(item.tone),
            color: colors.on,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title, style: theme.textTheme.titleSmall),
                SizedBox(height: theme.spacing.xs),
                Text(
                  item.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (item.description != null &&
                    item.description!.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(item.description!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
final class _WorkspaceToneColors {
  const _WorkspaceToneColors({
    required this.container,
    required this.on,
    required this.border,
  });

  final Color container;
  final Color on;
  final Color border;
}

int _summaryColumnCount(double width, int maxColumns) {
  final int breakpointColumns = switch (width) {
    >= 1180 => 4,
    >= 880 => 3,
    >= 600 => 2,
    _ => 1,
  };

  return breakpointColumns.clamp(1, maxColumns).toInt();
}

IconData _defaultIcon(AppWorkspaceStatusTone tone) {
  return switch (tone) {
    AppWorkspaceStatusTone.neutral => Icons.radio_button_unchecked,
    AppWorkspaceStatusTone.success => Icons.check_circle_outline,
    AppWorkspaceStatusTone.warning => Icons.warning_amber_outlined,
    AppWorkspaceStatusTone.error => Icons.error_outline,
    AppWorkspaceStatusTone.info => Icons.info_outline,
  };
}

_WorkspaceToneColors _toneColors(ThemeData theme, AppWorkspaceStatusTone tone) {
  final ColorScheme colorScheme = theme.colorScheme;
  final AppStatusColors statusColors = theme.statusColors;

  return switch (tone) {
    AppWorkspaceStatusTone.neutral => _WorkspaceToneColors(
      container: colorScheme.surfaceContainerHighest,
      on: colorScheme.onSurfaceVariant,
      border: colorScheme.outlineVariant,
    ),
    AppWorkspaceStatusTone.success => _WorkspaceToneColors(
      container: statusColors.successContainer,
      on: statusColors.onSuccessContainer,
      border: statusColors.success,
    ),
    AppWorkspaceStatusTone.warning => _WorkspaceToneColors(
      container: statusColors.warningContainer,
      on: statusColors.onWarningContainer,
      border: statusColors.warning,
    ),
    AppWorkspaceStatusTone.error => _WorkspaceToneColors(
      container: statusColors.errorContainer,
      on: statusColors.onErrorContainer,
      border: statusColors.error,
    ),
    AppWorkspaceStatusTone.info => _WorkspaceToneColors(
      container: statusColors.infoContainer,
      on: statusColors.onInfoContainer,
      border: statusColors.info,
    ),
  };
}

const double _searchWidth = 320;
const double _filterWidth = 220;
