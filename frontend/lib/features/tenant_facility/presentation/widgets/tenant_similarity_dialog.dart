import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

enum TenantSimilarityAction { cancel, useExisting, proceed }

final class TenantSimilarityProposedValues {
  const TenantSimilarityProposedValues({
    required this.name,
    this.slug,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.currency,
    this.standardConsultationFee,
  });

  final String name;
  final String? slug;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? currency;
  final String? standardConsultationFee;
}

final class TenantSimilarityDialogResult {
  const TenantSimilarityDialogResult._({
    required this.action,
    this.selectedTenant,
  });

  const TenantSimilarityDialogResult.cancel()
    : this._(action: TenantSimilarityAction.cancel);

  const TenantSimilarityDialogResult.proceed()
    : this._(action: TenantSimilarityAction.proceed);

  const TenantSimilarityDialogResult.useExisting(TenantProfile tenant)
    : this._(
        action: TenantSimilarityAction.useExisting,
        selectedTenant: tenant,
      );

  final TenantSimilarityAction action;
  final TenantProfile? selectedTenant;
}

Future<TenantSimilarityDialogResult> showTenantSimilarityDialog(
  BuildContext context, {
  required TenantSimilarityProposedValues proposed,
  required List<TenantSimilarityMatch> matches,
  bool allowProceed = true,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<TenantSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactSlugConflict = visibleMatches.any(
    (TenantSimilarityMatch match) => match.exactSlugConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactSlugConflict;
  final TenantSimilarityMatch? topMatch = visibleMatches.isEmpty
      ? null
      : visibleMatches.first;

  final String dialogTitle = hasExactSlugConflict
      ? l10n.tenantFacilitySimilarTenantDialogTitle
      : hasMatches
      ? l10n.tenantFacilitySimilarTenantDialogTitle
      : l10n.tenantFacilityNoSimilarTenantDialogTitle;

  final String proceedLabel = hasExactSlugConflict
      ? l10n.tenantFacilityProceedCreateTenantAction
      : hasMatches
      ? l10n.tenantFacilityProceedCreateTenantAction
      : l10n.tenantFacilityContinueCreateTenantAction;

  return showAppDialog<TenantSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final AppFormInformationVariant bannerVariant = hasExactSlugConflict
          ? AppFormInformationVariant.error
          : hasMatches
          ? AppFormInformationVariant.warning
          : AppFormInformationVariant.success;
      final String bannerTitle = hasExactSlugConflict
          ? l10n.tenantFacilityTenantSlugAlreadyInUse
          : hasMatches
          ? l10n.tenantFacilitySimilarTenantWarningTitle
          : l10n.tenantFacilityNoSimilarTenantBannerTitle;
      final String bannerMessage = hasExactSlugConflict
          ? l10n.tenantFacilitySimilarTenantHardConflictBody
          : hasMatches
          ? l10n.tenantFacilitySimilarTenantDialogBody
          : l10n.tenantFacilityNoSimilarTenantDialogBody;
      final String? closestScore = topMatch == null
          ? null
          : l10n.tenantFacilitySimilarTenantScoreLabel(topMatch.score);

      return AppDialog(
        title: Text(dialogTitle),
        icon: Icon(
          hasExactSlugConflict
              ? Icons.gpp_bad_outlined
              : hasMatches
              ? Icons.warning_amber_outlined
              : Icons.verified_outlined,
        ),
        scrollable: true,
        maxWidth: 760,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFormInformationBanner(
              title: bannerTitle,
              message: closestScore == null
                  ? bannerMessage
                  : '$bannerMessage ${l10n.tenantFacilitySimilarTenantClosestScoreBody(topMatch!.score)}',
              variant: bannerVariant,
              icon: hasExactSlugConflict
                  ? Icons.gpp_bad_outlined
                  : hasMatches
                  ? Icons.manage_search_outlined
                  : Icons.verified_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedTenantCard(proposed: proposed),
            if (hasMatches) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              Text(
                l10n.tenantFacilitySimilarTenantMatchesHeading,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              for (int index = 0; index < visibleMatches.length; index += 1) ...<
                Widget
              >[
                if (index > 0) SizedBox(height: theme.spacing.md),
                _TenantSimilarityMatchCard(
                  match: visibleMatches[index],
                  onUseExisting: () => Navigator.of(dialogContext).pop(
                    TenantSimilarityDialogResult.useExisting(
                      visibleMatches[index].tenant,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(
              const TenantSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: proceedLabel,
              leadingIcon: hasMatches
                  ? Icons.add_business_outlined
                  : Icons.check_circle_outline,
              onPressed: () => Navigator.of(dialogContext).pop(
                const TenantSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (TenantSimilarityDialogResult? value) =>
        value ?? const TenantSimilarityDialogResult.cancel(),
  );
}

class _ProposedTenantCard extends StatelessWidget {
  const _ProposedTenantCard({required this.proposed});

  final TenantSimilarityProposedValues proposed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<(String, String)> facts = <(String, String)>[
      (l10n.tenantFacilityTenantNameLabel, _display(proposed.name, l10n)),
      (
        l10n.tenantFacilityTenantSlugLabel,
        _display(proposed.slug, l10n),
      ),
      (
        l10n.tenantFacilityTenantDetailsContactNameLabel,
        _display(proposed.contactName, l10n),
      ),
      (l10n.profilePhoneLabel, _display(proposed.contactPhone, l10n)),
      (l10n.profileEmailLabel, _display(proposed.contactEmail, l10n)),
      (
        l10n.tenantFacilityDefaultCurrencyLabel,
        _display(proposed.currency, l10n),
      ),
      (
        l10n.settingsConfigurationConsultationFeeLabel,
        _display(proposed.standardConsultationFee, l10n),
      ),
    ];

    return AppSectionPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.edit_note_outlined,
      title: l10n.tenantFacilitySimilarTenantProposedHeading,
      children: <Widget>[
        Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            for (final (String label, String value) in facts)
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _display(String? value, AppLocalizations l10n) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? l10n.clinicalOrderEmptyValueLabel : trimmed;
  }
}

class _TenantSimilarityMatchCard extends StatelessWidget {
  const _TenantSimilarityMatchCard({
    required this.match,
    required this.onUseExisting,
  });

  final TenantSimilarityMatch match;
  final VoidCallback onUseExisting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppSectionPanel(
      tone: match.exactSlugConflict
          ? AppWorkspaceStatusTone.error
          : AppWorkspaceStatusTone.warning,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.apartment_outlined,
      title: match.tenant.name,
      trailing: Text(
        l10n.tenantFacilitySimilarTenantScoreLabel(match.score),
        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      children: <Widget>[
        if (match.tenant.slug != null && match.tenant.slug!.isNotEmpty)
          Text(
            match.tenant.slug!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        SizedBox(height: theme.spacing.sm),
        for (final TenantFieldComparison comparison in match.fieldComparisons)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.xs),
            child: _TenantFieldComparisonRow(comparison: comparison),
          ),
        SizedBox(height: theme.spacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.secondary(
            label: l10n.tenantFacilityUseExistingTenantAction,
            leadingIcon: Icons.open_in_new,
            onPressed: onUseExisting,
          ),
        ),
      ],
    );
  }
}

class _TenantFieldComparisonRow extends StatelessWidget {
  const _TenantFieldComparisonRow({required this.comparison});

  final TenantFieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Color statusColor = switch (comparison.status) {
      TenantFieldComparisonStatus.match => theme.colorScheme.primary,
      TenantFieldComparisonStatus.similar => theme.colorScheme.tertiary,
      TenantFieldComparisonStatus.different => theme.colorScheme.error,
      TenantFieldComparisonStatus.missing => theme.colorScheme.onSurfaceVariant,
    };
    final String scoreLabel = comparison.score == null
        ? l10n.clinicalOrderEmptyValueLabel
        : l10n.tenantFacilitySimilarTenantScoreLabel(comparison.score!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(
            _fieldLabel(l10n, comparison.field),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(_valuePair(l10n), style: theme.textTheme.bodySmall),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              _statusLabel(l10n, comparison.status),
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              scoreLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _valuePair(AppLocalizations l10n) {
    final String input = comparison.inputValue?.trim().isNotEmpty == true
        ? comparison.inputValue!
        : l10n.clinicalOrderEmptyValueLabel;
    final String candidate =
        comparison.candidateValue?.trim().isNotEmpty == true
        ? comparison.candidateValue!
        : l10n.clinicalOrderEmptyValueLabel;
    return '$input → $candidate';
  }
}

String _fieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'name' => l10n.tenantFacilityTenantNameLabel,
    'slug' => l10n.tenantFacilityTenantSlugLabel,
    'contact_name' => l10n.tenantFacilityTenantDetailsContactNameLabel,
    'contact_phone' => l10n.profilePhoneLabel,
    'contact_email' => l10n.profileEmailLabel,
    'currency' => l10n.tenantFacilityDefaultCurrencyLabel,
    'consultation_fee' => l10n.settingsConfigurationConsultationFeeLabel,
    _ => AppDisplay.apiLabel(field),
  };
}

String _statusLabel(
  AppLocalizations l10n,
  TenantFieldComparisonStatus status,
) {
  return switch (status) {
    TenantFieldComparisonStatus.match =>
      l10n.tenantFacilitySimilarFieldStatusMatch,
    TenantFieldComparisonStatus.similar =>
      l10n.tenantFacilitySimilarFieldStatusSimilar,
    TenantFieldComparisonStatus.different =>
      l10n.tenantFacilitySimilarFieldStatusDifferent,
    TenantFieldComparisonStatus.missing =>
      l10n.tenantFacilitySimilarFieldStatusMissing,
  };
}
