import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_department_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> showHrAssignmentDetailDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffDetail detail,
  HrStaffAssignment assignment, {
  required bool isMutating,
}) async {
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => _HrAssignmentDetailDialog(
      detail: detail,
      assignment: assignment,
      isMutating: isMutating,
    ),
  );
}

class _HrAssignmentDetailDialog extends ConsumerWidget {
  const _HrAssignmentDetailDialog({
    required this.detail,
    required this.assignment,
    required this.isMutating,
  });

  final HrStaffDetail detail;
  final HrStaffAssignment assignment;
  final bool isMutating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final HrStaffProfile profile = detail.profile;

    return AppDialog(
      title: Text(l10n.hrAssignmentDetailDialogTitle),
      icon: const Icon(Icons.account_tree_outlined),
      scrollable: true,
      maxWidth: 560,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppInfoTileGrid(
            emptyValue: l10n.profileUnknownValue,
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.hrAssignmentIdLabel,
                value: assignment.displayId ?? assignment.effectiveId,
                icon: Icons.confirmation_number_outlined,
                copyable: true,
              ),
              AppInfoTileData(
                label: l10n.hrStaffNumberLabel,
                value: profile.staffNumber ?? profile.effectiveId,
                icon: Icons.badge_outlined,
              ),
              AppInfoTileData(
                label: l10n.hrStaffNameLabel,
                value: profile.displayName,
                icon: Icons.person_outline,
              ),
              AppInfoTileData(
                label: l10n.hrDepartmentLabel,
                value: assignment.departmentName ?? assignment.departmentDisplayId,
                icon: Icons.account_tree_outlined,
              ),
              if ((assignment.unitName ?? assignment.unitDisplayId ?? '')
                  .trim()
                  .isNotEmpty)
                AppInfoTileData(
                  label: l10n.hrUnitLabel,
                  value: assignment.unitName ?? assignment.unitDisplayId,
                  icon: Icons.apartment_outlined,
                ),
              if ((assignment.roomName ?? assignment.roomDisplayId ?? '')
                  .trim()
                  .isNotEmpty)
                AppInfoTileData(
                  label: l10n.hrRoomLabel,
                  value: assignment.roomName ?? assignment.roomDisplayId,
                  icon: Icons.meeting_room_outlined,
                ),
              AppInfoTileData(
                label: l10n.hrPeriodStartLabel,
                value: hrDateRange(
                  context,
                  assignment.startDate,
                  assignment.endDate,
                ),
                icon: Icons.date_range_outlined,
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              if (assignment.isPrimary)
                AppWorkspaceStatusBadge(status: hrPrimaryAssignmentBadge(l10n)),
              AppWorkspaceStatusBadge(
                status: hrAssignmentStatusBadge(assignment, l10n),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        if (assignment.isActive && !isMutating) ...<Widget>[
          AppButton.secondary(
            label: l10n.hrEditAssignmentAction,
            leadingIcon: Icons.edit_outlined,
            onPressed: () {
              Navigator.of(context).pop();
              showHrAssignDepartmentDialog(context, ref);
            },
          ),
          AppButton.secondary(
            label: l10n.hrEndAssignmentAction,
            leadingIcon: Icons.event_busy_outlined,
            onPressed: () async {
              Navigator.of(context).pop();
              await showHrEndAssignmentDialog(context, ref, assignment);
            },
          ),
        ],
        AppButton(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
