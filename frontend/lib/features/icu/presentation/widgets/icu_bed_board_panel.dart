import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_format.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// ICU-ward scoped bed board (icu-flow §7, ipd-flow §14.2). Read view over the
/// shared bed catalog filtered to ICU wards; bed CRUD remains in Facility/IPD.
class IcuBedBoardPanel extends ConsumerWidget {
  const IcuBedBoardPanel({
    required this.state,
    required this.writeRequirement,
    super.key,
  });

  final IcuWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final IcuBedBoard board = state.bedBoard;
    final List<IcuBed> beds = board.visibleBeds;

    return AppWorkspaceDetailPanel(
      title: l10n.icuBedBoardTitle,
      description: l10n.icuBedBoardDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (board.wards.isNotEmpty)
            Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                ChoiceChip(
                  label: Text(l10n.icuBedBoardAllWards),
                  selected: board.selectedWardId == null,
                  onSelected: (_) => controller.selectBedWard(null),
                ),
                for (final IcuBedWard ward in board.wards)
                  ChoiceChip(
                    label: Text(ward.displayTitle),
                    selected: board.selectedWardId == ward.id,
                    onSelected: (_) => controller.selectBedWard(ward.id),
                  ),
              ],
            ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label: l10n.icuBedAvailableLabel(board.availableCount),
                  tone: AppWorkspaceStatusTone.success,
                ),
              ),
              AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label: l10n.icuBedOccupiedLabel(board.occupiedCount),
                  tone: AppWorkspaceStatusTone.info,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          if (state.isRefreshingBeds && beds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (beds.isEmpty)
            AppWorkspaceStatePanel.state(
              variant: AppStateViewVariant.empty,
              title: l10n.icuBedNoBedsTitle,
              body: l10n.icuBedNoBedsBody,
              icon: Icons.bed_outlined,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  var index = 0;
                  index < beds.length;
                  index += 1
                ) ...<Widget>[
                  if (index > 0) const Divider(height: 1),
                  _IcuBedRow(bed: beds[index]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _IcuBedRow extends StatelessWidget {
  const _IcuBedRow({required this.bed});

  final IcuBed bed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool occupied = bed.isOccupied;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            occupied ? Icons.bed : Icons.bed_outlined,
            size: theme.appTokens.listIconSize,
            color: bed.occupantHasCriticalAlert
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  bed.locationLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  occupied
                      ? joinDisplay(<String?>[
                          bed.occupantName,
                          bed.occupantDisplayId,
                        ])
                      : l10n.icuBedVacantLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: apiLabel(bed.status ?? ''),
              tone: bedStatusTone(bed.status),
            ),
          ),
          if (occupied) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            AppIconButton(
              icon: Icons.open_in_new_outlined,
              semanticLabel: l10n.icuActionOpenIpd,
              tooltip: l10n.icuActionOpenIpd,
              onPressed: () => _openIpd(context, bed),
            ),
          ],
        ],
      ),
    );
  }

  void _openIpd(BuildContext context, IcuBed bed) {
    final String? admissionId = bed.occupantAdmissionId?.trim();
    final String location = admissionId == null || admissionId.isEmpty
        ? AppRoutes.ipd.path
        : AppRoutes.ipd.location(
            queryParameters: <String, String>{'id': admissionId},
          );
    context.go(location);
  }
}
