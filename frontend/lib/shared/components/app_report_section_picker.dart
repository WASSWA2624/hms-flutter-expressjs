import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_report_section.dart';

/// Responsive grid of selectable report sections for print/export flows.
class AppReportSectionPicker extends StatelessWidget {
  const AppReportSectionPicker({
    required this.sections,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.minTileWidth = 220,
    this.maxColumns = 3,
    super.key,
  });

  final List<AppReportSectionData> sections;
  final Set<Object> selectedIds;
  final ValueChanged<Set<Object>> onSelectionChanged;
  final double minTileWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = _columnCount(
          constraints.maxWidth,
          sections.length,
          maxColumns,
          minTileWidth,
        );
        final double gap = theme.spacing.sm;
        final double tileWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final AppReportSectionData section in sections)
              SizedBox(
                width: tileWidth.clamp(0, double.infinity),
                child: AppReportSectionTile(
                  section: section,
                  selected: selectedIds.contains(section.id),
                  onChanged: section.enabled
                      ? (bool selected) {
                          final Set<Object> next = Set<Object>.of(selectedIds);
                          if (selected) {
                            next.add(section.id);
                          } else {
                            next.remove(section.id);
                          }
                          onSelectionChanged(next);
                        }
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

int _columnCount(
  double width,
  int itemCount,
  int maxColumns,
  double minTileWidth,
) {
  if (itemCount <= 0) {
    return 1;
  }
  final int fitColumns = (width / minTileWidth).floor().clamp(1, maxColumns);
  return fitColumns.clamp(1, itemCount);
}
