import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class DischargeClearanceTile extends StatelessWidget {
  const DischargeClearanceTile({
    required this.item,
    this.titleMaxLines = 1,
    this.showReference = true,
    super.key,
  });

  final DischargeClearanceItem item;
  final int titleMaxLines;
  final bool showReference;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppWorkspaceStatus status = dischargeClearanceStatus(
      context,
      item.state,
    );

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                dischargeClearanceIcon(item.code),
                size: theme.appTokens.listIconSize,
                color: colorScheme.primary,
              ),
              SizedBox(width: theme.spacing.xs),
              Expanded(
                child: Text(
                  dischargeClearanceLabel(context, item.code),
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          AppWorkspaceStatusBadge(status: status),
          if (showReference && item.reference != null) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            Text(
              item.reference!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

AppWorkspaceStatus dischargeClearanceStatus(
  BuildContext context,
  DischargeClearanceState state,
) {
  return switch (state) {
    DischargeClearanceState.complete => AppWorkspaceStatus(
      label: context.l10n.dischargeClearanceComplete,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.check_circle_outline,
    ),
    DischargeClearanceState.pending => AppWorkspaceStatus(
      label: context.l10n.dischargeClearancePending,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.schedule_outlined,
    ),
    DischargeClearanceState.unavailable => AppWorkspaceStatus(
      label: context.l10n.dischargeClearanceUnavailable,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.lock_outline,
    ),
  };
}

IconData dischargeClearanceIcon(DischargeClearanceCode code) {
  return switch (code) {
    DischargeClearanceCode.doctor => Icons.medical_information_outlined,
    DischargeClearanceCode.nursing => Icons.health_and_safety_outlined,
    DischargeClearanceCode.pharmacy => Icons.medication_outlined,
    DischargeClearanceCode.billing => Icons.receipt_long_outlined,
    DischargeClearanceCode.insurance => Icons.policy_outlined,
    DischargeClearanceCode.documents => Icons.description_outlined,
    DischargeClearanceCode.bedRelease => Icons.bed_outlined,
    DischargeClearanceCode.housekeeping => Icons.cleaning_services_outlined,
  };
}

String dischargeClearanceLabel(
  BuildContext context,
  DischargeClearanceCode code,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (code) {
    DischargeClearanceCode.doctor => l10n.dischargeClearanceDoctor,
    DischargeClearanceCode.nursing => l10n.dischargeClearanceNursing,
    DischargeClearanceCode.pharmacy => l10n.dischargeClearancePharmacy,
    DischargeClearanceCode.billing => l10n.dischargeClearanceBilling,
    DischargeClearanceCode.insurance => l10n.dischargeClearanceInsurance,
    DischargeClearanceCode.documents => l10n.dischargeClearanceDocuments,
    DischargeClearanceCode.bedRelease => l10n.dischargeClearanceBedRelease,
    DischargeClearanceCode.housekeeping =>
      l10n.dischargeClearanceHousekeeping,
  };
}
