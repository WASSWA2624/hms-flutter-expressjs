import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/patient_registry_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class PatientPharmacyContextPanel extends StatelessWidget {
  const PatientPharmacyContextPanel({required this.detail, super.key});

  final PatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<PatientSummaryRecord> orders = detail.workspace.pharmacyOrders;

    return AppWorkspaceDetailPanel(
      title: l10n.patientsPharmacyOrdersSectionTitle,
      actions: <Widget>[
        AppAccessActionGate(
          requirement: PatientActiveAtomPermissions.pharmacyWorkbench,
          builder: (_, bool isAllowed) {
            if (!isAllowed) {
              return const SizedBox.shrink();
            }
            return AppButton.secondary(
              label: l10n.patientsOpenPharmacyWorkbenchAction,
              leadingIcon: Icons.local_pharmacy_outlined,
              onPressed: () => context.go(AppRoutes.pharmacy.path),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (orders.isEmpty)
            Text(
              l10n.patientsNoPharmacyOrders,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...orders.map((PatientSummaryRecord order) {
              final String? occurredAt = order.occurredAt == null
                  ? null
                  : AppFormatters.dateTime(
                      order.occurredAt!,
                      Localizations.localeOf(context),
                    );
              final String subtitle = <String>[
                if ((order.status ?? '').trim().isNotEmpty) order.status!.trim(),
                ?occurredAt,
              ].join(' · ');

              return Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.xs),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medication_liquid_outlined),
                  title: Text(
                    (order.title ?? '').trim().isNotEmpty
                        ? order.title!.trim()
                        : order.kind,
                  ),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                ),
              );
            }),
        ],
      ),
    );
  }
}
