import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_loading_indicator.dart';

/// File selection surface for upload flows.
///
/// Empty: a dashed target with a browse action (the whole card is tappable).
/// Selected: a file summary with replace and remove actions.
class AppFilePickerCard extends StatelessWidget {
  const AppFilePickerCard({
    required this.title,
    required this.description,
    required this.browseLabel,
    required this.onBrowse,
    this.fileName,
    this.fileDetails,
    this.replaceLabel,
    this.removeLabel,
    this.onRemove,
    this.busyLabel,
    this.isBusy = false,
    this.enabled = true,
    this.errorText,
    this.icon = Icons.upload_file_rounded,
    this.fileIcon = Icons.table_view_rounded,
    super.key,
  });

  /// Empty-state headline, e.g. "Choose an Excel file".
  final String title;

  /// Empty-state supporting copy, e.g. accepted format.
  final String description;
  final String browseLabel;
  final VoidCallback onBrowse;

  /// Selected file name; null shows the empty state.
  final String? fileName;

  /// Secondary line under the file name (size, status).
  final String? fileDetails;
  final String? replaceLabel;
  final String? removeLabel;
  final VoidCallback? onRemove;

  /// Shown while [isBusy] (e.g. reading the file).
  final String? busyLabel;
  final bool isBusy;
  final bool enabled;
  final String? errorText;
  final IconData icon;
  final IconData fileIcon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppStatusColors statusColors = theme.statusColors;
    final BorderRadius radius = BorderRadius.circular(
      context.responsiveRadius(theme.radius.lg),
    );
    final bool hasFile = fileName != null;
    final bool interactive = enabled && !isBusy;
    final bool hasError = errorText != null;

    final Color borderColor = hasError
        ? theme.borders.error
        : hasFile
        ? statusColors.success.withValues(alpha: 0.55)
        : colorScheme.primary.withValues(alpha: 0.45);
    final Color background = hasFile
        ? statusColors.success.withValues(alpha: 0.06)
        : colorScheme.primary.withValues(alpha: 0.04);

    final Widget body = isBusy
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
            child: AppLoadingIndicator.compact(title: busyLabel, expand: false),
          )
        : hasFile
        ? _SelectedFile(
            fileName: fileName!,
            fileDetails: fileDetails,
            fileIcon: fileIcon,
            replaceLabel: replaceLabel,
            removeLabel: removeLabel,
            onReplace: interactive ? onBrowse : null,
            onRemove: interactive ? onRemove : null,
          )
        : _EmptyTarget(
            title: title,
            description: description,
            browseLabel: browseLabel,
            icon: icon,
            onBrowse: interactive ? onBrowse : null,
          );

    final Widget card = CustomPaint(
      foregroundPainter: hasFile
          ? null
          : _DashedBorderPainter(color: borderColor, borderRadius: radius),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: hasFile
              ? BorderSide(color: borderColor, width: theme.borders.thin)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: !hasFile && interactive ? onBrowse : null,
          child: Padding(
            padding: EdgeInsets.all(
              hasFile ? theme.spacing.md : theme.spacing.xl,
            ),
            child: body,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(button: !hasFile, label: hasFile ? fileName : title, child: card),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: statusColors.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyTarget extends StatelessWidget {
  const _EmptyTarget({
    required this.title,
    required this.description,
    required this.browseLabel,
    required this.icon,
    required this.onBrowse,
  });

  final String title;
  final String description;
  final String browseLabel;
  final IconData icon;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: colorScheme.primary),
        ),
        SizedBox(height: theme.spacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: AppFontWeight.semiBold,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          description,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.md),
        AppButton.primary(
          label: browseLabel,
          leadingIcon: Icons.folder_open_rounded,
          enabled: onBrowse != null,
          onPressed: onBrowse,
        ),
      ],
    );
  }
}

class _SelectedFile extends StatelessWidget {
  const _SelectedFile({
    required this.fileName,
    required this.fileDetails,
    required this.fileIcon,
    required this.replaceLabel,
    required this.removeLabel,
    required this.onReplace,
    required this.onRemove,
  });

  final String fileName;
  final String? fileDetails;
  final IconData fileIcon;
  final String? replaceLabel;
  final String? removeLabel;
  final VoidCallback? onReplace;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppStatusColors statusColors = theme.statusColors;

    final Widget summary = Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColors.success.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(theme.radius.md),
          ),
          child: Icon(fileIcon, color: statusColors.success),
        ),
        SizedBox(width: theme.spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeight.semiBold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (fileDetails != null)
                Text(
                  fileDetails!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final List<Widget> actions = <Widget>[
      if (replaceLabel != null)
        AppButton.tertiary(
          label: replaceLabel!,
          leadingIcon: Icons.swap_horiz_rounded,
          dense: true,
          enabled: onReplace != null,
          onPressed: onReplace,
        ),
      if (removeLabel != null && onRemove != null)
        AppButton.tertiary(
          label: removeLabel!,
          leadingIcon: Icons.close_rounded,
          iconOnly: true,
          tooltip: removeLabel,
          semanticLabel: removeLabel,
          dense: true,
          onPressed: onRemove,
        ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              summary,
              if (actions.isNotEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: theme.spacing.xs,
                  children: actions,
                ),
              ],
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: summary),
            SizedBox(width: theme.spacing.sm),
            ...actions,
          ],
        );
      },
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
  });

  static const double _strokeWidth = 1.5;
  static const double _dashLength = 8;
  static const double _gapLength = 6;

  final Color color;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;
    final Path outline = Path()
      ..addRRect(
        borderRadius
            .toRRect(Offset.zero & size)
            .deflate(_strokeWidth / 2),
      );
    for (final ui.PathMetric metric in outline.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = math.min(distance + _dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius;
  }
}
