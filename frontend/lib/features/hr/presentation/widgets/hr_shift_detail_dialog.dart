import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> showHrShiftDetailDialog(
  BuildContext context,
  HrShiftAssignment assignment,
  HrReferenceData referenceData, {
  VoidCallback? onSwap,
  VoidCallback? onRemove,
  bool actionsEnabled = true,
}) async {
  final AppLocalizations l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.hrShiftDetailDialogTitle),
      icon: const Icon(Icons.calendar_view_week_outlined),
      content: AppInfoTileGrid(
        emptyValue: l10n.profileUnknownValue,
        items: <AppInfoTileData>[
          AppInfoTileData(
            label: l10n.hrShiftLabel,
            value: hrShiftAssignmentTitle(assignment, referenceData, l10n),
            icon: Icons.calendar_view_week_outlined,
          ),
          AppInfoTileData(
            label: l10n.hrShiftTypeLabel,
            value: assignment.shiftType,
            icon: Icons.category_outlined,
          ),
          AppInfoTileData(
            label: l10n.hrStatusColumnLabel,
            value: assignment.shiftStatus,
            icon: Icons.radio_button_checked,
          ),
          AppInfoTileData(
            label: l10n.hrAssignedAtLabel,
            value: assignment.assignedAt == null
                ? null
                : AppFormatters.dateTime(assignment.assignedAt!, locale),
            icon: Icons.schedule_outlined,
          ),
          AppInfoTileData(
            label: l10n.hrRosterPeriodLabel,
            value: assignment.rosterPeriodLabel,
            icon: Icons.date_range_outlined,
          ),
        ],
      ),
      actions: <Widget>[
        if (actionsEnabled && onSwap != null)
          AppButton.secondary(
            label: l10n.hrSwapShiftAction,
            leadingIcon: Icons.swap_horiz_outlined,
            onPressed: () {
              Navigator.of(context).pop();
              onSwap();
            },
          ),
        if (actionsEnabled && onRemove != null)
          AppButton.secondary(
            label: l10n.hrRemoveShiftAssignmentAction,
            leadingIcon: Icons.delete_outline,
            onPressed: () {
              Navigator.of(context).pop();
              onRemove();
            },
          ),
        AppButton(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
