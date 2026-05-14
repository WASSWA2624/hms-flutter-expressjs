import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/locale/app_locale_controller.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_mode_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeMode themeMode = ref.watch(appThemeModeProvider);
    final Locale selectedLocale =
        ref.watch(appLocaleProvider) ?? _englishLocale;

    return AppScreen(
      title: l10n.settingsTitle,
      body: l10n.settingsBody,
      maxWidth: PageMaxWidth.dashboard,
      children: <Widget>[
        _SettingsSectionGrid(
          sections: <Widget>[
            AppScreenSection(
              title: l10n.settingsLanguageSectionTitle,
              body: l10n.settingsLanguageSectionBody,
              child: AppSelectField<Locale>(
                labelText: l10n.settingsLanguageFieldLabel,
                value: selectedLocale,
                options: <AppSelectOption<Locale>>[
                  AppSelectOption<Locale>(
                    value: _englishLocale,
                    label: l10n.settingsLanguageEnglish,
                  ),
                ],
                onChanged: (Locale? locale) {
                  if (locale == null) {
                    return;
                  }

                  unawaited(_setLocale(context, ref, locale));
                },
              ),
            ),
            AppScreenSection(
              title: l10n.settingsThemeSectionTitle,
              body: l10n.settingsThemeSectionBody,
              child: AppRadioGroup<ThemeMode>(
                labelText: l10n.settingsThemeModeFieldLabel,
                value: themeMode,
                options: <AppRadioOption<ThemeMode>>[
                  AppRadioOption<ThemeMode>(
                    value: ThemeMode.system,
                    label: l10n.settingsThemeModeSystem,
                    description: l10n.settingsThemeModeSystemDescription,
                    secondary: const Icon(Icons.brightness_auto_outlined),
                  ),
                  AppRadioOption<ThemeMode>(
                    value: ThemeMode.light,
                    label: l10n.settingsThemeModeLight,
                    description: l10n.settingsThemeModeLightDescription,
                    secondary: const Icon(Icons.light_mode_outlined),
                  ),
                  AppRadioOption<ThemeMode>(
                    value: ThemeMode.dark,
                    label: l10n.settingsThemeModeDark,
                    description: l10n.settingsThemeModeDarkDescription,
                    secondary: const Icon(Icons.dark_mode_outlined),
                  ),
                ],
                onChanged: (ThemeMode? mode) {
                  if (mode == null) {
                    return;
                  }

                  unawaited(_setThemeMode(context, ref, mode));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _setLocale(
    BuildContext context,
    WidgetRef ref,
    Locale locale,
  ) async {
    try {
      await ref.read(appLocaleProvider.notifier).setLocale(locale);
    } catch (_) {
      if (context.mounted) {
        _showSaveError(context);
      }
    }
  }

  Future<void> _setThemeMode(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
  ) async {
    try {
      await ref.read(appThemeModeProvider.notifier).setThemeMode(themeMode);
    } catch (_) {
      if (context.mounted) {
        _showSaveError(context);
      }
    }
  }

  void _showSaveError(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.settingsSaveErrorMessage)),
      );
  }
}

class _SettingsSectionGrid extends StatelessWidget {
  const _SettingsSectionGrid({required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useTwoColumns = constraints.maxWidth >= _twoColumnMinWidth;
        final double itemWidth = useTwoColumns
            ? (constraints.maxWidth - theme.spacing.lg) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.lg,
          children: <Widget>[
            for (final Widget section in sections)
              SizedBox(width: itemWidth, child: section),
          ],
        );
      },
    );
  }
}

const Locale _englishLocale = Locale('en');
const double _twoColumnMinWidth = 920;
