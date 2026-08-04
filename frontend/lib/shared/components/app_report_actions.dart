import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum AppReportActionKind { print, export, download, copy, preview }

class AppReportActionButton extends StatelessWidget {
  const AppReportActionButton({
    required this.label,
    required this.onPressed,
    this.kind = AppReportActionKind.print,
    this.variant = AppButtonVariant.secondary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    super.key,
  });

  const AppReportActionButton.print({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    super.key,
  }) : kind = AppReportActionKind.print;

  const AppReportActionButton.export({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    super.key,
  }) : kind = AppReportActionKind.export;

  const AppReportActionButton.download({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    super.key,
  }) : kind = AppReportActionKind.download;

  const AppReportActionButton.copy({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    super.key,
  }) : kind = AppReportActionKind.copy;

  const AppReportActionButton.preview({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
    super.key,
  }) : kind = AppReportActionKind.preview;

  final String label;
  final VoidCallback? onPressed;
  final AppReportActionKind kind;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;
  final bool fullWidth;
  final String? semanticLabel;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      variant: variant,
      leadingIcon: icon ?? _defaultIcon(kind),
      isLoading: isLoading,
      enabled: enabled,
      fullWidth: fullWidth,
      semanticLabel: semanticLabel,
      tooltip: tooltip,
    );
  }
}

@immutable
final class AppReportSummaryItem {
  const AppReportSummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    this.semanticLabel,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? semanticLabel;
}

class AppReportSummaryGrid extends StatelessWidget {
  const AppReportSummaryGrid({
    required this.records,
    this.maxColumns = 4,
    this.minTileWidth = 132,
    super.key,
  });

  final List<AppReportSummaryItem> records;
  final int maxColumns;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = _columnCount(
          constraints.maxWidth,
          records.length,
          maxColumns,
          minTileWidth,
        );
        final double gap = constraints.maxWidth < AppBreakpoints.md
            ? theme.spacing.xs
            : theme.spacing.sm;
        final double tileWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final AppReportSummaryItem record in records)
              SizedBox(
                width: tileWidth,
                child: _ReportSummaryTile(record: record),
              ),
          ],
        );
      },
    );
  }
}

class AppReportPreviewPanel extends StatelessWidget {
  const AppReportPreviewPanel({
    required this.child,
    this.title,
    this.semanticLabel,
    this.selectable = false,
    this.collapsible = true,
    this.initiallyExpanded = true,
    this.headerActions = const <Widget>[],
    this.maxBodyHeight,
    this.scrollBody = true,
    this.contentPadding,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? semanticLabel;
  final bool selectable;
  final bool collapsible;
  final bool initiallyExpanded;
  final List<Widget> headerActions;

  /// When set, the preview body is constrained to this height.
  final double? maxBodyHeight;

  /// When true (default), the constrained body scrolls in Flutter.
  /// Set false for embedded HTML previews that scroll inside an iframe.
  final bool scrollBody;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? resolvedTitle = title?.trim().isNotEmpty == true
        ? title
        : null;
    Widget content = child;

    if (selectable) {
      content = SelectionArea(child: content);
    }

    final EdgeInsetsGeometry padding =
        contentPadding ?? EdgeInsets.all(theme.spacing.md);
    if (maxBodyHeight != null) {
      final Widget padded = scrollBody
          ? Padding(padding: padding, child: content)
          : Padding(
              padding: padding,
              child: SizedBox.expand(child: content),
            );
      content = SizedBox(
        height: maxBodyHeight,
        width: double.infinity,
        child: scrollBody
            ? ClipRect(child: SingleChildScrollView(child: padded))
            : padded,
      );
    } else {
      content = Padding(padding: padding, child: content);
    }

    if (resolvedTitle != null) {
      return Semantics(
        container: true,
        label: semanticLabel ?? resolvedTitle,
        child: AppCollapsibleSection(
          title: resolvedTitle,
          collapsible: collapsible,
          initiallyExpanded: initiallyExpanded,
          headerActions: headerActions,
          contentPadding: EdgeInsets.zero,
          child: content,
        ),
      );
    }

    return Semantics(
      container: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          border: theme.borders.all(),
        ),
        child: content,
      ),
    );
  }
}

class _ReportSummaryTile extends StatelessWidget {
  const _ReportSummaryTile({required this.record});

  final AppReportSummaryItem record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: record.semanticLabel ?? '${record.label}: ${record.value}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: theme.borders.all(),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                record.icon,
                color: colorScheme.primary,
                size: theme.appTokens.listIconSize,
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                record.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                record.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _defaultIcon(AppReportActionKind kind) {
  return switch (kind) {
    AppReportActionKind.print => AppActionIcons.print,
    AppReportActionKind.export => Icons.ios_share_outlined,
    AppReportActionKind.download => AppActionIcons.download,
    AppReportActionKind.copy => AppActionIcons.copy,
    AppReportActionKind.preview => AppActionIcons.visibility,
  };
}

int _columnCount(
  double width,
  int itemCount,
  int maxColumns,
  double minTileWidth,
) {
  if (itemCount <= 0) {
    return 1;
  }

  final int fitColumns = (width / minTileWidth).floor().clamp(1, maxColumns);
  return fitColumns.clamp(1, itemCount);
}
