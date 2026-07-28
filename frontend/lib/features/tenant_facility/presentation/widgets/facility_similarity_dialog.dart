import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/facility_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'tenant_facility_setup_helpers.dart';

enum FacilitySimilarityAction { cancel, useExisting, proceed }

final class FacilitySimilarityDialogResult {
  const FacilitySimilarityDialogResult._({
    required this.action,
    this.selectedFacility,
  });

  const FacilitySimilarityDialogResult.cancel()
    : this._(action: FacilitySimilarityAction.cancel);

  const FacilitySimilarityDialogResult.proceed()
    : this._(action: FacilitySimilarityAction.proceed);

  const FacilitySimilarityDialogResult.useExisting(FacilityProfile facility)
    : this._(
        action: FacilitySimilarityAction.useExisting,
        selectedFacility: facility,
      );

  final FacilitySimilarityAction action;
  final FacilityProfile? selectedFacility;
}

Future<FacilitySimilarityDialogResult> showFacilitySimilarityDialog(
  BuildContext context, {
  required FacilitySimilarityProposedValues proposed,
  required List<FacilitySimilarityMatch> matches,
  bool allowProceed = true,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<FacilitySimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (FacilitySimilarityMatch match) => match.exactNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;

  final String dialogTitle = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarFacilityDialogTitle
      : l10n.tenantFacilityNoSimilarTenantDialogTitle;

  final String proceedLabel = hasMatches
      ? l10n.tenantFacilityProceedCreateFacilityAction
      : l10n.tenantFacilityContinueCreateTenantAction;

  return showAppDialog<FacilitySimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final AppFormInformationVariant bannerVariant = hasExactNameConflict
          ? AppFormInformationVariant.error
          : hasMatches
          ? AppFormInformationVariant.warning
          : AppFormInformationVariant.success;
      final String bannerTitle = hasExactNameConflict
          ? l10n.tenantFacilityFacilityNameAlreadyInUse
          : hasMatches
          ? l10n.tenantFacilitySimilarFacilityWarningTitle
          : l10n.tenantFacilityNoSimilarTenantBannerTitle;
      final String bannerMessage = hasExactNameConflict
          ? l10n.tenantFacilitySimilarFacilityWarningBody
          : hasMatches
          ? l10n.tenantFacilitySimilarFacilityWarningBody
          : l10n.tenantFacilityNoSimilarTenantDialogBody;

      return AppDialog(
        title: Text(dialogTitle),
        icon: Icon(
          hasExactNameConflict
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
              icon: hasExactNameConflict
                  ? Icons.gpp_bad_outlined
                  : hasMatches
                  ? Icons.manage_search_outlined
                  : Icons.verified_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedFacilityCard(proposed: proposed),
            if (hasMatches) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.tenantFacilitySimilarTenantMatchesHeading,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    l10n.tenantFacilitySimilarTenantMatchCountLabel(
                      visibleMatches.length,
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              for (int index = 0; index < visibleMatches.length; index += 1) ...<
                Widget
              >[
                if (index > 0) SizedBox(height: theme.spacing.md),
                _FacilitySimilarityMatchCard(
                  match: visibleMatches[index],
                  onUseExisting: () => Navigator.of(dialogContext).pop(
                    FacilitySimilarityDialogResult.useExisting(
                      visibleMatches[index].facility,
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
              const FacilitySimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: proceedLabel,
              leadingIcon: hasMatches
                  ? Icons.add_business_outlined
                  : Icons.check_circle_outline,
              onPressed: () => Navigator.of(dialogContext).pop(
                const FacilitySimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (FacilitySimilarityDialogResult? value) =>
        value ?? const FacilitySimilarityDialogResult.cancel(),
  );
}

class _ProposedFacilityCard extends StatelessWidget {
  const _ProposedFacilityCard({required this.proposed});

  final FacilitySimilarityProposedValues proposed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String typeLabel = tenantFacilityFacilityTypeLabel(l10n, proposed.type);
    final String statusLabel = tenantFacilityActiveStatusLabel(l10n, proposed.isActive);

    final List<(String, String)> facts = <(String, String)>[
      (l10n.tenantFacilityTenantNameLabel, _display(proposed.name, l10n)),
      (l10n.authFacilityTypeLabel, typeLabel),
      (l10n.tenantFacilityActiveLabel, statusLabel),
      (l10n.profilePhoneLabel, _display(proposed.phone, l10n)),
      (l10n.profileEmailLabel, _display(proposed.email, l10n)),
      (l10n.tenantFacilityAddressLineLabel, _display(proposed.addressLine1, l10n)),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
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

class _FacilitySimilarityMatchCard extends StatelessWidget {
  const _FacilitySimilarityMatchCard({
    required this.match,
    required this.onUseExisting,
  });

  final FacilitySimilarityMatch match;
  final VoidCallback onUseExisting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final bool hardConflict = match.exactNameConflict;
    final Color accent = hardConflict
        ? statusColors.error
        : statusColors.warning;
    final Color badgeContainer = hardConflict
        ? statusColors.errorContainer
        : statusColors.warningContainer;
    final Color badgeOnContainer = hardConflict
        ? statusColors.onErrorContainer
        : statusColors.onWarningContainer;
    final List<FacilityFieldComparison> comparisons = _sortedComparisons(
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
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      match.facility.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (match.facility.displayId != null &&
                        match.facility.displayId!.trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        match.facility.displayId!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      hardConflict
                          ? l10n.tenantFacilitySimilarTenantExactConflictLabel
                          : match.score >= facilitySimilarityThreshold
                          ? l10n.tenantFacilitySimilarTenantNearMatchLabel
                          : l10n.tenantFacilitySimilarTenantPartialMatchLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeOnContainer,
                        fontWeight: FontWeight.w600,
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
                      fontWeight: FontWeight.w600,
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
      fontWeight: FontWeight.w600,
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

  final FacilityFieldComparison comparison;

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
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _display(comparison.inputValue, l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _display(comparison.candidateValue, l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
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

  final FacilityFieldComparison comparison;

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
                  fontWeight: FontWeight.w600,
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
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.comparison});

  final FacilityFieldComparison comparison;

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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

List<FacilityFieldComparison> _sortedComparisons(
  List<FacilityFieldComparison> comparisons,
) {
  int rank(FacilityFieldComparisonStatus status) {
    return switch (status) {
      TenantFieldComparisonStatus.match => 0,
      TenantFieldComparisonStatus.similar => 1,
      TenantFieldComparisonStatus.different => 2,
      TenantFieldComparisonStatus.missing => 3,
    };
  }

  final List<FacilityFieldComparison> next = List<FacilityFieldComparison>.of(
    comparisons,
  );
  next.sort((FacilityFieldComparison left, FacilityFieldComparison right) {
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
    'name' => l10n.authFacilityNameLabel,
    'facility_type' => l10n.authFacilityTypeLabel,
    'status' => l10n.tenantFacilityActiveLabel,
    'phone' => l10n.profilePhoneLabel,
    'email' => l10n.profileEmailLabel,
    'address_line1' => l10n.tenantFacilityAddressLineLabel,
    'city' => l10n.tenantFacilityCityLabel,
    'country' => l10n.tenantFacilityCountryLabel,
    'display_id' => l10n.accessAdminColumnDetails,
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
