import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> showHrLeaveDetailDialog(
  BuildContext context,
  HrStaffLeave leave,
) async {
  final AppLocalizations l10n = context.l10n;
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.hrLeaveDetailDialogTitle),
      icon: const Icon(Icons.event_busy_outlined),
      content: AppInfoTileGrid(
        emptyValue: l10n.profileUnknownValue,
        items: <AppInfoTileData>[
          AppInfoTileData(
            label: l10n.hrLeaveTypeLabel,
            value: leave.leaveType,
            icon: Icons.category_outlined,
          ),
          AppInfoTileData(
            label: l10n.hrStatusColumnLabel,
            value: leave.status,
            icon: Icons.radio_button_checked,
          ),
          AppInfoTileData(
            label: l10n.hrPeriodStartLabel,
            value: hrDateRange(context, leave.startDate, leave.endDate),
            icon: Icons.date_range_outlined,
          ),
          AppInfoTileData(
            label: l10n.hrLeaveCoveringStaffLabel,
            value: leave.coveringStaffName ?? leave.coveringStaffProfileId,
            icon: Icons.person_outline,
          ),
          AppInfoTileData(
            label: l10n.hrLeaveHandoverNotesLabel,
            value: leave.handoverNotes,
            icon: Icons.notes_outlined,
          ),
          AppInfoTileData(
            label: l10n.hrLeaveReasonLabel,
            value: leave.reason,
            icon: Icons.info_outline,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
