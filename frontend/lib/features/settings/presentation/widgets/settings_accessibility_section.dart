import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_controller.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_preferences.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/profile/presentation/profile_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Accessibility preferences tab (`/settings?tab=accessibility`).
///
/// Inventory → matrix mapping (reuse [profileReadRequirement] /
/// [profileUpdateRequirement]; create/delete `facility:admin` and nested
/// cross-module rows have no atoms on this surface):
///
/// | Atom | Intent | Gate |
/// | --- | --- | --- |
/// | Section chrome / tab strip entry | read | `profile:read` ∩ |
/// | Reduce motion value display | read | `profile:read` ∩ |
/// | Bold text value display | read | `profile:read` ∩ |
/// | Text size value display | read | `profile:read` ∩ |
/// | Reduce motion checkbox | update | `profile:update` ∩ |
/// | Bold text checkbox | update | `profile:update` ∩ |
/// | Text size select | update | `profile:update` ∩ |
/// | Save-error snackbar | visible feedback | authorized update path |
class SettingsAccessibilitySection extends ConsumerWidget {
  const SettingsAccessibilitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final AppAccessibilityPreferences accessibility = ref.watch(
      appAccessibilityProvider,
    );
    final bool canUpdate = profileUpdateRequirement.isAllowed(accessPolicy);

    return AppAccessGate(
      requirement: profileReadRequirement,
      child: AppScreenSection(
        title: l10n.settingsAccessibilitySectionTitle,
        body: l10n.settingsAccessibilitySectionBody,
        child: canUpdate
            ? _AccessibilityUpdateControls(accessibility: accessibility)
            : _AccessibilityReadOnlySummary(accessibility: accessibility),
      ),
    );
  }
}

class _AccessibilityUpdateControls extends ConsumerWidget {
  const _AccessibilityUpdateControls({required this.accessibility});

  final AppAccessibilityPreferences accessibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        AppAccessActionGate(
          requirement: profileUpdateRequirement,
          builder: (BuildContext context, bool _) {
            return AppCheckboxField(
              title: l10n.settingsReduceMotionLabel,
              subtitle: l10n.settingsReduceMotionDescription,
              value: accessibility.reduceMotion,
              onChanged: (bool value) {
                unawaited(_setReduceMotion(context, ref, value));
              },
            );
          },
        ),
        SizedBox(height: theme.spacing.md),
        AppAccessActionGate(
          requirement: profileUpdateRequirement,
          builder: (BuildContext context, bool _) {
            return AppCheckboxField(
              title: l10n.settingsBoldTextLabel,
              subtitle: l10n.settingsBoldTextDescription,
              value: accessibility.boldText,
              onChanged: (bool value) {
                unawaited(_setBoldText(context, ref, value));
              },
            );
          },
        ),
        SizedBox(height: theme.spacing.lg),
        AppAccessActionGate(
          requirement: profileUpdateRequirement,
          builder: (BuildContext context, bool _) {
            return AppSelectField<AppTextScaleLevel>(
              labelText: l10n.settingsTextScaleFieldLabel,
              value: accessibility.textScaleLevel,
              options: <AppSelectOption<AppTextScaleLevel>>[
                AppSelectOption<AppTextScaleLevel>(
                  value: AppTextScaleLevel.normal,
                  label: l10n.settingsTextScaleNormal,
                ),
                AppSelectOption<AppTextScaleLevel>(
                  value: AppTextScaleLevel.large,
                  label: l10n.settingsTextScaleLarge,
                ),
                AppSelectOption<AppTextScaleLevel>(
                  value: AppTextScaleLevel.extraLarge,
                  label: l10n.settingsTextScaleExtraLarge,
                ),
              ],
              onChanged: (AppTextScaleLevel? level) {
                if (level == null) return;
                unawaited(_setTextScaleLevel(context, ref, level));
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _setReduceMotion(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref.read(appAccessibilityProvider.notifier).setReduceMotion(value);
    } catch (_) {
      if (context.mounted) {
        _showSaveError(context);
      }
    }
  }

  Future<void> _setBoldText(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref.read(appAccessibilityProvider.notifier).setBoldText(value);
    } catch (_) {
      if (context.mounted) {
        _showSaveError(context);
      }
    }
  }

  Future<void> _setTextScaleLevel(
    BuildContext context,
    WidgetRef ref,
    AppTextScaleLevel level,
  ) async {
    try {
      await ref
          .read(appAccessibilityProvider.notifier)
          .setTextScaleLevel(level);
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

/// Read-only preference values — not interactive controls (no disabled stubs).
class _AccessibilityReadOnlySummary extends StatelessWidget {
  const _AccessibilityReadOnlySummary({required this.accessibility});

  final AppAccessibilityPreferences accessibility;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PreferenceValueRow(
          label: l10n.settingsReduceMotionLabel,
          value: accessibility.reduceMotion
              ? l10n.commonYesLabel
              : l10n.commonNoLabel,
          description: l10n.settingsReduceMotionDescription,
        ),
        SizedBox(height: theme.spacing.md),
        _PreferenceValueRow(
          label: l10n.settingsBoldTextLabel,
          value: accessibility.boldText
              ? l10n.commonYesLabel
              : l10n.commonNoLabel,
          description: l10n.settingsBoldTextDescription,
        ),
        SizedBox(height: theme.spacing.md),
        _PreferenceValueRow(
          label: l10n.settingsTextScaleFieldLabel,
          value: _textScaleLabel(l10n, accessibility.textScaleLevel),
        ),
      ],
    );
  }

  String _textScaleLabel(AppLocalizations l10n, AppTextScaleLevel level) {
    return switch (level) {
      AppTextScaleLevel.normal => l10n.settingsTextScaleNormal,
      AppTextScaleLevel.large => l10n.settingsTextScaleLarge,
      AppTextScaleLevel.extraLarge => l10n.settingsTextScaleExtraLarge,
    };
  }
}

class _PreferenceValueRow extends StatelessWidget {
  const _PreferenceValueRow({
    required this.label,
    required this.value,
    this.description,
  });

  final String label;
  final String value;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (description != null) ...<Widget>[
          SizedBox(height: theme.spacing.xs / 2),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
