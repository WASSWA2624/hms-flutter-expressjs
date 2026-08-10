import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_staff_position.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Printable content sections for a staff position.
enum HrPositionPrintSection {
  details,
  staff,
}

/// Staff table columns that can be included in the position printout.
enum HrPositionPrintStaffColumn {
  name,
  staffNumber,
  department,
  email,
  status,
  practitionerType,
}

/// Mutable section/column selection for live position print-preview rebuilds.
final class HrPositionPrintOptionsController extends ChangeNotifier {
  HrPositionPrintOptionsController({
    Set<HrPositionPrintSection> initialSections =
        const <HrPositionPrintSection>{
          HrPositionPrintSection.details,
          HrPositionPrintSection.staff,
        },
    Set<HrPositionPrintStaffColumn> initialColumns =
        const <HrPositionPrintStaffColumn>{
          HrPositionPrintStaffColumn.name,
          HrPositionPrintStaffColumn.staffNumber,
          HrPositionPrintStaffColumn.department,
          HrPositionPrintStaffColumn.email,
          HrPositionPrintStaffColumn.status,
          HrPositionPrintStaffColumn.practitionerType,
        },
  }) : _sections = Set<HrPositionPrintSection>.from(initialSections),
       _columns = Set<HrPositionPrintStaffColumn>.from(initialColumns);

  final Set<HrPositionPrintSection> _sections;
  final Set<HrPositionPrintStaffColumn> _columns;

  Set<HrPositionPrintSection> get selectedSections =>
      Set<HrPositionPrintSection>.unmodifiable(_sections);

  Set<HrPositionPrintStaffColumn> get selectedColumns =>
      Set<HrPositionPrintStaffColumn>.unmodifiable(_columns);

  Set<Object> get selectedSectionIds => _sections.cast<Object>().toSet();

  Set<Object> get selectedColumnIds => _columns.cast<Object>().toSet();

  bool get includesStaff => _sections.contains(HrPositionPrintSection.staff);

  bool get canPrint {
    if (_sections.isEmpty) {
      return false;
    }
    if (includesStaff && _columns.isEmpty) {
      return false;
    }
    return true;
  }

  void setSections(Set<Object> selected) {
    final Set<HrPositionPrintSection> next = <HrPositionPrintSection>{
      for (final Object id in selected)
        if (id is HrPositionPrintSection) id,
    };
    if (next.length == _sections.length && _sections.containsAll(next)) {
      return;
    }
    _sections
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  void setColumns(Set<Object> selected) {
    final Set<HrPositionPrintStaffColumn> next = <HrPositionPrintStaffColumn>{
      for (final Object id in selected)
        if (id is HrPositionPrintStaffColumn) id,
    };
    if (next.length == _columns.length && _columns.containsAll(next)) {
      return;
    }
    _columns
      ..clear()
      ..addAll(next);
    notifyListeners();
  }
}

/// Section and column toggles for the shared print-preview dialog.
class HrPositionPrintOptionsSection extends StatelessWidget {
  const HrPositionPrintOptionsSection({required this.controller, super.key});

  final HrPositionPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFormSection(
              title: l10n.hrPositionPrintContentSection,
              density: AppFormSectionDensity.compact,
              children: <Widget>[
                Text(
                  l10n.hrPositionPrintContentSectionHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: theme.spacing.sm),
                AppReportSectionPicker(
                  compact: true,
                  sections: <AppReportSectionData>[
                    AppReportSectionData(
                      id: HrPositionPrintSection.details,
                      title: l10n.hrPositionPrintDetailsSection,
                      icon: Icons.work_outline,
                    ),
                    AppReportSectionData(
                      id: HrPositionPrintSection.staff,
                      title: l10n.hrPositionPrintStaffSection,
                      icon: Icons.groups_outlined,
                    ),
                  ],
                  selectedIds: controller.selectedSectionIds,
                  onSelectionChanged: controller.setSections,
                ),
              ],
            ),
            if (controller.includesStaff) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              AppFormSection(
                title: l10n.hrPositionPrintColumnsSection,
                density: AppFormSectionDensity.compact,
                children: <Widget>[
                  Text(
                    l10n.hrPositionPrintColumnsSectionHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  AppReportSectionPicker(
                    compact: true,
                    sections: <AppReportSectionData>[
                      AppReportSectionData(
                        id: HrPositionPrintStaffColumn.name,
                        title: l10n.hrStaffNameLabel,
                        icon: Icons.person_outline,
                      ),
                      AppReportSectionData(
                        id: HrPositionPrintStaffColumn.staffNumber,
                        title: l10n.hrStaffNumberLabel,
                        icon: Icons.badge_outlined,
                      ),
                      AppReportSectionData(
                        id: HrPositionPrintStaffColumn.department,
                        title: l10n.hrDepartmentLabel,
                        icon: Icons.apartment_outlined,
                      ),
                      AppReportSectionData(
                        id: HrPositionPrintStaffColumn.email,
                        title: l10n.hrEmailLabel,
                        icon: Icons.email_outlined,
                      ),
                      AppReportSectionData(
                        id: HrPositionPrintStaffColumn.status,
                        title: l10n.hrStatusLabel,
                        icon: Icons.info_outline,
                      ),
                      AppReportSectionData(
                        id: HrPositionPrintStaffColumn.practitionerType,
                        title: l10n.hrPractitionerTypeLabel,
                        icon: Icons.medical_services_outlined,
                      ),
                    ],
                    selectedIds: controller.selectedColumnIds,
                    onSelectionChanged: controller.setColumns,
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

Future<void> showHrPositionPrintPreview({
  required BuildContext context,
  required WidgetRef ref,
  required HrStaffPosition position,
  required List<HrStaffProfile> staff,
}) async {
  final AppLocalizations l10n = context.l10n;
  final HrPositionPrintOptionsController options =
      HrPositionPrintOptionsController();

  String buildBodyHtml() => buildHrPositionPrintHtml(
    l10n,
    position: position,
    staff: staff,
    sections: options.selectedSections,
    columns: options.selectedColumns,
  );

  try {
    await PrintDocumentTemplates.registry(
      ref: ref,
      context: context,
      title: position.name,
      subtitle: position.effectiveId,
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewDialogTitle: l10n.hrPositionPrintDialogTitle,
      previewSectionsExtra: HrPositionPrintOptionsSection(controller: options),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
    );
  } finally {
    options.dispose();
  }
}

String buildHrPositionPrintHtml(
  AppLocalizations l10n, {
  required HrStaffPosition position,
  required List<HrStaffProfile> staff,
  required Set<HrPositionPrintSection> sections,
  required Set<HrPositionPrintStaffColumn> columns,
}) {
  final StringBuffer buffer = StringBuffer();
  buffer.writeln(
    '<div style="font-family:Segoe UI,Arial,sans-serif;color:#1A237E;">'
    '<h1 style="margin:0 0 4px;font-size:22px;">${_esc(position.name)}</h1>'
    '<p style="margin:0 0 18px;color:#546E7A;font-size:13px;">'
    '${_esc(l10n.hrPositionPrintDocumentSubtitle)} · ${_esc(position.effectiveId)}'
    '</p>',
  );

  if (sections.contains(HrPositionPrintSection.details)) {
    buffer.writeln(_sectionTitle(l10n.hrPositionPrintDetailsSection));
    buffer.writeln(_kvTableStart());
    _kvRow(buffer, l10n.hrPositionLabel, position.name);
    _kvRow(buffer, l10n.hrPositionIdLabel, position.effectiveId);
    final String description = (position.description ?? '').trim();
    _kvRow(
      buffer,
      l10n.hrPositionDescriptionLabel,
      description.isEmpty ? '—' : description,
    );
    _kvRow(
      buffer,
      l10n.hrPositionScopeLabel,
      position.isShared
          ? l10n.hrPositionScopeShared
          : l10n.hrPositionScopeFacility,
    );
    _kvRow(
      buffer,
      l10n.hrStatusLabel,
      position.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : position.isActive
          ? l10n.hrPositionActiveStatus
          : l10n.hrPositionInactiveStatus,
    );
    buffer.writeln(_tableEnd());
  }

  if (sections.contains(HrPositionPrintSection.staff)) {
    buffer.writeln(_sectionTitle(l10n.hrPositionPrintStaffSection));
    buffer.writeln(
      '<p style="margin:0 0 10px;color:#546E7A;font-size:12px;">'
      '${_esc(l10n.hrPositionAssignedStaffCountChip(staff.length))}'
      '</p>',
    );
    if (staff.isEmpty) {
      buffer.writeln(
        '<p style="color:#78909C;">${_esc(l10n.hrPositionAssignedStaffEmptyTitle)}</p>',
      );
    } else {
      final List<HrPositionPrintStaffColumn> ordered =
          <HrPositionPrintStaffColumn>[
            for (final HrPositionPrintStaffColumn column
                in HrPositionPrintStaffColumn.values)
              if (columns.contains(column)) column,
          ];
      buffer.writeln(
        '<table style="width:100%;border-collapse:collapse;margin:0 0 8px;font-size:12px;">'
        '<thead><tr>',
      );
      for (final HrPositionPrintStaffColumn column in ordered) {
        buffer.writeln(
          '<th style="text-align:left;padding:8px 10px;border-bottom:2px solid #90CAF9;'
          'color:#546E7A;font-weight:600;background:#E3F2FD;">'
          '${_esc(_columnLabel(l10n, column))}</th>',
        );
      }
      buffer.writeln('</tr></thead><tbody>');
      for (final HrStaffProfile row in staff) {
        buffer.write('<tr>');
        for (final HrPositionPrintStaffColumn column in ordered) {
          buffer.write(
            '<td style="padding:8px 10px;border-bottom:1px solid #ECEFF1;'
            'vertical-align:top;">${_esc(_columnValue(l10n, row, column))}</td>',
          );
        }
        buffer.writeln('</tr>');
      }
      buffer.writeln('</tbody></table>');
    }
  }

  buffer.writeln('</div>');
  return buffer.toString();
}

String _columnLabel(AppLocalizations l10n, HrPositionPrintStaffColumn column) {
  return switch (column) {
    HrPositionPrintStaffColumn.name => l10n.hrStaffNameLabel,
    HrPositionPrintStaffColumn.staffNumber => l10n.hrStaffNumberLabel,
    HrPositionPrintStaffColumn.department => l10n.hrDepartmentLabel,
    HrPositionPrintStaffColumn.email => l10n.hrEmailLabel,
    HrPositionPrintStaffColumn.status => l10n.hrStatusLabel,
    HrPositionPrintStaffColumn.practitionerType => l10n.hrPractitionerTypeLabel,
  };
}

String _columnValue(
  AppLocalizations l10n,
  HrStaffProfile row,
  HrPositionPrintStaffColumn column,
) {
  return switch (column) {
    HrPositionPrintStaffColumn.name => row.displayName,
    HrPositionPrintStaffColumn.staffNumber =>
      (row.staffNumber ?? row.effectiveId).trim().isEmpty
          ? '—'
          : (row.staffNumber ?? row.effectiveId),
    HrPositionPrintStaffColumn.department =>
      (row.departmentName ?? row.departmentDisplayId ?? '').trim().isEmpty
          ? '—'
          : (row.departmentName ?? row.departmentDisplayId)!,
    HrPositionPrintStaffColumn.email =>
      (row.userEmail ?? '').trim().isEmpty ? '—' : row.userEmail!,
    HrPositionPrintStaffColumn.status =>
      (row.status ?? '').trim().isEmpty ? '—' : row.status!,
    HrPositionPrintStaffColumn.practitionerType =>
      (row.practitionerType ?? '').trim().isEmpty
          ? '—'
          : l10n.hrReferencePractitionerTypeLabel(
              row.practitionerType,
              fallback: row.practitionerType ?? '—',
            ),
  };
}

String _sectionTitle(String title) =>
    '<h2 style="margin:18px 0 8px;font-size:15px;border-bottom:2px solid #E3F2FD;'
    'padding-bottom:6px;">${_esc(title)}</h2>';

String _kvTableStart() =>
    '<table style="width:100%;border-collapse:collapse;margin:0 0 8px;font-size:12px;"><tbody>';

String _tableEnd() => '</tbody></table>';

void _kvRow(StringBuffer buffer, String label, String value) {
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
