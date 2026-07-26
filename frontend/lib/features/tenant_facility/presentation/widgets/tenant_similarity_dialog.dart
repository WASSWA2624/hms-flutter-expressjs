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
    : this._(action: TenantSimilarityAction.useExisting, selectedTenant: tenant);

  final TenantSimilarityAction action;
  final TenantProfile? selectedTenant;
}

Future<TenantSimilarityDialogResult> showTenantSimilarityDialog(
  BuildContext context, {
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
  final bool canProceed = allowProceed && !hasExactSlugConflict;
  final TenantSimilarityMatch? topMatch = visibleMatches.isEmpty
      ? null
      : visibleMatches.first;

  return showAppDialog<TenantSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);

      return AppDialog(
        title: Text(l10n.tenantFacilitySimilarTenantDialogTitle),
        icon: Icon(
          hasExactSlugConflict
              ? Icons.gpp_bad_outlined
              : Icons.warning_amber_outlined,
        ),
        scrollable: true,
        maxWidth: 720,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFormInformationBanner(
              title: hasExactSlugConflict
                  ? l10n.tenantFacilityTenantSlugAlreadyInUse
                  : l10n.tenantFacilitySimilarTenantWarningTitle,
              message: hasExactSlugConflict
                  ? l10n.tenantFacilitySimilarTenantHardConflictBody
                  : l10n.tenantFacilitySimilarTenantDialogBody,
              variant: hasExactSlugConflict
                  ? AppFormInformationVariant.error
                  : AppFormInformationVariant.warning,
              icon: hasExactSlugConflict
                  ? Icons.gpp_bad_outlined
                  : Icons.manage_search_outlined,
            ),
            if (topMatch != null) ...<Widget>[
              SizedBox(height: theme.spacing.md),
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
              label: l10n.tenantFacilityProceedCreateTenantAction,
              leadingIcon: Icons.add_business_outlined,
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

class TenantSimilarityWarningPanel extends StatelessWidget {
  const TenantSimilarityWarningPanel({required this.matches, super.key});

  final List<TenantSimilarityMatch> matches;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormInformationBanner(
      title: l10n.tenantFacilitySimilarTenantWarningTitle,
      message: l10n.tenantFacilitySimilarTenantWarningBody,
      variant: AppFormInformationVariant.warning,
      icon: Icons.content_copy_outlined,
      children: <Widget>[
        for (final TenantSimilarityMatch match in matches.take(3))
          _TenantSimilarityLine(match: match),
      ],
    );
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
          child: Text(
            _valuePair(l10n),
            style: theme.textTheme.bodySmall,
          ),
        ),
        Text(
          _statusLabel(l10n, comparison.status),
          style: theme.textTheme.labelSmall?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _valuePair(AppLocalizations l10n) {
    final String input = comparison.inputValue?.trim().isNotEmpty == true
        ? comparison.inputValue!
        : l10n.clinicalOrderEmptyValueLabel;
    final String candidate = comparison.candidateValue?.trim().isNotEmpty == true
        ? comparison.candidateValue!
        : l10n.clinicalOrderEmptyValueLabel;
    return '$input → $candidate';
  }
}

class _TenantSimilarityLine extends StatelessWidget {
  const _TenantSimilarityLine({required this.match});

  final TenantSimilarityMatch match;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.tenantFacilitySimilarTenantScoreLabel(match.score)),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(_lineText(l10n), style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _lineText(AppLocalizations l10n) {
    final List<String> parts = <String>[
      match.tenant.name,
      if (match.tenant.slug != null && match.tenant.slug!.isNotEmpty)
        match.tenant.slug!,
      match.tenant.isActive ? l10n.commonYesLabel : l10n.commonNoLabel,
      match.reasons.map(AppDisplay.apiLabel).join(', '),
    ];

    return parts.where((String part) => part.trim().isNotEmpty).join(' • ');
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
