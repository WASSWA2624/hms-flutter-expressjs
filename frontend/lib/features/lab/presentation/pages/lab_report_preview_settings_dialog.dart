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
      maxWidth: 560,
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.labDeskSettingsColumnsSection,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          for (final AppListTableColumn<T> column in widget.columns)
            Builder(
              builder: (BuildContext context) {
                final bool isChecked =
                    column.alwaysVisible ||
                    _visibleColumnKeys.contains(column.key);
                final bool canChange =
                    !column.alwaysVisible &&
                    (!isChecked || _visibleColumnKeys.length > 1);
                return CheckboxListTile(
                  value: isChecked,
                  title: Text(column.label),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: canChange
                      ? (bool? value) {
                          setState(() {
                            final Set<String> next = Set<String>.of(
                              _visibleColumnKeys,
                            );
                            if (value ?? false) {
                              next.add(column.key);
                            } else {
                              next.remove(column.key);
                            }
                            _visibleColumnKeys = next;
                          });
                        }
                      : null,
                );
              },
            ),
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.labReportSettingsDisplaySection,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          DropdownButtonFormField<int>(
            initialValue: _settings.decimalPlaces,
            decoration: InputDecoration(
              labelText: l10n.labReportDecimalPlacesLabel,
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
                () => _settings = _settings.copyWith(decimalPlaces: value),
              );
            },
          ),
          SizedBox(height: theme.spacing.xs),
          CheckboxListTile(
            value: _settings.showRangeLabel,
            title: Text(l10n.labReportShowRangeLabelLabel),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (bool? value) {
              setState(
                () => _settings = _settings.copyWith(
                  showRangeLabel: value ?? false,
                ),
              );
            },
          ),
          CheckboxListTile(
            value: _settings.showRangeMethod,
            title: Text(l10n.labReportShowRangeMethodLabel),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (bool? value) {
              setState(
                () => _settings = _settings.copyWith(
                  showRangeMethod: value ?? false,
                ),
              );
            },
          ),
          CheckboxListTile(
            value: _settings.showRangeGender,
            title: Text(l10n.labReportShowRangeGenderLabel),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (bool? value) {
              setState(
                () => _settings = _settings.copyWith(
                  showRangeGender: value ?? false,
                ),
              );
            },
          ),
          CheckboxListTile(
            value: _settings.showRangeAge,
            title: Text(l10n.labReportShowRangeAgeLabel),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (bool? value) {
              setState(
                () => _settings = _settings.copyWith(
                  showRangeAge: value ?? false,
                ),
              );
            },
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.labReportSettingsMetadataSection,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          for (final String key in LabReportMetadataKeys.all)
            CheckboxListTile(
              value: _settings.showsMetadata(key),
              title: Text(_metadataLabel(l10n, key)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (bool? value) {
                setState(() {
                  final Set<String> next = Set<String>.of(_settings.metadataKeys);
                  if (value ?? false) {
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
        AppButton.tertiary(
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
