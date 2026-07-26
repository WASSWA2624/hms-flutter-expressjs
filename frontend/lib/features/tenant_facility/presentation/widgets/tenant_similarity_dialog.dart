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

  final String dialogTitle = hasExactSlugConflict || hasMatches
      ? l10n.tenantFacilitySimilarTenantDialogTitle
      : l10n.tenantFacilityNoSimilarTenantDialogTitle;

  final String proceedLabel = hasMatches
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
          ? l10n.tenantFacilitySimilarTenantReviewBannerBody(
              topMatch?.score ?? 0,
            )
          : l10n.tenantFacilityNoSimilarTenantDialogBody;

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
        maxWidth: 820,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFormInformationBanner(
              title: bannerTitle,
              message: bannerMessage,
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
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.tenantFacilitySimilarTenantMatchesHeading,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    l10n.tenantFacilitySimilarTenantMatchCountLabel(
                      visibleMatches.length,
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
      (l10n.tenantFacilityTenantSlugLabel, _display(proposed.slug, l10n)),
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
    final AppStatusColors statusColors = theme.statusColors;
    final bool hardConflict = match.exactSlugConflict;
    final Color accent = hardConflict
        ? statusColors.error
        : statusColors.warning;
    final Color badgeContainer = hardConflict
        ? statusColors.errorContainer
        : statusColors.warningContainer;
    final Color badgeOnContainer = hardConflict
        ? statusColors.onErrorContainer
        : statusColors.onWarningContainer;
    final List<TenantFieldComparison> comparisons = _sortedComparisons(
      match.fieldComparisons,
    );

    return AppContentPanel(
      tone: hardConflict
          ? AppWorkspaceStatusTone.error
          : AppWorkspaceStatusTone.neutral,
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                hardConflict
                    ? Icons.gpp_bad_outlined
                    : Icons.apartment_outlined,
                color: accent,
                size: theme.appTokens.listIconSize,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.tenantFacilitySimilarTenantExistingHeading,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      match.tenant.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (match.tenant.slug != null &&
                        match.tenant.slug!.trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        match.tenant.slug!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm,
                  vertical: theme.spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: badgeContainer,
                  borderRadius: BorderRadius.circular(theme.radius.md),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${match.score}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: badgeOnContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      hardConflict
                          ? l10n.tenantFacilitySimilarTenantExactConflictLabel
                          : match.score >= tenantSimilarityThreshold
                          ? l10n.tenantFacilitySimilarTenantNearMatchLabel
                          : l10n.tenantFacilitySimilarTenantPartialMatchLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeOnContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(theme.radius.sm),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.tenantFacilitySimilarTenantComparisonHeading,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool compact = constraints.maxWidth < 620;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (!compact) ...<Widget>[
                                _ComparisonTableHeader(),
                                SizedBox(height: theme.spacing.xs),
                              ],
                              for (
                                int index = 0;
                                index < comparisons.length;
                                index += 1
                              ) ...<Widget>[
                                if (index > 0 || !compact)
                                  Divider(
                                    height: theme.spacing.md,
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.55),
                                  ),
                                if (compact)
                                  _FieldComparisonStacked(
                                    comparison: comparisons[index],
                                  )
                                else
                                  _FieldComparisonRow(
                                    comparison: comparisons[index],
                                  ),
                              ],
                            ],
                          );
                        },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.secondary(
              label: l10n.tenantFacilityUseExistingTenantAction,
              leadingIcon: Icons.open_in_new,
              onPressed: onUseExisting,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final TextStyle style = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );

    return Row(
      children: <Widget>[
        SizedBox(
          width: 128,
          child: Text(l10n.tenantFacilitySimilarTenantFieldLabel, style: style),
        ),
        Expanded(
          child: Text(
            l10n.tenantFacilitySimilarTenantProposedValueLabel,
            style: style,
          ),
        ),
        Expanded(
          child: Text(
            l10n.tenantFacilitySimilarTenantExistingValueLabel,
            style: style,
          ),
        ),
        SizedBox(
          width: 108,
          child: Text(
            l10n.tenantFacilitySimilarTenantStatusLabel,
            style: style,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _FieldComparisonRow extends StatelessWidget {
  const _FieldComparisonRow({required this.comparison});

  final TenantFieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 128,
          child: Text(
            _fieldLabel(l10n, comparison.field),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _display(comparison.inputValue, l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _display(comparison.candidateValue, l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 108,
          child: Align(
            alignment: Alignment.centerRight,
            child: _StatusChip(comparison: comparison),
          ),
        ),
      ],
    );
  }
}

class _FieldComparisonStacked extends StatelessWidget {
  const _FieldComparisonStacked({required this.comparison});

  final TenantFieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _fieldLabel(l10n, comparison.field),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _StatusChip(comparison: comparison),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        _StackedValue(
          label: l10n.tenantFacilitySimilarTenantProposedValueLabel,
          value: _display(comparison.inputValue, l10n),
        ),
        SizedBox(height: theme.spacing.xs / 2),
        _StackedValue(
          label: l10n.tenantFacilitySimilarTenantExistingValueLabel,
          value: _display(comparison.candidateValue, l10n),
        ),
      ],
    );
  }
}

class _StackedValue extends StatelessWidget {
  const _StackedValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.comparison});

  final TenantFieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final (Color bg, Color fg, Color border) = switch (comparison.status) {
      TenantFieldComparisonStatus.match => (
        statusColors.successContainer,
        statusColors.onSuccessContainer,
        statusColors.success.withValues(alpha: 0.45),
      ),
      TenantFieldComparisonStatus.similar => (
        statusColors.warningContainer,
        statusColors.onWarningContainer,
        statusColors.warning.withValues(alpha: 0.45),
      ),
      TenantFieldComparisonStatus.different => (
        statusColors.errorContainer,
        statusColors.onErrorContainer,
        statusColors.error.withValues(alpha: 0.4),
      ),
      TenantFieldComparisonStatus.missing => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.outlineVariant,
      ),
    };

    final String label = _statusLabel(l10n, comparison.status);
    final String? score = comparison.score == null
        ? null
        : '${comparison.score}%';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: border),
      ),
      child: Text(
        score == null ? label : '$label · $score',
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

List<TenantFieldComparison> _sortedComparisons(
  List<TenantFieldComparison> comparisons,
) {
  int rank(TenantFieldComparisonStatus status) {
    return switch (status) {
      TenantFieldComparisonStatus.match => 0,
      TenantFieldComparisonStatus.similar => 1,
      TenantFieldComparisonStatus.different => 2,
      TenantFieldComparisonStatus.missing => 3,
    };
  }

  final List<TenantFieldComparison> next = List<TenantFieldComparison>.of(
    comparisons,
  );
  next.sort((TenantFieldComparison left, TenantFieldComparison right) {
    final int byStatus = rank(left.status).compareTo(rank(right.status));
    if (byStatus != 0) {
      return byStatus;
    }
    return (right.score ?? -1).compareTo(left.score ?? -1);
  });
  return next;
}

String _display(String? value, AppLocalizations l10n) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? l10n.clinicalOrderEmptyValueLabel : trimmed;
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
