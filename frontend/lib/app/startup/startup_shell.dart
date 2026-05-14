import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

typedef _StartupContentBuilder =
    Widget Function(BuildContext context, AppLocalizations l10n);

class StartupLoadingApp extends StatelessWidget {
  const StartupLoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _StartupShell(
      builder: (BuildContext context, AppLocalizations l10n) {
        return AppStateScaffold(
          variant: AppStateViewVariant.loading,
          title: l10n.startupLoadingTitle,
          body: l10n.startupLoadingBody,
        );
      },
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StartupShell(
      builder: (BuildContext context, AppLocalizations l10n) {
        return AppStateScaffold(
          variant: AppStateViewVariant.error,
          title: l10n.startupErrorTitle,
          body: l10n.startupErrorBody,
          action: AppButton.primary(
            label: l10n.commonRetryActionLabel,
            onPressed: onRetry,
          ),
        );
      },
    );
  }
}

class _StartupShell extends StatelessWidget {
  const _StartupShell({required this.builder});

  final _StartupContentBuilder builder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) {
            return builder(context, context.l10n);
          },
        );
      },
    );
  }
}
