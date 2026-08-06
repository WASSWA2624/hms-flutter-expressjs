import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_report_preview_preferences.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of applying lab report preview settings (columns + display prefs).
final class LabReportPreviewSettingsResult {
  const LabReportPreviewSettingsResult({
    required this.visibleColumnKeys,
    required this.settings,
  });

  final Set<String> visibleColumnKeys;
  final LabReportPreviewSettings settings;
}

Future<LabReportPreviewSettingsResult?> showLabReportPreviewSettingsDialog<T>({
  required BuildContext context,
  required List<AppListTableColumn<T>> columns,
  required Set<String> visibleColumnKeys,
  required Set<String> defaultColumnKeys,
  required LabReportPreviewSettings settings,
  required SharedPreferences preferences,
}) {
  final AppLocalizations l10n = context.l10n;
  return showAppDialog<LabReportPreviewSettingsResult>(
    context: context,
    builder: (_) => _LabReportPreviewSettingsDialog<T>(
      columns: columns,
      visibleColumnKeys: visibleColumnKeys,
      defaultColumnKeys: defaultColumnKeys,
      settings: settings,
      preferences: preferences,
      title: l10n.labReportSettingsTitle,
      applyLabel: l10n.labReportApplySettingsAction,
      resetLabel: l10n.labReportResetSettingsAction,
      closeLabel: l10n.commonCloseActionLabel,
    ),
  );
}

class _LabReportPreviewSettingsDialog<T> extends StatefulWidget {
  const _LabReportPreviewSettingsDialog({
    required this.columns,
    required this.visibleColumnKeys,
    required this.defaultColumnKeys,
    required this.settings,
    required this.preferences,
    required this.title,
    required this.applyLabel,
    required this.resetLabel,
    required this.closeLabel,
  });

  final List<AppListTableColumn<T>> columns;
  final Set<String> visibleColumnKeys;
  final Set<String> defaultColumnKeys;
  final LabReportPreviewSettings settings;
  final SharedPreferences preferences;
  final String title;
  final String applyLabel;
  final String resetLabel;
  final String closeLabel;

  @override
  State<_LabReportPreviewSettingsDialog<T>> createState() =>
      _LabReportPreviewSettingsDialogState<T>();
}

class _LabReportPreviewSettingsDialogState<T>
    extends State<_LabReportPreviewSettingsDialog<T>> {
  static const double _sideBySideBreakpoint = 640;
  static const double _threeColumnBreakpoint = 900;
  static const double _decimalPlacesFieldWidth = 168;

  late Set<String> _visibleColumnKeys;
  late LabReportPreviewSettings _settings;

  @override
  void initState() {
    super.initState();
    _visibleColumnKeys = Set<String>.of(widget.visibleColumnKeys);
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.settings_outlined),
      maxWidth: 760,
      scrollable: true,
      content: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool sideBySide =
              constraints.maxWidth >= _sideBySideBreakpoint;
          final Widget columnsSection = _SettingsSection(
            title: l10n.labDeskSettingsColumnsSection,
            child: _CheckboxGrid(
              columnCount: _gridColumns(constraints.maxWidth, sideBySide),
              children: <Widget>[
                for (final AppListTableColumn<T> column in widget.columns)
                  _columnToggle(column),
              ],
            ),
          );
          final Widget displaySection = _SettingsSection(
            title: l10n.labReportSettingsDisplaySection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    width: _decimalPlacesFieldWidth,
                    child: DropdownButtonFormField<int>(
                      initialValue: _settings.decimalPlaces,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.labReportDecimalPlacesLabel,
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<int>>[
                        for (final int places
                            in LabReportPreviewSettings.decimalPlaceChoices)
                          DropdownMenuItem<int>(
                            value: places,
                            child: Text('$places'),
                          ),
                      ],
                      onChanged: (int? value) {
                        if (value == null) {
                          return;
                        }
                        setState(
                          () => _settings = _settings.copyWith(
                            decimalPlaces: value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: theme.spacing.sm),
                _CheckboxGrid(
                  columnCount: _gridColumns(constraints.maxWidth, sideBySide),
                  children: <Widget>[
                    _settingToggle(
                      value: _settings.showRangeLabel,
                      label: l10n.labReportShowRangeLabelLabel,
                      onChanged: (bool value) {
                        setState(
                          () => _settings = _settings.copyWith(
                            showRangeLabel: value,
                          ),
                        );
                      },
                    ),
                    _settingToggle(
                      value: _settings.showRangeMethod,
                      label: l10n.labReportShowRangeMethodLabel,
                      onChanged: (bool value) {
                        setState(
                          () => _settings = _settings.copyWith(
                            showRangeMethod: value,
                          ),
                        );
                      },
                    ),
                    _settingToggle(
                      value: _settings.showRangeGender,
                      label: l10n.labReportShowRangeGenderLabel,
                      onChanged: (bool value) {
                        setState(
                          () => _settings = _settings.copyWith(
                            showRangeGender: value,
                          ),
                        );
                      },
                    ),
                    _settingToggle(
                      value: _settings.showRangeAge,
                      label: l10n.labReportShowRangeAgeLabel,
                      onChanged: (bool value) {
                        setState(
                          () => _settings = _settings.copyWith(
                            showRangeAge: value,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (sideBySide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: columnsSection),
                    SizedBox(width: theme.spacing.md),
                    Expanded(child: displaySection),
                  ],
                )
              else ...<Widget>[
                columnsSection,
                SizedBox(height: theme.spacing.md),
                displaySection,
              ],
              SizedBox(height: theme.spacing.md),
              _SettingsSection(
                title: l10n.labReportSettingsMetadataSection,
                child: _CheckboxGrid(
                  columnCount: constraints.maxWidth >= _threeColumnBreakpoint
                      ? 3
                      : constraints.maxWidth >= _sideBySideBreakpoint
                      ? 2
                      : 1,
                  children: <Widget>[
                    for (final String key in LabReportMetadataKeys.all)
                      _settingToggle(
                        value: _settings.showsMetadata(key),
                        label: _metadataLabel(l10n, key),
                        onChanged: (bool value) {
                          setState(() {
                            final Set<String> next = Set<String>.of(
                              _settings.metadataKeys,
                            );
                            if (value) {
                              next.add(key);
                            } else {
                              next.remove(key);
                            }
                            _settings = _settings.copyWith(metadataKeys: next);
                          });
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: widget.resetLabel,
          onPressed: () {
            setState(() {
              _visibleColumnKeys = Set<String>.of(widget.defaultColumnKeys);
              _settings = LabReportPreviewSettings.defaults;
            });
          },
        ),
        AppButton.close(
          leadingIcon: AppActionIcons.cancel,
          label: widget.closeLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: widget.applyLabel,
          onPressed: () async {
            final LabReportPreviewSettingsResult result =
                LabReportPreviewSettingsResult(
                  visibleColumnKeys: _withAlwaysVisible(_visibleColumnKeys),
                  settings: _settings,
                );
            final NavigatorState navigator = Navigator.of(context);
            await LabReportPreviewPreferences.write(
              widget.preferences,
              result.settings,
            );
            if (!mounted) {
              return;
            }
            navigator.pop(result);
          },
        ),
      ],
    );
  }

  int _gridColumns(double availableWidth, bool sideBySide) {
    if (sideBySide) {
      // Each pane is roughly half width; keep toggles readable.
      return availableWidth >= _threeColumnBreakpoint ? 2 : 1;
    }
    if (availableWidth >= _threeColumnBreakpoint) {
      return 3;
    }
    if (availableWidth >= _sideBySideBreakpoint) {
      return 2;
    }
    return 1;
  }

  Widget _columnToggle(AppListTableColumn<T> column) {
    final bool isChecked =
        column.alwaysVisible || _visibleColumnKeys.contains(column.key);
    final bool canChange =
        !column.alwaysVisible &&
        (!isChecked || _visibleColumnKeys.length > 1);
    return _settingToggle(
      value: isChecked,
      label: column.label,
      onChanged: canChange
          ? (bool value) {
              setState(() {
                final Set<String> next = Set<String>.of(_visibleColumnKeys);
                if (value) {
                  next.add(column.key);
                } else {
                  next.remove(column.key);
                }
                _visibleColumnKeys = next;
              });
            }
          : null,
    );
  }

  Widget _settingToggle({
    required bool value,
    required String label,
    required ValueChanged<bool>? onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      title: Text(label),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: onChanged == null
          ? null
          : (bool? next) => onChanged(next ?? false),
    );
  }

  Set<String> _withAlwaysVisible(Set<String> keys) {
    return <String>{
      ...keys,
      for (final AppListTableColumn<T> column in widget.columns)
        if (column.alwaysVisible) column.key,
    };
  }

  String _metadataLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      LabReportMetadataKeys.patientId => l10n.labPatientIdFieldLabel,
      LabReportMetadataKeys.encounter => l10n.labEncounterFieldLabel,
      LabReportMetadataKeys.orderIds => l10n.labOrderFieldLabel,
      LabReportMetadataKeys.orderStatus => l10n.labOrderStatusFieldLabel,
      LabReportMetadataKeys.orderedAt => l10n.labOrderedAtFieldLabel,
      LabReportMetadataKeys.ordersIncluded => l10n.labOrdersIncludedLabel,
      LabReportMetadataKeys.patientGender => l10n.labReportPatientGenderLabel,
      LabReportMetadataKeys.patientAge => l10n.labReportPatientAgeLabel,
      _ => key,
    };
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCollapsibleSection(
      title: title,
      collapsible: false,
      child: child,
    );
  }
}

class _CheckboxGrid extends StatelessWidget {
  const _CheckboxGrid({required this.columnCount, required this.children});

  final int columnCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int columns = columnCount.clamp(1, 3);
    if (columns == 1 || children.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = theme.spacing.md;
        final double tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
