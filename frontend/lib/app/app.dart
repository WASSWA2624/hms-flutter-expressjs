import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/app/locale/app_locale_controller.dart';
import 'package:flutter_template/app/router/app_router.dart';
import 'package:flutter_template/app/theme/app_theme.dart';
import 'package:flutter_template/app/theme/app_theme_mode_controller.dart';
import 'package:flutter_template/l10n/app_localizations.dart';
import 'package:flutter_template/l10n/app_localizations_x.dart';
import 'package:go_router/go_router.dart';

class TemplateApp extends ConsumerWidget {
  const TemplateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}
