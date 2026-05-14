import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/app/theme/app_theme_extensions.dart';
import 'package:flutter_template/core/errors/app_failure.dart';
import 'package:flutter_template/core/errors/result.dart';
import 'package:flutter_template/l10n/app_localizations_x.dart';
import 'package:flutter_template/shared/components/app_button.dart';
import 'package:flutter_template/shared/layout/responsive_page.dart';

enum AppStateViewVariant { loading, empty, error, success, info }

typedef AsyncStateDataBuilder<T> =
    Widget Function(BuildContext context, T data);
typedef AsyncStateEmptyPredicate<T> = bool Function(T data);
typedef AsyncStateFailureMapper =
    AppFailure Function(Object error, StackTrace stackTrace);

class AppStateView extends StatelessWidget {
  const AppStateView({
    required this.title,
    required this.body,
    this.variant = AppStateViewVariant.info,
    this.icon,
    this.detail,
    this.action,
    this.semanticLabel,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String title;
  final String body;
  final AppStateViewVariant variant;
  final IconData? icon;
  final String? detail;
  final Widget? action;
  final String? semanticLabel;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppSpacingTokens spacing = theme.spacing;

    return Semantics(
      container: true,
      liveRegion:
          variant == AppStateViewVariant.loading ||
          variant == AppStateViewVariant.error,
      label: semanticLabel ?? title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: <Widget>[
          _StateVisual(variant: variant, icon: icon),
          SizedBox(height: spacing.sm),
          Text(title, style: textTheme.titleLarge, textAlign: textAlign),
          SizedBox(height: spacing.sm),
          Text(body, style: textTheme.bodyMedium, textAlign: textAlign),
          if (detail != null && detail!.isNotEmpty) ...<Widget>[
            SizedBox(height: spacing.sm),
            Text(detail!, style: textTheme.bodyMedium, textAlign: textAlign),
          ],
          if (action != null) ...<Widget>[
            SizedBox(height: spacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

class AppFailureStateView extends StatelessWidget {
  const AppFailureStateView({
    required this.failure,
    this.onRetry,
    this.title,
    this.body,
    this.semanticLabel,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final AppFailure failure;
  final VoidCallback? onRetry;
  final String? title;
  final String? body;
  final String? semanticLabel;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final retryAction = failure.isRetryable && onRetry != null
        ? AppButton.primary(
            label: l10n.commonRetryActionLabel,
            leadingIcon: Icons.refresh,
            onPressed: onRetry,
          )
        : null;

    return AppStateView(
      variant: AppStateViewVariant.error,
      title: title ?? l10n.failureTitle(failure),
      body: body ?? l10n.failureMessage(failure),
      action: retryAction,
      semanticLabel: semanticLabel,
      crossAxisAlignment: crossAxisAlignment,
      textAlign: textAlign,
    );
  }
}

class AppStateScaffold extends StatelessWidget {
  const AppStateScaffold({
    required this.title,
    required this.body,
    this.appBarTitle,
    this.variant = AppStateViewVariant.info,
    this.icon,
    this.detail,
    this.action,
    this.semanticLabel,
    this.maxWidth = PageMaxWidth.authForm,
    this.centerVertically = true,
    this.scrollable = true,
    this.safeArea = true,
    super.key,
  });

  final String? appBarTitle;
  final String title;
  final String body;
  final AppStateViewVariant variant;
  final IconData? icon;
  final String? detail;
  final Widget? action;
  final String? semanticLabel;
  final PageMaxWidth maxWidth;
  final bool centerVertically;
  final bool scrollable;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarTitle == null ? null : AppBar(title: Text(appBarTitle!)),
      body: ResponsivePage(
        maxWidth: maxWidth,
        centerVertically: centerVertically,
        scrollable: scrollable,
        safeArea: safeArea,
        child: AppStateView(
          variant: variant,
          icon: icon,
          title: title,
          body: body,
          detail: detail,
          action: action,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}

class AppFailureStateScaffold extends StatelessWidget {
  const AppFailureStateScaffold({
    required this.failure,
    this.appBarTitle,
    this.onRetry,
    this.title,
    this.body,
    this.semanticLabel,
    this.maxWidth = PageMaxWidth.authForm,
    this.centerVertically = true,
    this.scrollable = true,
    this.safeArea = true,
    super.key,
  });

  final AppFailure failure;
  final String? appBarTitle;
  final VoidCallback? onRetry;
  final String? title;
  final String? body;
  final String? semanticLabel;
  final PageMaxWidth maxWidth;
  final bool centerVertically;
  final bool scrollable;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarTitle == null ? null : AppBar(title: Text(appBarTitle!)),
      body: ResponsivePage(
        maxWidth: maxWidth,
        centerVertically: centerVertically,
        scrollable: scrollable,
        safeArea: safeArea,
        child: AppFailureStateView(
          failure: failure,
          title: title,
          body: body,
          onRetry: onRetry,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}

class AsyncStateScaffold<T> extends StatelessWidget {
  const AsyncStateScaffold({
    required this.value,
    required this.dataBuilder,
    required this.loadingTitle,
    required this.loadingBody,
    this.appBarTitle,
    this.onRetry,
    this.emptyPredicate,
    this.emptyTitle,
    this.emptyBody,
    this.emptySemanticLabel,
    this.emptyAction,
    this.failureMapper = _defaultFailureMapper,
    this.maxWidth = PageMaxWidth.authForm,
    this.centerVertically = true,
    this.scrollable = true,
    this.safeArea = true,
    super.key,
  }) : assert(
         emptyPredicate == null || (emptyTitle != null && emptyBody != null),
         'Provide localized emptyTitle and emptyBody with emptyPredicate.',
       );

  final AsyncValue<Result<T>> value;
  final AsyncStateDataBuilder<T> dataBuilder;
  final String? appBarTitle;
  final String loadingTitle;
  final String loadingBody;
  final VoidCallback? onRetry;
  final AsyncStateEmptyPredicate<T>? emptyPredicate;
  final String? emptyTitle;
  final String? emptyBody;
  final String? emptySemanticLabel;
  final Widget? emptyAction;
  final AsyncStateFailureMapper failureMapper;
  final PageMaxWidth maxWidth;
  final bool centerVertically;
  final bool scrollable;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (result) {
        return result.when(
          success: (data) {
            if (emptyPredicate?.call(data) ?? false) {
              return AppStateScaffold(
                appBarTitle: appBarTitle,
                variant: AppStateViewVariant.empty,
                title: emptyTitle!,
                body: emptyBody!,
                action: emptyAction,
                semanticLabel: emptySemanticLabel,
                maxWidth: maxWidth,
                centerVertically: centerVertically,
                scrollable: scrollable,
                safeArea: safeArea,
              );
            }

            return dataBuilder(context, data);
          },
          failure: (failure) => AppFailureStateScaffold(
            appBarTitle: appBarTitle,
            failure: failure,
            onRetry: onRetry,
            maxWidth: maxWidth,
            centerVertically: centerVertically,
            scrollable: scrollable,
            safeArea: safeArea,
          ),
        );
      },
      error: (error, stackTrace) {
        return AppFailureStateScaffold(
          appBarTitle: appBarTitle,
          failure: failureMapper(error, stackTrace),
          onRetry: onRetry,
          maxWidth: maxWidth,
          centerVertically: centerVertically,
          scrollable: scrollable,
          safeArea: safeArea,
        );
      },
      loading: () {
        return AppStateScaffold(
          appBarTitle: appBarTitle,
          variant: AppStateViewVariant.loading,
          title: loadingTitle,
          body: loadingBody,
          maxWidth: maxWidth,
          centerVertically: centerVertically,
          scrollable: scrollable,
          safeArea: safeArea,
        );
      },
    );
  }
}

AppFailure _defaultFailureMapper(Object error, StackTrace stackTrace) {
  if (error is AppFailure) {
    return error;
  }

  return const AppFailure.unexpected();
}

class _StateVisual extends StatelessWidget {
  const _StateVisual({required this.variant, required this.icon});

  final AppStateViewVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppDesignTokens appTokens = theme.appTokens;

    if (variant == AppStateViewVariant.loading) {
      return SizedBox.square(
        dimension: appTokens.statusIconSize,
        child: const CircularProgressIndicator(strokeWidth: 3),
      );
    }

    return Icon(
      icon ?? _defaultIcon(),
      size: appTokens.statusIconSize,
      color: _color(theme),
    );
  }

  IconData _defaultIcon() {
    return switch (variant) {
      AppStateViewVariant.loading => Icons.hourglass_empty_outlined,
      AppStateViewVariant.empty => Icons.inbox_outlined,
      AppStateViewVariant.error => Icons.error_outline,
      AppStateViewVariant.success => Icons.check_circle_outline,
      AppStateViewVariant.info => Icons.info_outline,
    };
  }

  Color _color(ThemeData theme) {
    return switch (variant) {
      AppStateViewVariant.loading => theme.colorScheme.primary,
      AppStateViewVariant.empty => theme.colorScheme.onSurfaceVariant,
      AppStateViewVariant.error => theme.statusColors.error,
      AppStateViewVariant.success => theme.statusColors.success,
      AppStateViewVariant.info => theme.statusColors.info,
    };
  }
}
