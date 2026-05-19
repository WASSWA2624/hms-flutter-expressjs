import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
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

@immutable
final class AppWorkspacePatientContextField {
  const AppWorkspacePatientContextField({
    required this.label,
    required this.value,
    this.icon,
    this.tone = AppWorkspaceStatusTone.neutral,
  });

  final String label;
  final String value;
  final IconData? icon;
  final AppWorkspaceStatusTone tone;

  bool get hasValue => value.trim().isNotEmpty;
}

class AppWorkspace extends StatelessWidget {
  const AppWorkspace({
    required this.title,
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
    this.compactSummaryCards = false,
    super.key,
  });

  final String title;
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
  final bool compactSummaryCards;

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
        status: status,
        primaryAction: primaryAction,
        secondaryActions: secondaryActions,
      ),
    ];

    if (summaryCards.isNotEmpty) {
      children
        ..add(SizedBox(height: contentGap))
        ..add(
          AppWorkspaceSummaryGrid(
            compact: compactSummaryCards,
            children: summaryCards,
          ),
        );
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
    this.status,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
    super.key,
  });

  final String title;
  final AppWorkspaceStatus? status;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final List<Widget> actions = <Widget>[...secondaryActions, ?primaryAction];
    final Widget titleBlock = _WorkspaceHeaderText(
      title: title,
      status: status,
    );
    final Widget actionBar = _WorkspaceHeaderActions(actions: actions);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.xs),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stackHeader =
                breakpoint == AppBreakpoint.xs ||
                constraints.maxWidth < AppBreakpoints.md;

            if (stackHeader) {
              return Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(width: constraints.maxWidth, child: titleBlock),
                  if (actions.isNotEmpty) actionBar,
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: titleBlock),
                if (actions.isNotEmpty) ...<Widget>[
                  SizedBox(width: theme.spacing.md),
                  actionBar,
                ],
              ],
            );
          },
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
    this.compact = false,
    this.compactItemWidth = 218,
    super.key,
  });

  final List<Widget> children;
  final int maxColumns;
  final bool compact;
  final double compactItemWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (compact) {
          final double gap = constraints.maxWidth < AppBreakpoints.md
              ? theme.spacing.sm
              : theme.spacing.md;
          final int columns = _compactSummaryColumnCount(
            constraints.maxWidth,
            children.length,
            maxColumns,
          );
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
        }

        final int columns = _summaryColumnCount(
          constraints.maxWidth,
          maxColumns,
        );
        final double gap = constraints.maxWidth < AppBreakpoints.md
            ? theme.spacing.sm
            : theme.spacing.md;
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

class AppWorkspaceSummaryCard extends StatefulWidget {
  const AppWorkspaceSummaryCard({
    required this.label,
    required this.value,
    this.description,
    this.status,
    this.icon,
    this.tone,
    this.onPressed,
    this.compact = false,
    super.key,
  });

  final String label;
  final String value;
  final String? description;
  final AppWorkspaceStatus? status;
  final IconData? icon;
  final AppWorkspaceStatusTone? tone;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  State<AppWorkspaceSummaryCard> createState() =>
      _AppWorkspaceSummaryCardState();
}

class _AppWorkspaceSummaryCardState extends State<AppWorkspaceSummaryCard> {
  static const Duration _animationDuration = Duration(milliseconds: 160);

  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant AppWorkspaceSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null && (_hovered || _focused || _pressed)) {
      _hovered = false;
      _focused = false;
      _pressed = false;
    }
  }

  void _setHovered(bool hovered) {
    if (widget.onPressed == null || _hovered == hovered) {
      return;
    }

    setState(() {
      _hovered = hovered;
    });
  }

  void _setFocused(bool focused) {
    if (_focused == focused) {
      return;
    }

    setState(() {
      _focused = focused;
    });
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed) {
      return;
    }

    setState(() {
      _pressed = pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool interactive = widget.onPressed != null;
    final bool active = interactive && (_hovered || _focused);
    final Color accentColor = _summaryAccentColor(theme, widget.tone);
    final BorderRadius borderRadius = BorderRadius.circular(theme.radius.sm);
    final Color surfaceColor = Color.alphaBlend(
      accentColor.withValues(alpha: active ? 0.055 : 0.025),
      colorScheme.surface,
    );
    final Color borderColor = Color.alphaBlend(
      accentColor.withValues(alpha: active ? 0.34 : 0.14),
      colorScheme.outlineVariant,
    );
    final double scale = _pressed
        ? 0.985
        : active
        ? 1.01
        : 1;
    final List<BoxShadow> boxShadow = _summaryCardShadow(
      colorScheme: colorScheme,
      accentColor: accentColor,
      active: active,
      pressed: _pressed,
    );
    final Widget cardBody = _SummaryCardBody(
      label: widget.label,
      value: widget.value,
      description: widget.description,
      status: widget.status,
      icon: widget.icon,
      compact: widget.compact,
      interactive: interactive,
      active: active,
      accentColor: accentColor,
    );

    return Semantics(
      button: interactive,
      enabled: interactive ? true : null,
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) {
          _setHovered(true);
        },
        onExit: (_) {
          _setHovered(false);
        },
        child: AnimatedScale(
          duration: _animationDuration,
          curve: Curves.easeOutCubic,
          scale: scale,
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border.all(color: borderColor),
              borderRadius: borderRadius,
              boxShadow: boxShadow,
            ),
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onPressed,
                onFocusChange: _setFocused,
                onHighlightChanged: _setPressed,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                highlightColor: accentColor.withValues(alpha: 0.08),
                splashColor: accentColor.withValues(alpha: 0.10),
                child: cardBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCardBody extends StatelessWidget {
  const _SummaryCardBody({
    required this.label,
    required this.value,
    required this.compact,
    required this.interactive,
    required this.active,
    required this.accentColor,
    this.description,
    this.status,
    this.icon,
  });

  final String label;
  final String value;
  final String? description;
  final AppWorkspaceStatus? status;
  final IconData? icon;
  final bool compact;
  final bool interactive;
  final bool active;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? trimmedDescription =
        description == null || description!.trim().isEmpty
        ? null
        : description!.trim();
    final bool overlayValue = _shouldOverlaySummaryValue(value);
    final double minHeight = compact
        ? trimmedDescription == null && status == null && overlayValue
              ? 72
              : 92
        : 104;
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: compact ? theme.spacing.md : theme.spacing.lg,
      vertical: compact ? theme.spacing.sm : theme.spacing.md,
    );
    final TextStyle? labelStyle = compact
        ? theme.textTheme.titleSmall
        : theme.textTheme.titleLarge;
    final TextStyle? valueStyle = compact
        ? theme.textTheme.labelLarge
        : theme.textTheme.titleSmall;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: padding,
        child: Row(
          children: <Widget>[
            _SummaryIconTile(
              icon: icon ?? Icons.insights_outlined,
              value: value,
              showValue: overlayValue,
              compact: compact,
              active: active,
              accentColor: accentColor,
            ),
            SizedBox(width: compact ? theme.spacing.md : theme.spacing.lg),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!overlayValue) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (trimmedDescription != null) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      trimmedDescription,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (status != null) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    _CompactSummaryStatusLine(
                      status: status!,
                      fallbackColor: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
            if (interactive) ...<Widget>[
              SizedBox(width: theme.spacing.sm),
              AnimatedOpacity(
                duration: _AppWorkspaceSummaryCardState._animationDuration,
                opacity: active ? 1 : 0.58,
                child: Icon(
                  Icons.chevron_right,
                  color: accentColor,
                  size: theme.appTokens.listIconSize,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryIconTile extends StatelessWidget {
  const _SummaryIconTile({
    required this.icon,
    required this.value,
    required this.showValue,
    required this.compact,
    required this.active,
    required this.accentColor,
  });

  final IconData icon;
  final String value;
  final bool showValue;
  final bool compact;
  final bool active;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double tileSize = compact ? 48 : 58;
    final double iconSize = compact ? 24 : 28;
    final BorderRadius borderRadius = BorderRadius.circular(theme.radius.sm);

    return SizedBox(
      width: tileSize + (showValue ? theme.spacing.sm : 0),
      height: tileSize + (showValue ? theme.spacing.sm : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: _AppWorkspaceSummaryCardState._animationDuration,
              curve: Curves.easeOutCubic,
              width: tileSize,
              height: tileSize,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: active ? 0.13 : 0.08),
                border: Border.all(
                  color: accentColor.withValues(alpha: active ? 0.28 : 0.16),
                ),
                borderRadius: borderRadius,
              ),
              child: Center(
                child: Icon(icon, color: accentColor, size: iconSize),
              ),
            ),
          ),
          if (showValue)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: _SummaryValueBadge(
                value: value,
                compact: compact,
                accentColor: accentColor,
                foregroundColor: _onSummaryAccentColor(
                  accentColor,
                  colorScheme,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryValueBadge extends StatelessWidget {
  const _SummaryValueBadge({
    required this.value,
    required this.compact,
    required this.accentColor,
    required this.foregroundColor,
  });

  final String value;
  final bool compact;
  final Color accentColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double minWidth = compact ? 28 : 34;
    final double height = compact ? 24 : 28;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accentColor,
        border: Border.all(
          color: theme.colorScheme.surface.withValues(alpha: 0.90),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(theme.radius.sm),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accentColor.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth,
          maxWidth: compact ? 68 : 86,
          minHeight: height,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
          child: Center(
            child: Text(
              value.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _summaryAccentColor(ThemeData theme, AppWorkspaceStatusTone? tone) {
  final ColorScheme colorScheme = theme.colorScheme;
  final AppStatusColors statusColors = theme.statusColors;

  return switch (tone) {
    null || AppWorkspaceStatusTone.neutral => colorScheme.primary,
    AppWorkspaceStatusTone.success => statusColors.success,
    AppWorkspaceStatusTone.warning => statusColors.warning,
    AppWorkspaceStatusTone.error => statusColors.error,
    AppWorkspaceStatusTone.info => statusColors.info,
  };
}

Color _onSummaryAccentColor(Color accentColor, ColorScheme colorScheme) {
  final Brightness brightness = ThemeData.estimateBrightnessForColor(
    accentColor,
  );

  return brightness == Brightness.dark ? Colors.white : colorScheme.onSurface;
}

List<BoxShadow> _summaryCardShadow({
  required ColorScheme colorScheme,
  required Color accentColor,
  required bool active,
  required bool pressed,
}) {
  if (pressed) {
    return <BoxShadow>[
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.08),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
      BoxShadow(
        color: accentColor.withValues(alpha: 0.08),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];
  }

  if (active) {
    return <BoxShadow>[
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.10),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: accentColor.withValues(alpha: 0.16),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }

  return <BoxShadow>[
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ];
}

bool _shouldOverlaySummaryValue(String value) {
  final String text = value.trim();
  if (text.isEmpty || text.contains('\n') || text.length > 8) {
    return false;
  }

  final Iterable<String> words = text
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty);
  return words.length <= 2;
}

class _CompactSummaryStatusLine extends StatelessWidget {
  const _CompactSummaryStatusLine({
    required this.status,
    required this.fallbackColor,
  });

  final AppWorkspaceStatus status;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _WorkspaceToneColors colors = _toneColors(theme, status.tone);

    return Row(
      children: <Widget>[
        Icon(
          status.icon ?? _defaultIcon(status.tone),
          color: colors.on,
          size: 16,
        ),
        SizedBox(width: theme.spacing.xs),
        Expanded(
          child: Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.on == Colors.transparent
                  ? fallbackColor
                  : colors.on,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class AppWorkspaceFilterBar extends StatelessWidget {
  const AppWorkspaceFilterBar({
    this.search,
    this.filters = const <Widget>[],
    this.actions = const <Widget>[],
    this.semanticLabel,
    this.expandSearch = false,
    super.key,
  });

  final Widget? search;
  final List<Widget> filters;
  final List<Widget> actions;
  final String? semanticLabel;
  final bool expandSearch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Semantics(
        container: true,
        label: semanticLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.xs),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth < 480) {
                  return _MobileFilterBar(
                    search: search,
                    filters: filters,
                    actions: actions,
                  );
                }

                return _WideFilterBar(
                  expandSearch: expandSearch,
                  search: search,
                  filters: filters,
                  actions: actions,
                );
              },
            ),
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

class AppWorkspacePatientContextHeader extends StatelessWidget {
  const AppWorkspacePatientContextHeader({
    required this.patientName,
    required this.patientNumber,
    this.patientNumberLabel,
    this.demographics,
    this.status,
    this.alerts = const <AppWorkspaceStatus>[],
    this.fields = const <AppWorkspacePatientContextField>[],
    this.actions = const <Widget>[],
    this.onCopyPatientNumber,
    this.copyPatientNumberTooltip,
    this.semanticLabel,
    super.key,
  });

  final String patientName;
  final String patientNumber;
  final String? patientNumberLabel;
  final String? demographics;
  final AppWorkspaceStatus? status;
  final List<AppWorkspaceStatus> alerts;
  final List<AppWorkspacePatientContextField> fields;
  final List<Widget> actions;
  final VoidCallback? onCopyPatientNumber;
  final String? copyPatientNumberTooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<AppWorkspacePatientContextField> visibleFields = fields
        .where((AppWorkspacePatientContextField field) => field.hasValue)
        .toList(growable: false);
    Widget header = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < AppBreakpoints.md;
            final Widget identity = _PatientContextIdentity(
              patientName: patientName,
              patientNumber: patientNumber,
              patientNumberLabel: patientNumberLabel,
              demographics: demographics,
              status: status,
              alerts: alerts,
              onCopyPatientNumber: onCopyPatientNumber,
              copyPatientNumberTooltip: copyPatientNumberTooltip,
            );
            final Widget? actionBar = actions.isEmpty
                ? null
                : _WorkspaceHeaderActions(actions: actions);
            final List<Widget> children = <Widget>[
              compact || actionBar == null
                  ? identity
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: identity),
                        SizedBox(width: theme.spacing.md),
                        Flexible(child: actionBar),
                      ],
                    ),
            ];

            if (compact && actionBar != null) {
              children
                ..add(SizedBox(height: theme.spacing.md))
                ..add(actionBar);
            }

            if (visibleFields.isNotEmpty) {
              children
                ..add(SizedBox(height: theme.spacing.md))
                ..add(_PatientContextFieldGrid(fields: visibleFields));
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            );
          },
        ),
      ),
    );

    if (semanticLabel != null) {
      header = Semantics(container: true, label: semanticLabel, child: header);
    }

    return header;
  }
}

class AppWorkspaceStatePanel extends StatelessWidget {
  const AppWorkspaceStatePanel({
    required this.child,
    this.minHeight = 280,
    super.key,
  }) : _stateVariant = null,
       _stateTitle = null,
       _stateBody = null,
       _stateIcon = null,
       _stateDetail = null,
       _stateAction = null,
       _stateSemanticLabel = null,
       _stateCrossAxisAlignment = CrossAxisAlignment.center,
       _stateTextAlign = TextAlign.center;

  const AppWorkspaceStatePanel.state({
    required AppStateViewVariant variant,
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextAlign textAlign = TextAlign.center,
    this.minHeight = 280,
    super.key,
  }) : child = null,
       _stateVariant = variant,
       _stateTitle = title,
       _stateBody = body,
       _stateIcon = icon,
       _stateDetail = detail,
       _stateAction = action,
       _stateSemanticLabel = semanticLabel,
       _stateCrossAxisAlignment = crossAxisAlignment,
       _stateTextAlign = textAlign;

  const AppWorkspaceStatePanel.loading({
    required String title,
    required String body,
    String? detail,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.loading,
         title: title,
         body: body,
         detail: detail,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.empty({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.empty,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.error({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.error,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.forbidden({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.forbidden,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.offline({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.offline,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.validation({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.validation,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.success({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.success,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  final Widget? child;
  final double minHeight;
  final AppStateViewVariant? _stateVariant;
  final String? _stateTitle;
  final String? _stateBody;
  final IconData? _stateIcon;
  final String? _stateDetail;
  final Widget? _stateAction;
  final String? _stateSemanticLabel;
  final CrossAxisAlignment _stateCrossAxisAlignment;
  final TextAlign _stateTextAlign;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Widget content =
        child ??
        AppStateView(
          variant: _stateVariant!,
          icon: _stateIcon,
          title: _stateTitle!,
          body: _stateBody!,
          detail: _stateDetail,
          action: _stateAction,
          semanticLabel: _stateSemanticLabel,
          crossAxisAlignment: _stateCrossAxisAlignment,
          textAlign: _stateTextAlign,
        );

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
            child: content,
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceDetailDrawer extends StatelessWidget {
  const AppWorkspaceDetailDrawer({
    required this.title,
    required this.child,
    this.description,
    this.actions = const <Widget>[],
    this.icon,
    this.semanticLabel,
    this.scrollable = true,
    this.showCloseButton = true,
    this.closeEnabled = true,
    this.maxWidth = _defaultDrawerWidth,
    super.key,
  });

  final Widget title;
  final Widget child;
  final Widget? description;
  final List<Widget> actions;
  final Widget? icon;
  final String? semanticLabel;
  final bool scrollable;
  final bool showCloseButton;
  final bool closeEnabled;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Size viewport = MediaQuery.sizeOf(context);
    final double width = viewport.width < AppBreakpoints.md
        ? viewport.width
        : maxWidth.clamp(theme.spacing.none, viewport.width).toDouble();
    final Widget content = scrollable
        ? SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: child,
          )
        : child;
    Widget drawer = Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Material(
          color: colorScheme.surface,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _WorkspaceDrawerHeader(
                    title: title,
                    description: description,
                    icon: icon,
                    showCloseButton: showCloseButton,
                    closeEnabled: closeEnabled,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(theme.spacing.lg),
                      child: content,
                    ),
                  ),
                  if (actions.isNotEmpty)
                    _WorkspaceDrawerActions(actions: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (semanticLabel != null) {
      drawer = Semantics(
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        label: semanticLabel,
        child: drawer,
      );
    }

    return FocusTraversalGroup(child: drawer);
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

class _PatientContextIdentity extends StatelessWidget {
  const _PatientContextIdentity({
    required this.patientName,
    required this.patientNumber,
    required this.patientNumberLabel,
    required this.demographics,
    required this.status,
    required this.alerts,
    required this.onCopyPatientNumber,
    required this.copyPatientNumberTooltip,
  });

  final String patientName;
  final String patientNumber;
  final String? patientNumberLabel;
  final String? demographics;
  final AppWorkspaceStatus? status;
  final List<AppWorkspaceStatus> alerts;
  final VoidCallback? onCopyPatientNumber;
  final String? copyPatientNumberTooltip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            border: Border.all(color: colorScheme.primary),
          ),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(
              Icons.person_outline,
              color: colorScheme.onPrimaryContainer,
              size: theme.appTokens.listIconSize,
            ),
          ),
        ),
        SizedBox(width: theme.spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                patientName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              _PatientContextMetaLine(
                patientNumber: patientNumber,
                patientNumberLabel: patientNumberLabel,
                demographics: demographics,
                status: status,
                onCopyPatientNumber: onCopyPatientNumber,
                copyPatientNumberTooltip: copyPatientNumberTooltip,
              ),
              if (alerts.isNotEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                _PatientContextAlerts(alerts: alerts),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PatientContextMetaLine extends StatelessWidget {
  const _PatientContextMetaLine({
    required this.patientNumber,
    required this.patientNumberLabel,
    required this.demographics,
    required this.status,
    required this.onCopyPatientNumber,
    required this.copyPatientNumberTooltip,
  });

  final String patientNumber;
  final String? patientNumberLabel;
  final String? demographics;
  final AppWorkspaceStatus? status;
  final VoidCallback? onCopyPatientNumber;
  final String? copyPatientNumberTooltip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<Widget> items = <Widget>[
      if (patientNumber.trim().isNotEmpty)
        _PatientContextNumberToken(
          label: patientNumberLabel,
          value: patientNumber,
          onCopy: onCopyPatientNumber,
          copyTooltip: copyPatientNumberTooltip,
        ),
      if (demographics != null && demographics!.trim().isNotEmpty)
        Text(
          demographics!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      if (status != null) AppWorkspaceStatusBadge(status: status!),
    ];

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }
}

class _PatientContextNumberToken extends StatelessWidget {
  const _PatientContextNumberToken({
    required this.value,
    this.label,
    this.onCopy,
    this.copyTooltip,
  });

  final String? label;
  final String value;
  final VoidCallback? onCopy;
  final String? copyTooltip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle? labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    final TextStyle? valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w800,
    );
    final String? resolvedLabel = label?.trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: theme.spacing.sm,
            top: theme.spacing.xs,
            bottom: theme.spacing.xs,
            end: onCopy == null ? theme.spacing.sm : theme.spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (resolvedLabel != null && resolvedLabel.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    resolvedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
                SizedBox(width: theme.spacing.xs),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
              if (onCopy != null) ...<Widget>[
                SizedBox(width: theme.spacing.xs),
                Tooltip(
                  message:
                      copyTooltip ??
                      MaterialLocalizations.of(context).copyButtonLabel,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(
                      width: theme.appTokens.minInteractiveDimension,
                      height: theme.appTokens.minInteractiveDimension,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onCopy,
                    icon: Icon(
                      Icons.copy_outlined,
                      size: theme.appTokens.listIconSize,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientContextAlerts extends StatelessWidget {
  const _PatientContextAlerts({required this.alerts});

  final List<AppWorkspaceStatus> alerts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (final AppWorkspaceStatus alert in alerts)
          AppWorkspaceStatusBadge(status: alert),
      ],
    );
  }
}

class _PatientContextFieldGrid extends StatelessWidget {
  const _PatientContextFieldGrid({required this.fields});

  final List<AppWorkspacePatientContextField> fields;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = constraints.maxWidth < AppBreakpoints.md
            ? theme.spacing.sm
            : theme.spacing.md;
        final int columns = _patientContextColumnCount(
          constraints.maxWidth,
          fields.length,
        );
        final double itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final AppWorkspacePatientContextField field in fields)
              SizedBox(
                width: itemWidth,
                child: _PatientContextFieldTile(field: field),
              ),
          ],
        );
      },
    );
  }
}

class _PatientContextFieldTile extends StatelessWidget {
  const _PatientContextFieldTile({required this.field});

  final AppWorkspacePatientContextField field;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool neutralTone = field.tone == AppWorkspaceStatusTone.neutral;
    final _WorkspaceToneColors colors = _toneColors(theme, field.tone);
    final Color borderColor = neutralTone
        ? colorScheme.outlineVariant
        : colors.border;
    final Color labelColor = neutralTone
        ? colorScheme.onSurfaceVariant
        : colors.on;
    final Color iconColor = neutralTone ? colorScheme.primary : colors.on;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: neutralTone
            ? colorScheme.surfaceContainerLowest
            : colors.container,
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (field.icon != null) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.xs),
                child: Icon(
                  field.icon,
                  color: iconColor,
                  size: theme.appTokens.listIconSize,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    field.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    field.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: neutralTone ? colorScheme.onSurface : colors.on,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceDrawerHeader extends StatelessWidget {
  const _WorkspaceDrawerHeader({
    required this.title,
    required this.description,
    required this.icon,
    required this.showCloseButton,
    required this.closeEnabled,
  });

  final Widget title;
  final Widget? description;
  final Widget? icon;
  final bool showCloseButton;
  final bool closeEnabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: theme.spacing.lg,
          top: theme.spacing.md,
          bottom: theme.spacing.md,
          end: theme.spacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.xs),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: colorScheme.primary,
                    size: theme.appTokens.listIconSize,
                  ),
                  child: icon!,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DefaultTextStyle(
                    style:
                        theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ) ??
                        TextStyle(color: colorScheme.onSurface, fontSize: 22),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                  if (description != null) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    DefaultTextStyle(
                      style:
                          theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ) ??
                          TextStyle(color: colorScheme.onSurfaceVariant),
                      child: description!,
                    ),
                  ],
                ],
              ),
            ),
            if (showCloseButton)
              Tooltip(
                message: MaterialLocalizations.of(context).closeButtonTooltip,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: closeEnabled
                      ? () {
                          Navigator.of(context).maybePop();
                        }
                      : null,
                  icon: const Icon(Icons.close),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceDrawerActions extends StatelessWidget {
  const _WorkspaceDrawerActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: OverflowBar(
          alignment: MainAxisAlignment.end,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: theme.spacing.sm,
          overflowSpacing: theme.spacing.sm,
          children: actions,
        ),
      ),
    );
  }
}

class _WorkspaceHeaderText extends StatelessWidget {
  const _WorkspaceHeaderText({required this.title, required this.status});

  final String title;
  final AppWorkspaceStatus? status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final TextStyle? titleStyle = switch (breakpoint) {
      AppBreakpoint.xs ||
      AppBreakpoint.sm ||
      AppBreakpoint.md => textTheme.titleLarge,
      _ => textTheme.headlineSmall,
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth < AppBreakpoints.sm;

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (status != null) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                AppWorkspaceStatusBadge(status: status!),
              ],
            ],
          );
        }

        return Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (status != null) AppWorkspaceStatusBadge(status: status!),
          ],
        );
      },
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
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
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
    required this.expandSearch,
    required this.search,
    required this.filters,
    required this.actions,
  });

  final bool expandSearch;
  final Widget? search;
  final List<Widget> filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget? searchWidget = search;

    if (expandSearch) {
      return Row(
        children: <Widget>[
          if (searchWidget != null) Expanded(child: searchWidget),
          for (final Widget filter in filters) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            SizedBox(width: _filterWidth, child: filter),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            _WorkspaceHeaderActions(actions: actions),
          ],
        ],
      );
    }

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
    >= 1080 => 4,
    >= 760 => 3,
    >= 480 => 2,
    _ => 1,
  };

  return breakpointColumns.clamp(1, maxColumns).toInt();
}

int _compactSummaryColumnCount(double width, int childCount, int maxColumns) {
  final int effectiveMaxColumns = math.min(childCount, maxColumns);
  if (effectiveMaxColumns <= 0) {
    return 1;
  }

  final int breakpointColumns = switch (width) {
    >= 920 => 4,
    >= 700 => 3,
    >= 480 => 2,
    _ => 1,
  };

  return breakpointColumns.clamp(1, effectiveMaxColumns).toInt();
}

int _patientContextColumnCount(double width, int childCount) {
  if (childCount <= 0) {
    return 1;
  }

  final int breakpointColumns = switch (width) {
    >= 980 => 4,
    >= 720 => 3,
    >= 460 => 2,
    _ => 1,
  };

  return math.min(childCount, breakpointColumns).clamp(1, childCount).toInt();
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

Future<T?> showAppWorkspaceActionDialog<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  List<Widget> actions = const <Widget>[],
  Widget? icon,
  String? semanticLabel,
  bool barrierDismissible = false,
  bool scrollable = true,
  bool showCloseButton = true,
  bool closeEnabled = true,
  double maxWidth = 600,
  RouteSettings? routeSettings,
}) {
  return showAppDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    routeSettings: routeSettings,
    builder: (_) => AppDialog(
      title: title,
      content: content,
      actions: actions,
      icon: icon,
      semanticLabel: semanticLabel,
      scrollable: scrollable,
      showCloseButton: showCloseButton,
      closeEnabled: closeEnabled,
      maxWidth: maxWidth,
    ),
  );
}

Future<T?> showAppWorkspaceDetailDrawer<T>({
  required BuildContext context,
  required Widget title,
  required Widget child,
  Widget? description,
  List<Widget> actions = const <Widget>[],
  Widget? icon,
  String? semanticLabel,
  String? barrierLabel,
  bool barrierDismissible = true,
  bool scrollable = true,
  bool showCloseButton = true,
  bool closeEnabled = true,
  double maxWidth = _defaultDrawerWidth,
  RouteSettings? routeSettings,
}) async {
  final FocusNode? previousFocus = FocusManager.instance.primaryFocus;
  final String resolvedBarrierLabel =
      barrierLabel ??
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final T? result = await showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: resolvedBarrierLabel,
    routeSettings: routeSettings,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return AppWorkspaceDetailDrawer(
            title: title,
            description: description,
            actions: actions,
            icon: icon,
            semanticLabel: semanticLabel,
            scrollable: scrollable,
            showCloseButton: showCloseButton,
            closeEnabled: closeEnabled,
            maxWidth: maxWidth,
            child: child,
          );
        },
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final TextDirection textDirection = Directionality.of(context);
          final double beginOffset = textDirection == TextDirection.rtl
              ? -1
              : 1;
          final Animation<Offset> position = animation.drive(
            Tween<Offset>(
              begin: Offset(beginOffset, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          );

          return SlideTransition(position: position, child: child);
        },
  );

  if (previousFocus case final FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? previousContext = node.context;
      if (previousContext != null &&
          previousContext.mounted &&
          node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }

  return result;
}

const double _searchWidth = 280;
const double _filterWidth = 220;
const double _defaultDrawerWidth = 480;
