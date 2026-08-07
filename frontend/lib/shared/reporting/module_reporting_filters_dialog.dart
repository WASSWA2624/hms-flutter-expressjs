import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';

bool moduleReportingFiltersAreActive(
  AppSearchBarFilterValue value, {
  required int totalCategories,
  required int totalReports,
}) {
  if (value.dateFrom != null || value.dateTo != null) {
    return true;
  }
  final Set<String> categories = value.optionsFor(
    ModuleReportingFilterKeys.category,
  );
  final Set<String> reports = value.optionsFor(
    ModuleReportingFilterKeys.subcategory,
  );
  final Set<String> kinds = value.optionsFor(
    ModuleReportingFilterKeys.contentKind,
  );
  if (kinds.contains(ModuleReportingFilterKeys.noneSentinel) ||
      categories.contains(ModuleReportingFilterKeys.noneSentinel) ||
      reports.contains(ModuleReportingFilterKeys.noneSentinel)) {
    return true;
  }
  if (kinds.isNotEmpty &&
      kinds.length < ModuleReportingContentKind.values.length) {
    return true;
  }
  if (categories.isNotEmpty && categories.length < totalCategories) {
    return true;
  }
  if (reports.isNotEmpty && reports.length < totalReports) {
    return true;
  }
  return false;
}

Future<void> openModuleReportingFiltersDialog({
  required BuildContext context,
  required List<ModuleReportingCategory> catalog,
  required AppSearchBarFilterValue initialValue,
  required ValueChanged<AppSearchBarFilterValue> onApply,
  required ModuleReportingLabels labels,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => ModuleReportingFiltersDialog(
      catalog: catalog,
      initialValue: initialValue,
      onApply: onApply,
      labels: labels,
    ),
  );
}

class ModuleReportingFiltersDialog extends StatefulWidget {
  const ModuleReportingFiltersDialog({
    required this.catalog,
    required this.initialValue,
    required this.onApply,
    required this.labels,
    super.key,
  });

  final List<ModuleReportingCategory> catalog;
  final AppSearchBarFilterValue initialValue;
  final ValueChanged<AppSearchBarFilterValue> onApply;
  final ModuleReportingLabels labels;

  @override
  State<ModuleReportingFiltersDialog> createState() =>
      _ModuleReportingFiltersDialogState();
}

class _ModuleReportingFiltersDialogState
    extends State<ModuleReportingFiltersDialog> {
  late DateTime? _dateFrom;
  late DateTime? _dateTo;
  String? _dateRangeError;
  late Set<String> _selectedKinds;
  late Set<String> _selectedCategories;
  late Set<String> _selectedReports;
  bool _isApplying = false;

  ModuleReportingLabels get _labels => widget.labels;

  List<String> get _allCategoryIds => widget.catalog
      .map((ModuleReportingCategory category) => category.id)
      .toList(growable: false);

  List<ModuleReportingReport> get _allReports => widget.catalog
      .expand((ModuleReportingCategory category) => category.reports)
      .toList(growable: false);

  List<ModuleReportingReport> get _visibleReports {
    if (_selectedCategories.isEmpty) {
      return const <ModuleReportingReport>[];
    }
    return _allReports
        .where(
          (ModuleReportingReport report) =>
              _selectedCategories.contains(report.categoryId),
        )
        .toList(growable: false);
  }

  bool get _allKindsSelected =>
      _selectedKinds.length == ModuleReportingContentKind.values.length;

  bool get _allCategoriesSelected =>
      _selectedCategories.length == _allCategoryIds.length &&
      _allCategoryIds.isNotEmpty;

  bool get _allVisibleReportsSelected {
    final List<ModuleReportingReport> visible = _visibleReports;
    if (visible.isEmpty) {
      return false;
    }
    return visible.every(
      (ModuleReportingReport report) => _selectedReports.contains(report.id),
    );
  }

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialValue);
  }

  void _hydrate(AppSearchBarFilterValue value) {
    _dateFrom = value.dateFrom;
    _dateTo = value.dateTo;
    _dateRangeError = null;

    final Set<String> kinds = value.optionsFor(
      ModuleReportingFilterKeys.contentKind,
    );
    if (kinds.contains(ModuleReportingFilterKeys.noneSentinel)) {
      _selectedKinds = <String>{};
    } else {
      _selectedKinds = kinds.isEmpty
          ? ModuleReportingContentKind.values
                .map((ModuleReportingContentKind kind) => kind.name)
                .toSet()
          : Set<String>.of(kinds);
    }

    final Set<String> categories = value.optionsFor(
      ModuleReportingFilterKeys.category,
    );
    if (categories.contains(ModuleReportingFilterKeys.noneSentinel)) {
      _selectedCategories = <String>{};
    } else {
      _selectedCategories = categories.isEmpty
          ? _allCategoryIds.toSet()
          : categories.intersection(_allCategoryIds.toSet());
    }

    final Set<String> reports = value.optionsFor(
      ModuleReportingFilterKeys.subcategory,
    );
    final Set<String> visibleIds = _visibleReports
        .map((ModuleReportingReport report) => report.id)
        .toSet();
    if (reports.contains(ModuleReportingFilterKeys.noneSentinel)) {
      _selectedReports = <String>{};
    } else {
      _selectedReports = reports.isEmpty
          ? Set<String>.of(visibleIds)
          : reports.intersection(visibleIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canInteract = !_isApplying;

    return AppDialog(
      title: Text(_labels.advancedFiltersTitle),
      icon: const Icon(Icons.filter_alt_outlined),
      scrollable: true,
      maxWidth: 760,
      closeEnabled: canInteract,
      content: AbsorbPointer(
        absorbing: !canInteract,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _labels.dateRangeLabel,
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: theme.spacing.sm),
            AppResponsiveFieldRow(
              children: <Widget>[
                AppDateField(
                  value: _dateFrom,
                  labelText: _labels.dateFromLabel,
                  pickerButtonLabel: _labels.datePickerLabel,
                  invalidDateMessage: _labels.invalidDateMessage,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (DateTime? value) {
                    setState(() {
                      _dateFrom = value;
                      _dateRangeError = null;
                    });
                  },
                ),
                AppDateField(
                  value: _dateTo,
                  labelText: _labels.dateToLabel,
                  pickerButtonLabel: _labels.datePickerLabel,
                  invalidDateMessage: _labels.invalidDateMessage,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (DateTime? value) {
                    setState(() {
                      _dateTo = value;
                      _dateRangeError = null;
                    });
                  },
                ),
              ],
            ),
            if (_dateRangeError != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                _dateRangeError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            AppMutedText(_labels.dateFilterHint),
            SizedBox(height: theme.spacing.md),
            AppCollapsibleSection(
              title: _labels.contentKindFilterLabel,
              titleIcon: Icons.category_outlined,
              child: _FilterCheckboxSection(
                allLabel: _labels.allLabel,
                allSelected: _allKindsSelected,
                onAllChanged: (bool? checked) {
                  setState(() {
                    if (checked ?? false) {
                      _selectedKinds = ModuleReportingContentKind.values
                          .map((ModuleReportingContentKind kind) => kind.name)
                          .toSet();
                    } else {
                      _selectedKinds = <String>{};
                    }
                  });
                },
                children: <Widget>[
                  _FilterCheckTile(
                    selected: _selectedKinds.contains(
                      ModuleReportingContentKind.table.name,
                    ),
                    label: _labels.contentKindTable,
                    icon: Icons.table_chart_outlined,
                    onChanged: (bool selected) {
                      setState(() {
                        _toggleValue(
                          _selectedKinds,
                          ModuleReportingContentKind.table.name,
                          selected,
                        );
                      });
                    },
                  ),
                  _FilterCheckTile(
                    selected: _selectedKinds.contains(
                      ModuleReportingContentKind.chart.name,
                    ),
                    label: _labels.contentKindChart,
                    icon: Icons.bar_chart_outlined,
                    onChanged: (bool selected) {
                      setState(() {
                        _toggleValue(
                          _selectedKinds,
                          ModuleReportingContentKind.chart.name,
                          selected,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.spacing.md),
            AppCollapsibleSection(
              title: _labels.categoryFilterLabel,
              titleIcon: Icons.folder_outlined,
              child: _FilterCheckboxSection(
                allLabel: _labels.allLabel,
                allSelected: _allCategoriesSelected,
                onAllChanged: (bool? checked) {
                  setState(() {
                    if (checked ?? false) {
                      _selectedCategories = _allCategoryIds.toSet();
                      _selectedReports = _allReports
                          .map(
                            (ModuleReportingReport report) => report.id,
                          )
                          .toSet();
                    } else {
                      _selectedCategories = <String>{};
                      _selectedReports = <String>{};
                    }
                  });
                },
                children: <Widget>[
                  for (final ModuleReportingCategory category in widget.catalog)
                    _FilterCheckTile(
                      selected: _selectedCategories.contains(category.id),
                      label: _labels.categoryTitle(category.id),
                      icon: category.icon,
                      onChanged: (bool selected) {
                        setState(() {
                          _toggleValue(
                            _selectedCategories,
                            category.id,
                            selected,
                          );
                          final Set<String> reportIds = category.reports
                              .map(
                                (ModuleReportingReport report) => report.id,
                              )
                              .toSet();
                          if (selected) {
                            _selectedReports.addAll(reportIds);
                          } else {
                            _selectedReports.removeWhere(reportIds.contains);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            SizedBox(height: theme.spacing.md),
            AppCollapsibleSection(
              title: _labels.subcategoryFilterLabel,
              titleIcon: Icons.description_outlined,
              child: _selectedCategories.isEmpty
                  ? AppMutedText(_labels.selectCategoryHint)
                  : _FilterCheckboxSection(
                      allLabel: _labels.allLabel,
                      allSelected: _allVisibleReportsSelected,
                      onAllChanged: (bool? checked) {
                        setState(() {
                          final Set<String> visibleIds = _visibleReports
                              .map(
                                (ModuleReportingReport report) => report.id,
                              )
                              .toSet();
                          if (checked ?? false) {
                            _selectedReports = <String>{
                              ..._selectedReports,
                              ...visibleIds,
                            };
                          } else {
                            _selectedReports.removeWhere(visibleIds.contains);
                          }
                        });
                      },
                      children: <Widget>[
                        for (final ModuleReportingReport report
                            in _visibleReports)
                          _FilterCheckTile(
                            selected: _selectedReports.contains(report.id),
                            label: report.label,
                            icon:
                                report.contentKind ==
                                    ModuleReportingContentKind.chart
                                ? Icons.bar_chart_outlined
                                : Icons.description_outlined,
                            onChanged: (bool selected) {
                              setState(() {
                                _toggleValue(
                                  _selectedReports,
                                  report.id,
                                  selected,
                                );
                              });
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: _labels.clearFiltersAction,
          leadingIcon: Icons.filter_alt_off_outlined,
          enabled: canInteract,
          onPressed: canInteract
              ? () {
                  setState(() => _hydrate(AppSearchBarFilterValue.empty));
                }
              : null,
        ),
        AppButton.primary(
          label: _labels.applyFiltersAction,
          leadingIcon: Icons.check,
          enabled: canInteract,
          isLoading: _isApplying,
          onPressed: canInteract ? () => unawaited(_apply()) : null,
        ),
        AppButton.close(
          label: _labels.closeAction,
          enabled: canInteract,
          onPressed: canInteract
              ? () => Navigator.of(context).pop()
              : null,
        ),
      ],
    );
  }

  void _toggleValue(Set<String> values, String value, bool selected) {
    if (selected) {
      values.add(value);
    } else {
      values.remove(value);
    }
  }

  Future<void> _apply() async {
    if (_dateFrom != null || _dateTo != null) {
      if (!appSearchBarDateRangeIsValid(_dateFrom, _dateTo)) {
        setState(() => _dateRangeError = _labels.invalidDateMessage);
        return;
      }
    }

    setState(() => _isApplying = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }

    final Set<String> kindsForFilter = _selectedKinds.isEmpty
        ? const <String>{ModuleReportingFilterKeys.noneSentinel}
        : (_allKindsSelected
              ? const <String>{}
              : Set<String>.of(_selectedKinds));
    final Set<String> categoriesForFilter = _selectedCategories.isEmpty
        ? const <String>{ModuleReportingFilterKeys.noneSentinel}
        : (_allCategoriesSelected
              ? const <String>{}
              : Set<String>.of(_selectedCategories));
    final Set<String> visibleIds = _visibleReports
        .map((ModuleReportingReport report) => report.id)
        .toSet();
    final Set<String> selectedVisibleReports =
        _selectedReports.intersection(visibleIds);
    final Set<String> reportsForFilter;
    if (_selectedCategories.isEmpty) {
      reportsForFilter = const <String>{};
    } else if (_allVisibleReportsSelected) {
      reportsForFilter = const <String>{};
    } else if (selectedVisibleReports.isEmpty) {
      reportsForFilter = const <String>{ModuleReportingFilterKeys.noneSentinel};
    } else {
      reportsForFilter = selectedVisibleReports;
    }

    // Empty date fields mean no date filter is applied.
    final AppSearchBarFilterValue next = AppSearchBarFilterValue(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      selections: <String, Set<String>>{
        if (kindsForFilter.isNotEmpty)
          ModuleReportingFilterKeys.contentKind: kindsForFilter,
        if (categoriesForFilter.isNotEmpty)
          ModuleReportingFilterKeys.category: categoriesForFilter,
        if (reportsForFilter.isNotEmpty)
          ModuleReportingFilterKeys.subcategory: reportsForFilter,
      },
    );

    widget.onApply(next);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _FilterCheckboxSection extends StatelessWidget {
  const _FilterCheckboxSection({
    required this.allLabel,
    required this.allSelected,
    required this.onAllChanged,
    required this.children,
  });

  final String allLabel;
  final bool allSelected;
  final ValueChanged<bool?> onAllChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: allSelected,
            onChanged: onAllChanged,
            title: Text(
              allLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        ...children,
      ],
    );
  }
}

class _FilterCheckTile extends StatelessWidget {
  const _FilterCheckTile({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.28)
            : colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: selected
              ? theme.borders.side(tone: AppBorderTone.selected)
              : theme.borders.side(),
        ),
        child: CheckboxListTile(
          dense: true,
          value: selected,
          onChanged: (bool? value) => onChanged(value ?? false),
          secondary: Icon(icon, size: 18),
          title: Text(label),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
    );
  }
}
