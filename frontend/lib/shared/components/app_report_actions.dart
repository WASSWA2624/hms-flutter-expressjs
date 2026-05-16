import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

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
    super.key,
  });

  final Widget child;
  final String? title;
  final String? semanticLabel;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title != null && title!.isNotEmpty) ...<Widget>[
          Text(title!, style: theme.textTheme.titleSmall),
          SizedBox(height: theme.spacing.sm),
        ],
        child,
      ],
    );

    if (selectable) {
      content = SelectionArea(child: content);
    }

    return Semantics(
      container: true,
      label: semanticLabel ?? title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: content,
        ),
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
          border: Border.all(color: colorScheme.outlineVariant),
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
                  fontWeight: FontWeight.w800,
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
    AppReportActionKind.print => Icons.print_outlined,
    AppReportActionKind.export => Icons.ios_share_outlined,
    AppReportActionKind.download => Icons.file_download_outlined,
    AppReportActionKind.copy => Icons.copy_outlined,
    AppReportActionKind.preview => Icons.visibility_outlined,
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
