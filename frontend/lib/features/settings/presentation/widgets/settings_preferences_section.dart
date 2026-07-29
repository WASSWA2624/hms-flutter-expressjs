import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_mode_controller.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Preferences tab (`/settings?tab=preferences`).
///
/// See [SettingsPreferencesAtomPermissions] for the inventory → matrix map.
class SettingsPreferencesSection extends ConsumerWidget {
  const SettingsPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final ThemeMode themeMode = ref.watch(appThemeModeProvider);
    final bool canUpdate =
        SettingsPreferencesAtomPermissions.update.isAllowed(accessPolicy);

    return AppAccessGate(
      requirement: SettingsPreferencesAtomPermissions.tab,
      child: AppScreenSection(
        title: l10n.settingsPreferencesSectionTitle,
        body: l10n.settingsPreferencesSectionBody,
        child: canUpdate
            ? _PreferencesUpdateControls(themeMode: themeMode)
            : _PreferencesReadOnlySummary(themeMode: themeMode),
      ),
    );
  }
}

class _PreferencesUpdateControls extends ConsumerWidget {
  const _PreferencesUpdateControls({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return AppAccessActionGate(
      requirement: SettingsPreferencesAtomPermissions.themeMode,
      builder: (BuildContext context, bool _) {
        return AppRadioGroup<ThemeMode>(
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
            if (mode == null) return;
            unawaited(_setThemeMode(context, ref, mode));
          },
        );
      },
    );
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.settingsSaveErrorMessage)),
          );
      }
    }
  }
}

/// Read-only preference values — not interactive controls (no disabled stubs).
class _PreferencesReadOnlySummary extends StatelessWidget {
  const _PreferencesReadOnlySummary({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final (String label, String description) = _themeModeCopy(l10n, themeMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.settingsThemeModeFieldLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              _themeModeIcon(themeMode),
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.xs / 2),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  (String, String) _themeModeCopy(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => (
        l10n.settingsThemeModeSystem,
        l10n.settingsThemeModeSystemDescription,
      ),
      ThemeMode.light => (
        l10n.settingsThemeModeLight,
        l10n.settingsThemeModeLightDescription,
      ),
      ThemeMode.dark => (
        l10n.settingsThemeModeDark,
        l10n.settingsThemeModeDarkDescription,
      ),
    };
  }

  IconData _themeModeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto_outlined,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
    };
  }
}
