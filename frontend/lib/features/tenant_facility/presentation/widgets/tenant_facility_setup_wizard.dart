import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class TenantFacilitySetupChecklist extends StatelessWidget {
  const TenantFacilitySetupChecklist({required this.snapshot, super.key});

  final FacilitySetupSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppScreenSection(
      title: l10n.tenantFacilityChecklistTitle,
      body: l10n.tenantFacilityChecklistBody(
        snapshot.completedChecklistItems,
        4,
      ),
      child: Column(
        children: <Widget>[
          _ChecklistItem(
            completed: snapshot.hasTenant,
            label: l10n.tenantFacilityChecklistTenant,
          ),
          _ChecklistItem(
            completed: snapshot.hasFacilityIdentity,
            label: l10n.tenantFacilityChecklistIdentity,
          ),
          _ChecklistItem(
            completed: snapshot.hasDepartmentsAndUnits,
            label: l10n.tenantFacilityChecklistDepartments,
          ),
          _ChecklistItem(
            completed:
                snapshot.roomsCount > 0 ||
                snapshot.wardsCount > 0 ||
                snapshot.bedsCount > 0,
            label: l10n.tenantFacilityChecklistLocations,
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.completed, required this.label});

  final bool completed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Row(
        children: <Widget>[
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed
                ? theme.statusColors.success
                : theme.colorScheme.onSurfaceVariant,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.xs),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class TenantFacilitySetupWizard extends StatelessWidget {
  const TenantFacilitySetupWizard({
    required this.snapshot,
    required this.onStepSelected,
    super.key,
  });

  final FacilitySetupSnapshot snapshot;
  final ValueChanged<TenantFacilitySetupWizardStep> onStepSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final TenantFacilitySetupWizardStep? nextStep =
        tenantFacilityNextIncompleteWizardStep(snapshot);

    return AppScreenSection(
      title: l10n.tenantFacilityWizardTitle,
      body: l10n.tenantFacilityWizardBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ...TenantFacilitySetupWizardStep.values.map((
            TenantFacilitySetupWizardStep step,
          ) {
            final bool completed = tenantFacilityWizardStepCompleted(
              snapshot,
              step,
            );

            return Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.xs),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: completed
                      ? theme.statusColors.success.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    completed ? Icons.check : Icons.circle_outlined,
                    size: 16,
                    color: completed
                        ? theme.statusColors.success
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(tenantFacilityWizardStepLabel(l10n, step)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onStepSelected(step),
              ),
            );
          }),
          if (nextStep != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            AppButton.primary(
              label: l10n.tenantFacilityWizardContinueAction,
              leadingIcon: Icons.play_arrow_outlined,
              onPressed: () => onStepSelected(nextStep),
            ),
          ],
        ],
      ),
    );
  }
}
