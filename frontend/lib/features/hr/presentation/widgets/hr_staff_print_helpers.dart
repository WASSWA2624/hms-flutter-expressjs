import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

enum HrStaffPrintSection {
  overview,
  assignments,
  rosters,
  leaves,
  payroll,
  roles,
  permissions,
}

final class HrStaffPrintOptionsController extends ChangeNotifier {
  HrStaffPrintOptionsController({
    Set<HrStaffPrintSection> initial = const <HrStaffPrintSection>{
      HrStaffPrintSection.overview,
      HrStaffPrintSection.assignments,
      HrStaffPrintSection.rosters,
      HrStaffPrintSection.leaves,
      HrStaffPrintSection.payroll,
      HrStaffPrintSection.roles,
      HrStaffPrintSection.permissions,
    },
  }) : _selected = Set<HrStaffPrintSection>.from(initial);

  final Set<HrStaffPrintSection> _selected;

  Set<HrStaffPrintSection> get selectedSections =>
      Set<HrStaffPrintSection>.unmodifiable(_selected);

  Set<Object> get selectedIds => _selected.cast<Object>().toSet();

  bool get canPrint => _selected.isNotEmpty;

  void setSelection(Set<Object> selected) {
    final Set<HrStaffPrintSection> next = <HrStaffPrintSection>{
      for (final Object id in selected)
        if (id is HrStaffPrintSection) id,
    };
    if (next.length == _selected.length && _selected.containsAll(next)) {
      return;
    }
    _selected
      ..clear()
      ..addAll(next);
    notifyListeners();
  }
}

class HrStaffPrintOptionsSection extends StatelessWidget {
  const HrStaffPrintOptionsSection({required this.controller, super.key});

  final HrStaffPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        return AppFormSection(
          title: l10n.hrStaffPrintContentSection,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            Text(
              l10n.hrStaffPrintContentSectionHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: HrStaffPrintSection.overview,
                  title: l10n.hrStaffDetailsSectionTitle,
                  icon: Icons.badge_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.assignments,
                  title: l10n.hrAssignmentsSectionTitle,
                  icon: Icons.account_tree_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.rosters,
                  title: l10n.hrStaffRostersSectionTitle,
                  icon: Icons.calendar_month_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.leaves,
                  title: l10n.hrStaffLeavesSectionTitle,
                  icon: Icons.event_busy_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.payroll,
                  title: l10n.hrStaffPayrollSectionTitle,
                  icon: Icons.payments_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.roles,
                  title: l10n.hrRolesSectionTitle,
                  icon: Icons.badge_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.permissions,
                  title: l10n.hrStaffPermissionsSectionTitle,
                  icon: Icons.shield_outlined,
                ),
              ],
              selectedIds: controller.selectedIds,
              onSelectionChanged: controller.setSelection,
            ),
          ],
        );
      },
    );
  }
}

Future<void> showHrStaffPrintPreview({
  required BuildContext context,
  required WidgetRef ref,
  required HrStaffDetail detail,
}) async {
  final AppLocalizations l10n = context.l10n;
  final HrStaffProfile profile = detail.profile;
  final HrStaffPrintOptionsController options = HrStaffPrintOptionsController();

  String buildBodyHtml() =>
      buildHrStaffPrintHtml(l10n, detail, options.selectedSections);

  try {
    await PrintDocumentTemplates.registry(
      ref: ref,
      context: context,
      title: profile.displayName,
      subtitle: profile.staffNumber ?? profile.effectiveId,
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewDialogTitle: l10n.hrStaffPrintDialogTitle,
      previewSectionsExtra: HrStaffPrintOptionsSection(controller: options),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
    );
  } finally {
    options.dispose();
  }
}

String buildHrStaffPrintHtml(
  AppLocalizations l10n,
  HrStaffDetail detail,
  Set<HrStaffPrintSection> sections,
) {
  final HrStaffProfile profile = detail.profile;
  final StringBuffer buffer = StringBuffer();
  buffer.writeln(
    '<div style="font-family:Segoe UI,Arial,sans-serif;color:#1A237E;">'
    '<h1 style="margin:0 0 4px;font-size:22px;">${_esc(profile.displayName)}</h1>'
    '<p style="margin:0 0 18px;color:#546E7A;font-size:13px;">'
    '${_esc(profile.staffNumber ?? profile.effectiveId)}'
    '${profile.position == null ? '' : ' · ${_esc(profile.position!)}'}'
    '</p>',
  );

  if (sections.contains(HrStaffPrintSection.overview)) {
    buffer.writeln(_sectionTitle(l10n.hrStaffDetailsSectionTitle));
    buffer.writeln(_tableStart());
    _row(buffer, l10n.hrPositionLabel, profile.position ?? '—');
    _row(
      buffer,
      l10n.hrPractitionerTypeLabel,
      l10n.hrReferencePractitionerTypeLabel(
        profile.practitionerType,
        fallback: profile.practitionerType ?? '—',
      ),
    );
    _row(
      buffer,
      l10n.hrDepartmentLabel,
      profile.departmentName ?? profile.departmentDisplayId ?? '—',
    );
    _row(
      buffer,
      l10n.hrStatusLabel,
      profile.status ?? '—',
    );
    _row(
      buffer,
      l10n.hrEmailLabel,
      profile.userEmail ?? '—',
    );
    buffer.writeln(_tableEnd());
  }

  if (sections.contains(HrStaffPrintSection.assignments)) {
    buffer.writeln(_sectionTitle(l10n.hrAssignmentsSectionTitle));
    final List<HrStaffAssignment> rows = detail.assignments
        .where((HrStaffAssignment row) => row.isActive)
        .toList(growable: false);
    if (rows.isEmpty) {
      buffer.writeln('<p style="color:#78909C;">${_esc(l10n.hrNoAssignmentsLabel)}</p>');
    } else {
      buffer.writeln(_tableStart());
      for (final HrStaffAssignment assignment in rows) {
        _row(
          buffer,
          hrAssignmentTitle(assignment, l10n),
          assignment.isPrimary ? l10n.hrPrimaryAssignmentLabel : '—',
        );
      }
      buffer.writeln(_tableEnd());
    }
  }

  if (sections.contains(HrStaffPrintSection.rosters)) {
    buffer.writeln(_sectionTitle(l10n.hrStaffRostersSectionTitle));
    if (detail.shiftAssignments.isEmpty) {
      buffer.writeln(
        '<p style="color:#78909C;">${_esc(l10n.hrStaffRostersEmptyTitle)}</p>',
      );
    } else {
      buffer.writeln(_tableStart());
      for (final HrShiftAssignment shift in detail.shiftAssignments) {
        final String when = shift.startTime == null
            ? '—'
            : AppFormatters.dateTime(shift.startTime!, const Locale('en'));
        _row(
          buffer,
          shift.shiftName ?? shift.shiftType ?? shift.displayId ?? shift.id,
          when,
        );
      }
      buffer.writeln(_tableEnd());
    }
  }

  if (sections.contains(HrStaffPrintSection.leaves)) {
    buffer.writeln(_sectionTitle(l10n.hrStaffLeavesSectionTitle));
    if (detail.leaves.isEmpty) {
      buffer.writeln('<p style="color:#78909C;">${_esc(l10n.hrNoLeaveLabel)}</p>');
    } else {
      buffer.writeln(_tableStart());
      for (final HrStaffLeave leave in detail.leaves) {
        _row(
          buffer,
          l10n.hrReferenceLeaveTypeLabel(
            leave.leaveType,
            fallback: leave.leaveType ?? l10n.hrLeaveLabel,
          ),
          '${leave.status ?? '—'} · ${leave.startDate?.toIso8601String().substring(0, 10) ?? '—'}',
        );
      }
      buffer.writeln(_tableEnd());
    }
  }

  if (sections.contains(HrStaffPrintSection.payroll)) {
    buffer.writeln(_sectionTitle(l10n.hrStaffPayrollSectionTitle));
    final List<HrStaffCompensation> comps = detail.compensations
        .where((HrStaffCompensation row) => row.isActive)
        .toList(growable: false);
    if (comps.isEmpty && profile.consultationFee == null) {
      buffer.writeln(
        '<p style="color:#78909C;">${_esc(l10n.hrNoCompensationLabel)}</p>',
      );
    } else {
      buffer.writeln(_tableStart());
      for (final HrStaffCompensation row in comps) {
        _row(
          buffer,
          l10n.hrReferenceCompensationPayTypeLabel(
            row.payType ?? '',
            fallback: row.payType ?? '—',
          ),
          '${row.rate ?? '—'} ${row.currency ?? ''}'.trim(),
        );
      }
      if (profile.consultationFee != null) {
        _row(
          buffer,
          l10n.hrConsultationFeeLabel,
          '${profile.consultationFee} ${profile.consultationCurrency ?? ''}'
              .trim(),
        );
      }
      buffer.writeln(_tableEnd());
    }
  }

  if (sections.contains(HrStaffPrintSection.roles)) {
    buffer.writeln(_sectionTitle(l10n.hrRolesSectionTitle));
    final List<HrUserRole> roles =
        detail.accessSummary?.userRoles ?? const <HrUserRole>[];
    if (roles.isEmpty) {
      buffer.writeln('<p style="color:#78909C;">${_esc(l10n.hrNoRolesLabel)}</p>');
    } else {
      buffer.writeln(
        '<p>${roles.map((HrUserRole role) => _esc(role.roleName ?? role.roleId ?? '')).where((String v) => v.isNotEmpty).join(' · ')}</p>',
      );
    }
  }

  if (sections.contains(HrStaffPrintSection.permissions)) {
    buffer.writeln(_sectionTitle(l10n.hrStaffPermissionsSectionTitle));
    final List<String> permissions =
        detail.accessSummary?.effectivePermissions ?? const <String>[];
    if (permissions.isEmpty) {
      buffer.writeln(
        '<p style="color:#78909C;">${_esc(l10n.hrStaffPermissionsEmptyTitle)}</p>',
      );
    } else {
      buffer.writeln(
        '<p style="font-size:12px;line-height:1.6;">${permissions.map(_esc).join(' · ')}</p>',
      );
    }
  }

  buffer.writeln('</div>');
  return buffer.toString();
}

String _sectionTitle(String title) =>
    '<h2 style="margin:18px 0 8px;font-size:15px;border-bottom:2px solid #E3F2FD;padding-bottom:6px;">${_esc(title)}</h2>';

String _tableStart() =>
    '<table style="width:100%;border-collapse:collapse;margin:0 0 8px;font-size:12px;"><tbody>';

String _tableEnd() => '</tbody></table>';

void _row(StringBuffer buffer, String label, String value) {
  buffer.writeln(
    '<tr>'
    '<td style="padding:8px 10px;width:34%;color:#546E7A;border-bottom:1px solid #ECEFF1;">${_esc(label)}</td>'
    '<td style="padding:8px 10px;border-bottom:1px solid #ECEFF1;font-weight:600;">${_esc(value)}</td>'
    '</tr>',
  );
}

String _esc(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
