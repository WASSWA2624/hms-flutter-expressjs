import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_desk_preferences.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of applying lab desk settings (columns + local preferences).
final class LabDeskSettingsResult {
  const LabDeskSettingsResult({
    required this.visibleColumnKeys,
    required this.defaultTab,
    required this.pageSize,
  });

  final Set<String> visibleColumnKeys;
  final LabDeskSection? defaultTab;
  final int pageSize;
}

Future<LabDeskSettingsResult?> showLabDeskSettingsDialog<T>({
  required BuildContext context,
  required List<AppListTableColumn<T>> columns,
  required Set<String> visibleColumnKeys,
  required Set<String> defaultColumnKeys,
  required SharedPreferences preferences,
  required String Function(LabDeskSection section) sectionLabel,
  List<LabDeskSection> allowedDefaultTabs = const <LabDeskSection>[],
}) {
  final AppLocalizations l10n = context.l10n;
  return showAppDialog<LabDeskSettingsResult>(
    context: context,
    builder: (_) => _LabDeskSettingsDialog<T>(
      columns: columns,
      visibleColumnKeys: visibleColumnKeys,
      defaultColumnKeys: defaultColumnKeys,
      preferences: preferences,
      sectionLabel: sectionLabel,
      allowedDefaultTabs: allowedDefaultTabs.isEmpty
          ? LabDeskSection.values
          : allowedDefaultTabs,
      title: l10n.labDeskSettingsTitle,
      applyLabel: l10n.labApplyColumnsAction,
      resetLabel: l10n.labResetColumnsAction,
      closeLabel: l10n.commonCloseActionLabel,
    ),
  );
}

class _LabDeskSettingsDialog<T> extends StatefulWidget {
  const _LabDeskSettingsDialog({
    required this.columns,
    required this.visibleColumnKeys,
    required this.defaultColumnKeys,
    required this.preferences,
    required this.sectionLabel,
    required this.allowedDefaultTabs,
    required this.title,
    required this.applyLabel,
    required this.resetLabel,
    required this.closeLabel,
  });

  final List<AppListTableColumn<T>> columns;
  final Set<String> visibleColumnKeys;
  final Set<String> defaultColumnKeys;
  final SharedPreferences preferences;
  final String Function(LabDeskSection section) sectionLabel;
  final List<LabDeskSection> allowedDefaultTabs;
  final String title;
  final String applyLabel;
  final String resetLabel;
  final String closeLabel;

  @override
  State<_LabDeskSettingsDialog<T>> createState() =>
      _LabDeskSettingsDialogState<T>();
}

class _LabDeskSettingsDialogState<T> extends State<_LabDeskSettingsDialog<T>> {
  late Set<String> _visibleColumnKeys;
  late LabDeskSection? _defaultTab;
  late int _pageSize;

  @override
  void initState() {
    super.initState();
    _visibleColumnKeys = Set<String>.of(widget.visibleColumnKeys);
    _defaultTab = LabDeskPreferences.readDefaultTab(widget.preferences);
    if (_defaultTab != null &&
        !widget.allowedDefaultTabs.contains(_defaultTab)) {
      _defaultTab = null;
    }
    _pageSize = LabDeskPreferences.readPageSize(widget.preferences);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.settings_outlined),
      maxWidth: 520,
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
            l10n.labDeskSettingsPreferencesSection,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          DropdownButtonFormField<LabDeskSection>(
            initialValue: _defaultTab ?? LabDeskSection.collection,
            decoration: InputDecoration(labelText: l10n.labDefaultTabLabel),
            items: <DropdownMenuItem<LabDeskSection>>[
              for (final LabDeskSection section in widget.allowedDefaultTabs)
                DropdownMenuItem<LabDeskSection>(
                  value: section,
                  child: Text(widget.sectionLabel(section)),
                ),
            ],
            onChanged: (LabDeskSection? value) {
              if (value == null) {
                return;
              }
              setState(() => _defaultTab = value);
            },
          ),
          SizedBox(height: theme.spacing.sm),
          DropdownButtonFormField<int>(
            initialValue: _pageSize,
            decoration: InputDecoration(labelText: l10n.labPageSizeLabel),
            items: <DropdownMenuItem<int>>[
              for (final int size in LabDeskPreferences.pageSizeChoices)
                DropdownMenuItem<int>(
                  value: size,
                  child: Text('$size'),
                ),
            ],
            onChanged: (int? value) {
              if (value == null) {
                return;
              }
              setState(() => _pageSize = value);
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
              _defaultTab = LabDeskSection.collection;
              _pageSize = LabDeskPreferences.defaultPageSize;
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
          onPressed: () {
            Navigator.of(context).pop(
              LabDeskSettingsResult(
                visibleColumnKeys: _withAlwaysVisible(_visibleColumnKeys),
                defaultTab: _defaultTab ?? LabDeskSection.collection,
                pageSize: _pageSize,
              ),
            );
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
}
