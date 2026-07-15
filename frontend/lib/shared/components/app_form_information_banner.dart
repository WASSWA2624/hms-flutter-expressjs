import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Inline [AppFormInformationBanner] for [AppFormShell.formStatus].
Widget? appFormFailureStatus(
  BuildContext context,
  AppFailure? failure, {
  String? title,
  String? message,
  String? Function(AppFailure failure)? messageBuilder,
  VoidCallback? onRetry,
}) {
  if (failure == null) {
    return null;
  }

  return AppFormInformationBanner.failure(
    context: context,
    failure: failure,
    title: title,
    message: message ?? messageBuilder?.call(failure),
    onRetry: onRetry,
  );
}

/// Stacks multiple [AppFormShell.formStatus] sections into one widget.
Widget? appFormCombinedStatus(Iterable<Widget?> sections) {
  final List<Widget> children = sections.whereType<Widget>().toList();
  if (children.isEmpty) {
    return null;
  }
  if (children.length == 1) {
    return children.first;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}

/// Guidance message with optional submit/API failure below it.
Widget appFormGuidanceAndFailureStatus(
  BuildContext context, {
  required String guidanceMessage,
  AppFailure? failure,
}) {
  return appFormCombinedStatus(<Widget?>[
        AppFormInformationBanner.message(message: guidanceMessage),
        appFormFailureStatus(context, failure),
      ]) ??
      AppFormInformationBanner.message(message: guidanceMessage);
}

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
    String? title,
    String? message,
    VoidCallback? onRetry,
    List<Widget> children = const <Widget>[],
  }) {
    final AppLocalizations l10n = context.l10n;
    final List<Widget> bannerChildren = List<Widget>.from(children);
    if (failure.isRetryable && onRetry != null) {
      bannerChildren.add(
        AppButton(
          label: l10n.commonRetryActionLabel,
          leadingIcon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onRetry,
        ),
      );
    }

    return AppFormInformationBanner(
      title: title ?? l10n.failureTitle(failure),
      message: message ?? failure.displayMessage(l10n),
      variant: _variantForFailure(failure),
      children: bannerChildren,
    );
  }

  factory AppFormInformationBanner.message({
    required String message,
    String title = '',
    AppFormInformationVariant variant = AppFormInformationVariant.info,
    IconData? icon,
    List<Widget> children = const <Widget>[],
  }) {
    return AppFormInformationBanner(
      title: title,
      message: message,
      variant: variant,
      icon: icon,
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
                  if (title.trim().isNotEmpty)
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.title,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (message.trim().isNotEmpty) ...<Widget>[
                    if (title.trim().isNotEmpty)
                      SizedBox(height: theme.spacing.xs),
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
      AppFailureCategory.conflict => AppFormInformationVariant.warning,
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
