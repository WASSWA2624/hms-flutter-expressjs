import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum AppContentPanelDensity { compact, regular, spacious }

class AppContentPanel extends StatelessWidget {
  const AppContentPanel({
    required this.child,
    this.tone = AppWorkspaceStatusTone.neutral,
    this.density = AppContentPanelDensity.regular,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final AppWorkspaceStatusTone tone;
  final AppContentPanelDensity density;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;

  /// When null, uses the default responsive large radius.
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _AppPanelToneColors colors = _toneColors(theme, tone);
    final BorderRadiusGeometry resolvedRadius =
        borderRadius ??
        BorderRadius.circular(context.responsiveRadius(theme.radius.lg));

    return Material(
      color: backgroundColor ?? colors.container,
      shape: RoundedRectangleBorder(
        borderRadius: resolvedRadius,
        side: theme.borders.side(color: borderColor ?? colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding ?? _padding(theme), child: child),
    );
  }

  EdgeInsetsGeometry _padding(ThemeData theme) {
    return EdgeInsets.all(switch (density) {
      AppContentPanelDensity.compact => theme.spacing.sm,
      AppContentPanelDensity.regular => theme.spacing.md,
      AppContentPanelDensity.spacious => theme.spacing.md,
    });
  }
}

/// Convenience builder for titled or toned content blocks.
///
/// Titled usage builds [AppCollapsibleSection] — the app's only section chrome.
/// Prefer [AppCollapsibleSection] directly when you do not need untitled
/// [AppContentPanel] tone framing or child gap stacking.
class AppSectionPanel extends StatelessWidget {
  const AppSectionPanel({
    required this.children,
    this.title,
    this.subtitle,
    this.description,
    this.leadingIcon,
    this.trailing,
    this.actions = const <Widget>[],
    this.tone = AppWorkspaceStatusTone.neutral,
    this.density = AppContentPanelDensity.regular,
    this.spacing,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.backgroundColor,
    this.borderColor,
    this.collapsible = true,
    this.initiallyExpanded = true,
    this.expanded,
    this.onExpandedChanged,
    super.key,
  });

  final String? title;

  /// Secondary line under [title] in the section header.
  final String? subtitle;
  final String? description;
  final IconData? leadingIcon;
  final Widget? trailing;

  /// Optional controls rendered below the section body (see [AppCollapsibleSection.actions]).
  final List<Widget> actions;
  final List<Widget> children;
  final AppWorkspaceStatusTone tone;
  final AppContentPanelDensity density;
  final double? spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final Color? backgroundColor;
  final Color? borderColor;

  /// Forwarded to [AppCollapsibleSection] for titled sections.
  final bool collapsible;
  final bool initiallyExpanded;

  /// When non-null, expansion is controlled by the parent.
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = spacing ?? _spacing(theme);
    final String? resolvedTitle = title?.trim().isNotEmpty == true
        ? title
        : null;
    final Widget body = Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < children.length; index += 1) ...<Widget>[
          children[index],
          if (index < children.length - 1) SizedBox(height: gap),
        ],
      ],
    );

    // Titled sections use the shared collapsible section chrome.
    if (resolvedTitle != null) {
      return AppCollapsibleSection(
        title: resolvedTitle,
        subtitle: subtitle,
        description: description,
        titleIcon: leadingIcon,
        headerActions: trailing == null
            ? const <Widget>[]
            : <Widget>[trailing!],
        actions: actions,
        collapsible: collapsible,
        initiallyExpanded: initiallyExpanded,
        expanded: expanded,
        onExpandedChanged: onExpandedChanged,
        contentPadding: EdgeInsets.all(_contentPadding(theme)),
        child: body,
      );
    }

    // Untitled panels remain compact content chrome (not section headers).
    final bool hasHeader = description != null || leadingIcon != null;
    return AppContentPanel(
      tone: tone,
      density: density,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasHeader)
            _AppSectionPanelHeader(
              title: null,
              description: description,
              leadingIcon: leadingIcon,
              trailing: trailing,
              tone: tone,
            ),
          if (hasHeader && children.isNotEmpty) SizedBox(height: gap),
          body,
        ],
      ),
    );
  }

  double _spacing(ThemeData theme) {
    return switch (density) {
      AppContentPanelDensity.compact => theme.spacing.sm,
      AppContentPanelDensity.regular => theme.spacing.md,
      AppContentPanelDensity.spacious => theme.spacing.md,
    };
  }

  double _contentPadding(ThemeData theme) {
    return switch (density) {
      AppContentPanelDensity.compact => theme.spacing.sm,
      AppContentPanelDensity.regular => theme.spacing.md,
      AppContentPanelDensity.spacious => theme.spacing.md,
    };
  }
}

class AppMessagePanel extends StatelessWidget {
  const AppMessagePanel({
    required this.message,
    this.title,
    this.icon,
    this.tone = AppWorkspaceStatusTone.info,
    this.density = AppContentPanelDensity.regular,
    this.children = const <Widget>[],
    super.key,
  });

  final String? title;
  final String message;
  final IconData? icon;
  final AppWorkspaceStatusTone tone;
  final AppContentPanelDensity density;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _AppPanelToneColors colors = _toneColors(theme, tone);

    return AppContentPanel(
      tone: tone,
      density: density,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon ?? _defaultIcon(tone),
            color: colors.accent,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onContainer,
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onContainer,
                  ),
                ),
                for (final Widget child in children) ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppSectionPanelHeader extends StatelessWidget {
  const _AppSectionPanelHeader({
    required this.title,
    required this.description,
    required this.leadingIcon,
    required this.trailing,
    required this.tone,
  });

  final String? title;
  final String? description;
  final IconData? leadingIcon;
  final Widget? trailing;
  final AppWorkspaceStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _AppPanelToneColors colors = _toneColors(theme, tone);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (leadingIcon != null) ...<Widget>[
          Icon(
            leadingIcon,
            color: colors.accent,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (title != null)
                Text(
                  title!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onContainer,
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
              if (description != null) ...<Widget>[
                if (title != null) SizedBox(height: theme.spacing.xs),
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          SizedBox(width: theme.spacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

@immutable
final class _AppPanelToneColors {
  const _AppPanelToneColors({
    required this.container,
    required this.onContainer,
    required this.secondaryText,
    required this.border,
    required this.accent,
  });

  final Color container;
  final Color onContainer;
  final Color secondaryText;
  final Color border;
  final Color accent;
}

_AppPanelToneColors _toneColors(ThemeData theme, AppWorkspaceStatusTone tone) {
  final ColorScheme colorScheme = theme.colorScheme;
  final AppStatusColors statusColors = theme.statusColors;

  return switch (tone) {
    AppWorkspaceStatusTone.neutral => _AppPanelToneColors(
      container: colorScheme.surfaceContainerLowest,
      onContainer: colorScheme.onSurface,
      secondaryText: colorScheme.onSurfaceVariant,
      border: theme.borders.faint,
      accent: colorScheme.primary,
    ),
    AppWorkspaceStatusTone.success => _AppPanelToneColors(
      container: statusColors.successContainer,
      onContainer: statusColors.onSuccessContainer,
      secondaryText: statusColors.onSuccessContainer,
      border: statusColors.success,
      accent: statusColors.success,
    ),
    AppWorkspaceStatusTone.warning => _AppPanelToneColors(
      container: statusColors.warningContainer,
      onContainer: statusColors.onWarningContainer,
      secondaryText: statusColors.onWarningContainer,
      border: statusColors.warning,
      accent: statusColors.warning,
    ),
    AppWorkspaceStatusTone.error => _AppPanelToneColors(
      container: statusColors.errorContainer,
      onContainer: statusColors.onErrorContainer,
      secondaryText: statusColors.onErrorContainer,
      border: statusColors.error,
      accent: statusColors.error,
    ),
    AppWorkspaceStatusTone.info => _AppPanelToneColors(
      container: statusColors.infoContainer,
      onContainer: statusColors.onInfoContainer,
      secondaryText: statusColors.onInfoContainer,
      border: statusColors.info,
      accent: statusColors.info,
    ),
  };
}

IconData _defaultIcon(AppWorkspaceStatusTone tone) {
  return switch (tone) {
    AppWorkspaceStatusTone.neutral => Icons.info_outline,
    AppWorkspaceStatusTone.success => Icons.check_circle_outline,
    AppWorkspaceStatusTone.warning => Icons.warning_amber_outlined,
    AppWorkspaceStatusTone.error => Icons.error_outline,
    AppWorkspaceStatusTone.info => Icons.info_outline,
  };
}
