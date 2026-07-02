import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum AppFormInformationVariant { error, warning, success, info }

/// Inline form feedback with icon-left layout and color-coded variants.
class AppFormInformationBanner extends StatelessWidget {
  const AppFormInformationBanner({
    required this.title,
    required this.message,
    this.variant = AppFormInformationVariant.info,
    this.icon,
    this.children = const <Widget>[],
    super.key,
  });

  factory AppFormInformationBanner.failure({
    required BuildContext context,
    required AppFailure failure,
    List<Widget> children = const <Widget>[],
  }) {
    final AppLocalizations l10n = context.l10n;
    return AppFormInformationBanner(
      title: l10n.failureTitle(failure),
      message: failure.displayMessage(l10n),
      variant: _variantForFailure(failure),
      children: children,
    );
  }

  final String title;
  final String message;
  final AppFormInformationVariant variant;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppWorkspaceStatusTone tone = _tone(variant);
    final _FormBannerColors colors = _colors(theme, variant);

    return Semantics(
      container: true,
      liveRegion: variant == AppFormInformationVariant.error,
      label: title,
      child: AppContentPanel(
        tone: tone,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon ?? _defaultIcon(variant),
              color: colors.accent,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.title,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (message.trim().isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    ..._messageLines(message, colors.message, theme),
                  ],
                  for (final Widget child in children) ...<Widget>[
                    SizedBox(height: theme.spacing.sm),
                    child,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static AppFormInformationVariant _variantForFailure(AppFailure failure) {
    return switch (failure.category) {
      AppFailureCategory.validation => AppFormInformationVariant.error,
      AppFailureCategory.forbidden ||
      AppFailureCategory.unauthorized => AppFormInformationVariant.error,
      AppFailureCategory.offline => AppFormInformationVariant.info,
      _ => AppFormInformationVariant.error,
    };
  }

  static AppWorkspaceStatusTone _tone(AppFormInformationVariant variant) {
    return switch (variant) {
      AppFormInformationVariant.error => AppWorkspaceStatusTone.error,
      AppFormInformationVariant.warning => AppWorkspaceStatusTone.warning,
      AppFormInformationVariant.success => AppWorkspaceStatusTone.success,
      AppFormInformationVariant.info => AppWorkspaceStatusTone.info,
    };
  }

  static IconData _defaultIcon(AppFormInformationVariant variant) {
    return switch (variant) {
      AppFormInformationVariant.error => Icons.error_outline,
      AppFormInformationVariant.warning => Icons.warning_amber_outlined,
      AppFormInformationVariant.success => Icons.check_circle_outline,
      AppFormInformationVariant.info => Icons.info_outline,
    };
  }

  static List<Widget> _messageLines(
    String message,
    Color color,
    ThemeData theme,
  ) {
    final TextStyle? style = theme.textTheme.bodyMedium?.copyWith(color: color);
    return message
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .map((String line) => Text(line, style: style))
        .toList(growable: false);
  }

  static _FormBannerColors _colors(
    ThemeData theme,
    AppFormInformationVariant variant,
  ) {
    final AppStatusColors statusColors = theme.statusColors;

    return switch (variant) {
      AppFormInformationVariant.error => _FormBannerColors(
        title: statusColors.onErrorContainer,
        message: statusColors.error,
        accent: statusColors.error,
      ),
      AppFormInformationVariant.warning => _FormBannerColors(
        title: statusColors.onWarningContainer,
        message: statusColors.warning,
        accent: statusColors.warning,
      ),
      AppFormInformationVariant.success => _FormBannerColors(
        title: statusColors.onSuccessContainer,
        message: statusColors.success,
        accent: statusColors.success,
      ),
      AppFormInformationVariant.info => _FormBannerColors(
        title: statusColors.onInfoContainer,
        message: statusColors.info,
        accent: statusColors.info,
      ),
    };
  }
}

@immutable
final class _FormBannerColors {
  const _FormBannerColors({
    required this.title,
    required this.message,
    required this.accent,
  });

  final Color title;
  final Color message;
  final Color accent;
}
