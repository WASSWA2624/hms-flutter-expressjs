import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_loading_indicator.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/layout/shell_navigation_loading.dart';

enum AppStateViewVariant {
  loading,
  empty,
  error,
  forbidden,
  offline,
  conflict,
  validation,
  success,
  info,
}

typedef AsyncStateDataBuilder<T> =
    Widget Function(BuildContext context, T data);
typedef AsyncStateEmptyPredicate<T> = bool Function(T data);
typedef AsyncStateFailureMapper =
    AppFailure Function(Object error, StackTrace stackTrace);
typedef AppRetryCallback = FutureOr<void> Function();

class AppStateView extends StatelessWidget {
  const AppStateView({
    required this.title,
    required this.body,
    this.variant = AppStateViewVariant.info,
    this.icon,
    this.detail,
    this.action,
    this.semanticLabel,
    this.crossAxisAlignment,
    this.textAlign,
    this.inlineVisualWithTitle = false,
    this.loadingSize = AppLoadingIndicatorSize.regular,
    super.key,
  });

  final String title;
  final String body;
  final AppStateViewVariant variant;
  final IconData? icon;
  final String? detail;
  final Widget? action;
  final String? semanticLabel;

  /// Defaults to centered for [AppStateViewVariant.loading] and
  /// [AppStateViewVariant.empty]; start-aligned otherwise.
  final CrossAxisAlignment? crossAxisAlignment;

  /// Defaults to centered for [AppStateViewVariant.loading] and
  /// [AppStateViewVariant.empty]; start-aligned otherwise.
  final TextAlign? textAlign;
  final bool inlineVisualWithTitle;
  final AppLoadingIndicatorSize loadingSize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppSpacingTokens spacing = theme.spacing;
    final bool isLoading = variant == AppStateViewVariant.loading;
    final bool centersByDefault =
        isLoading || variant == AppStateViewVariant.empty;
    final CrossAxisAlignment resolvedAlignment = isLoading
        ? CrossAxisAlignment.center
        : crossAxisAlignment ??
              (centersByDefault
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start);
    final TextAlign resolvedTextAlign = isLoading
        ? TextAlign.center
        : textAlign ?? (centersByDefault ? TextAlign.center : TextAlign.start);

    if (isLoading) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: semanticLabel ?? title,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppLoadingIndicator(
                size: loadingSize,
                title: title,
                body: body,
                semanticLabel: semanticLabel ?? title,
              ),
              if (detail != null && detail!.isNotEmpty) ...<Widget>[
                SizedBox(height: spacing.sm),
                Text(
                  detail!,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...<Widget>[
                SizedBox(height: spacing.md),
                action!,
              ],
            ],
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      liveRegion:
          variant == AppStateViewVariant.error ||
          variant == AppStateViewVariant.conflict,
      label: semanticLabel ?? title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: resolvedAlignment,
        children: <Widget>[
          if (inlineVisualWithTitle)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _StateVisual(variant: variant, icon: icon),
                SizedBox(width: spacing.sm),
                Flexible(
                  child: Text(
                    title,
                    style: textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          else ...<Widget>[
            _StateVisual(variant: variant, icon: icon),
            SizedBox(height: spacing.sm),
            Text(
              title,
              style: textTheme.titleLarge,
              textAlign: resolvedTextAlign,
            ),
          ],
          SizedBox(height: spacing.sm),
          Text(body, style: textTheme.bodyMedium, textAlign: resolvedTextAlign),
          if (detail != null && detail!.isNotEmpty) ...<Widget>[
            SizedBox(height: spacing.sm),
            Text(
              detail!,
              style: textTheme.bodyMedium,
              textAlign: resolvedTextAlign,
            ),
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

class AppFailureStateView extends StatefulWidget {
  const AppFailureStateView({
    required this.failure,
    this.onRetry,
    this.title,
    this.body,
    this.semanticLabel,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textAlign = TextAlign.center,
    super.key,
  });

  final AppFailure failure;
  final AppRetryCallback? onRetry;
  final String? title;
  final String? body;
  final String? semanticLabel;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  @override
  State<AppFailureStateView> createState() => _AppFailureStateViewState();
}

class _AppFailureStateViewState extends State<AppFailureStateView> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    if (_isRetrying || widget.onRetry == null) {
      return;
    }
    setState(() => _isRetrying = true);
    try {
      await widget.onRetry!();
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final retryAction = widget.failure.isRetryable && widget.onRetry != null
        ? AppButton(
            label: l10n.commonRetryActionLabel,
            leadingIcon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            isLoading: _isRetrying,
            onPressed: _retry,
          )
        : null;

    return AppStateView(
      variant: _failureVariant(widget.failure),
      title: widget.title ?? l10n.failureTitle(widget.failure),
      body: widget.body ?? widget.failure.displayMessage(l10n),
      action: retryAction,
      semanticLabel: widget.semanticLabel,
      crossAxisAlignment: widget.crossAxisAlignment,
      textAlign: widget.textAlign,
      inlineVisualWithTitle: true,
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
    if (variant == AppStateViewVariant.loading) {
      return Scaffold(
        // Route title lives in the shell menu bar; avoid a second page header.
        body: AppLoadingSurface(
          child: AppLoadingIndicator.page(
            title: title,
            body: body,
            semanticLabel: semanticLabel ?? title,
            showBrandName: false,
          ),
        ),
      );
    }

    return Scaffold(
      // Route title lives in the shell menu bar; avoid a second page header.
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
    this.scrollable = true,
    this.safeArea = true,
    super.key,
  });

  final AppFailure failure;
  final String? appBarTitle;
  final AppRetryCallback? onRetry;
  final String? title;
  final String? body;
  final String? semanticLabel;
  final bool scrollable;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Route title lives in the shell menu bar; avoid a second page header.
      body: ResponsivePage(
        maxWidth: PageMaxWidth.authForm,
        centerVertically: true,
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
    this.deferLoadingToShell,
    this.keepPreviousDataDuringRefresh = false,
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
  final AppRetryCallback? onRetry;
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

  /// When true, initial load shows the shell bar instead of a full-page spinner.
  /// Defaults to [ShellNavigationScope.deferLoadingToShellOf] when null.
  final bool? deferLoadingToShell;

  /// When true, a background refresh keeps the last successful payload visible
  /// instead of replacing the page with a loading scaffold.
  final bool keepPreviousDataDuringRefresh;

  bool _shouldDeferLoadingToShell(BuildContext context) {
    return deferLoadingToShell ??
        ShellNavigationScope.deferLoadingToShellOf(context);
  }

  Widget? _previousDataWidget(BuildContext context) {
    if (!keepPreviousDataDuringRefresh || !value.hasValue) {
      return null;
    }

    return value.requireValue.when(
      success: (T data) {
        if (emptyPredicate?.call(data) ?? false) {
          return null;
        }
        return dataBuilder(context, data);
      },
      failure: (_) => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (value.isLoading && !value.hasValue) {
      if (_shouldDeferLoadingToShell(context)) {
        return const ShellLoadingReporter(
          isLoading: true,
          child: SizedBox.shrink(),
        );
      }

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
    }

    return ShellLoadingReporter(
      isLoading: false,
      child: value.when(
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
            scrollable: scrollable,
            safeArea: safeArea,
          );
        },
        loading: () {
          final Widget? previousData = _previousDataWidget(context);
          if (previousData != null) {
            return previousData;
          }

          if (_shouldDeferLoadingToShell(context)) {
            return const SizedBox.shrink();
          }

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
      ),
    );
  }
}

AppFailure _defaultFailureMapper(Object error, StackTrace stackTrace) {
  if (error is AppFailure) {
    return error;
  }

  return const AppFailure.unexpected();
}

AppStateViewVariant _failureVariant(AppFailure failure) {
  return switch (failure.category) {
    AppFailureCategory.forbidden ||
    AppFailureCategory.unauthorized => AppStateViewVariant.forbidden,
    AppFailureCategory.offline => AppStateViewVariant.offline,
    AppFailureCategory.conflict => AppStateViewVariant.conflict,
    AppFailureCategory.validation => AppStateViewVariant.validation,
    _ => AppStateViewVariant.error,
  };
}

class _StateVisual extends StatelessWidget {
  const _StateVisual({required this.variant, required this.icon});

  final AppStateViewVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppDesignTokens appTokens = theme.appTokens;

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
      AppStateViewVariant.forbidden => Icons.lock_outline,
      AppStateViewVariant.offline => Icons.wifi_off_outlined,
      AppStateViewVariant.conflict => Icons.sync_problem_outlined,
      AppStateViewVariant.validation => Icons.fact_check_outlined,
      AppStateViewVariant.success => Icons.check_circle_outline,
      AppStateViewVariant.info => Icons.info_outline,
    };
  }

  Color _color(ThemeData theme) {
    return switch (variant) {
      AppStateViewVariant.loading => theme.colorScheme.primary,
      AppStateViewVariant.empty => theme.colorScheme.onSurfaceVariant,
      AppStateViewVariant.error => theme.statusColors.error,
      AppStateViewVariant.forbidden => theme.statusColors.warning,
      AppStateViewVariant.offline => theme.statusColors.info,
      AppStateViewVariant.conflict => theme.statusColors.warning,
      AppStateViewVariant.validation => theme.statusColors.warning,
      AppStateViewVariant.success => theme.statusColors.success,
      AppStateViewVariant.info => theme.statusColors.info,
    };
  }
}
