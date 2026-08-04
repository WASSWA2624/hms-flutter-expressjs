import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Snapshot of pharmacy medication-instructions print filters.
@immutable
final class PharmacyPrintInstructionsOptions {
  const PharmacyPrintInstructionsOptions({
    required this.selectedItemIds,
    required this.hideZeroQuantity,
    required this.hidePartiallyDispensed,
    required this.includeHistory,
    required this.selectedHistoryIds,
  });

  final Set<String> selectedItemIds;
  final bool hideZeroQuantity;
  final bool hidePartiallyDispensed;
  final bool includeHistory;
  final Set<String> selectedHistoryIds;
}

enum _PrintFilterOption { hideZero, hidePartial, includeHistory }

/// Mutable print-option state for live medication-instructions preview rebuilds.
final class PharmacyPrintOptionsController extends ChangeNotifier {
  PharmacyPrintOptionsController(this.workflow) {
    _selectedItemIds = items.map((PharmacyOrderItem item) => item.id).toSet();
    _selectedHistoryIds =
        history.map((PharmacyTimelineItem item) => item.id).toSet();
  }

  final PharmacyOrderWorkflow workflow;

  late final Set<String> _selectedItemIds;
  late final Set<String> _selectedHistoryIds;
  bool _hideZeroQuantity = true;
  bool _hidePartiallyDispensed = false;
  bool _includeHistory = false;
  bool _selectAllHistory = true;

  List<PharmacyOrderItem> get items {
    return workflow.items.isEmpty ? workflow.order.items : workflow.items;
  }

  List<PharmacyTimelineItem> get history => workflow.timeline;

  Set<String> get selectedItemIds => Set<String>.unmodifiable(_selectedItemIds);

  bool get hideZeroQuantity => _hideZeroQuantity;

  bool get hidePartiallyDispensed => _hidePartiallyDispensed;

  bool get includeHistory => _includeHistory;

  bool get selectAllHistory => _selectAllHistory;

  Set<String> get selectedHistoryIds =>
      Set<String>.unmodifiable(_selectedHistoryIds);

  bool get canPrint => _selectedItemIds.isNotEmpty;

  List<PharmacyTimelineItem> get selectedHistoryItems {
    if (!_includeHistory) {
      return const <PharmacyTimelineItem>[];
    }
    return history
        .where(
          (PharmacyTimelineItem item) => _selectedHistoryIds.contains(item.id),
        )
        .toList(growable: false);
  }

  PharmacyPrintInstructionsOptions get snapshot {
    return PharmacyPrintInstructionsOptions(
      selectedItemIds: selectedItemIds,
      hideZeroQuantity: _hideZeroQuantity,
      hidePartiallyDispensed: _hidePartiallyDispensed,
      includeHistory: _includeHistory,
      selectedHistoryIds:
          _includeHistory ? selectedHistoryIds : const <String>{},
    );
  }

  Set<Object> get selectedFilterIds => <Object>{
    if (_hideZeroQuantity) _PrintFilterOption.hideZero,
    if (_hidePartiallyDispensed) _PrintFilterOption.hidePartial,
    if (_includeHistory) _PrintFilterOption.includeHistory,
  };

  void setFilterSelection(Set<Object> selected) {
    final bool nextHideZero = selected.contains(_PrintFilterOption.hideZero);
    final bool nextHidePartial = selected.contains(
      _PrintFilterOption.hidePartial,
    );
    final bool nextIncludeHistory = selected.contains(
      _PrintFilterOption.includeHistory,
    );
    if (nextHideZero == _hideZeroQuantity &&
        nextHidePartial == _hidePartiallyDispensed &&
        nextIncludeHistory == _includeHistory) {
      return;
    }
    _hideZeroQuantity = nextHideZero;
    _hidePartiallyDispensed = nextHidePartial;
    _includeHistory = nextIncludeHistory;
    notifyListeners();
  }

  void setItemSelected(String itemId, bool selected) {
    if (selected) {
      _selectedItemIds.add(itemId);
    } else {
      _selectedItemIds.remove(itemId);
    }
    notifyListeners();
  }

  void setHideZeroQuantity(bool value) {
    if (_hideZeroQuantity == value) {
      return;
    }
    _hideZeroQuantity = value;
    notifyListeners();
  }

  void setHidePartiallyDispensed(bool value) {
    if (_hidePartiallyDispensed == value) {
      return;
    }
    _hidePartiallyDispensed = value;
    notifyListeners();
  }

  void setIncludeHistory(bool value) {
    if (_includeHistory == value) {
      return;
    }
    _includeHistory = value;
    notifyListeners();
  }

  void setSelectAllHistory(bool value) {
    _selectAllHistory = value;
    if (value) {
      _selectedHistoryIds
        ..clear()
        ..addAll(history.map((PharmacyTimelineItem item) => item.id));
    } else {
      _selectedHistoryIds.clear();
    }
    notifyListeners();
  }

  void setHistorySelected(String historyId, bool selected) {
    _selectAllHistory = false;
    if (selected) {
      _selectedHistoryIds.add(historyId);
    } else {
      _selectedHistoryIds.remove(historyId);
    }
    notifyListeners();
  }

  void selectAllItems() {
    _selectedItemIds
      ..clear()
      ..addAll(items.map((PharmacyOrderItem item) => item.id));
    notifyListeners();
  }

  void clearAllItems() {
    _selectedItemIds.clear();
    notifyListeners();
  }
}

/// Collapsible print-options section for the medication-instructions preview.
class PharmacyPrintOptionsSection extends StatelessWidget {
  const PharmacyPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final PharmacyPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final int selectedCount = controller.selectedItemIds.length;
        final int totalCount = controller.items.length;

        return AppFormSection(
          title: l10n.pharmacyPrintOptionsSectionLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: _PrintFilterOption.hideZero,
                  title: l10n.pharmacyPrintHideZeroQuantityLabel,
                  icon: Icons.filter_alt_outlined,
                ),
                AppReportSectionData(
                  id: _PrintFilterOption.hidePartial,
                  title: l10n.pharmacyPrintHidePartialLabel,
                  icon: Icons.incomplete_circle_outlined,
                ),
                AppReportSectionData(
                  id: _PrintFilterOption.includeHistory,
                  title: l10n.pharmacyPrintIncludeHistoryLabel,
                  icon: Icons.history_outlined,
                ),
              ],
              selectedIds: controller.selectedFilterIds,
              onSelectionChanged: controller.setFilterSelection,
            ),
            SizedBox(height: theme.spacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.pharmacyPrintSelectMedicationsLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$selectedCount / $totalCount',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (totalCount > 1) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: selectedCount == totalCount
                      ? controller.clearAllItems
                      : controller.selectAllItems,
                  child: Text(
                    selectedCount == totalCount
                        ? l10n.commonClearActionLabel
                        : l10n.commonSelectAllActionLabel,
                  ),
                ),
              ),
            ],
            SizedBox(height: theme.spacing.sm),
            for (var index = 0; index < controller.items.length; index++) ...<
              Widget
            >[
              if (index > 0) SizedBox(height: theme.spacing.xs),
              PharmacyPrintSelectableTile(
                selected: controller.selectedItemIds.contains(
                  controller.items[index].id,
                ),
                icon: Icons.medication_outlined,
                title: controller.items[index].medicationLabel,
                subtitle: controller.items[index].simplifiedDoseLine,
                meta: pharmacyOrderItemQuantityLabel(
                  controller.items[index],
                  l10n: context.l10n,
                ),
                onChanged: (bool selected) {
                  controller.setItemSelected(
                    controller.items[index].id,
                    selected,
                  );
                },
              ),
            ],
            if (controller.includeHistory) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.pharmacyPrintSelectHistoryLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (controller.history.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        final bool allSelected =
                            controller.selectedHistoryIds.length ==
                            controller.history.length;
                        controller.setSelectAllHistory(!allSelected);
                      },
                      child: Text(
                        controller.selectedHistoryIds.length ==
                                controller.history.length
                            ? l10n.commonClearActionLabel
                            : l10n.pharmacyPrintSelectAllHistoryLabel,
                      ),
                    ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              if (controller.history.isEmpty)
                Text(
                  l10n.pharmacyDispenseHistoryEmptyBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                for (
                  var index = 0;
                  index < controller.history.length;
                  index++
                ) ...<Widget>[
                  if (index > 0) SizedBox(height: theme.spacing.xs),
                  PharmacyPrintSelectableTile(
                    selected: controller.selectedHistoryIds.contains(
                      controller.history[index].id,
                    ),
                    icon: Icons.event_note_outlined,
                    title: pharmacyTimelineEventLabel(
                      context,
                      controller.history[index],
                    ),
                    onChanged: (bool selected) {
                      controller.setHistorySelected(
                        controller.history[index].id,
                        selected,
                      );
                    },
                  ),
                ],
            ],
          ],
        );
      },
    );
  }
}

/// Bordered checkbox tile aligned with facility print-section chrome.
class PharmacyPrintSelectableTile extends StatelessWidget {
  const PharmacyPrintSelectableTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onChanged,
    this.subtitle,
    this.meta,
    this.emphasizeTitle = true,
    super.key,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? meta;
  final ValueChanged<bool> onChanged;

  /// When true (default), title uses semibold weight.
  final bool emphasizeTitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? resolvedSubtitle = subtitle?.trim();
    final String? resolvedMeta = meta?.trim();
    final bool hasSubtitle =
        resolvedSubtitle != null && resolvedSubtitle.isNotEmpty;
    final bool hasMeta = resolvedMeta != null && resolvedMeta.isNotEmpty;
    final TextStyle? titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: emphasizeTitle ? FontWeight.w600 : FontWeight.w400,
      height: 1.2,
    );
    final TextStyle? subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.25,
    );
    final TextStyle? metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      fontWeight: emphasizeTitle ? FontWeight.w600 : FontWeight.w400,
      height: 1.2,
    );
    final TextStyle? separatorStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.25,
    );

    return Semantics(
      button: true,
      checked: selected,
      label: <String?>[
        title,
        if (hasSubtitle) resolvedSubtitle,
        if (hasMeta) resolvedMeta,
      ].whereType<String>().join(', '),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!selected),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.28)
                  : colorScheme.surface,
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: theme.spacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Checkbox(
                    value: selected,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (bool? value) => onChanged(value ?? false),
                  ),
                  Icon(
                    icon,
                    size: theme.appTokens.listIconSize * 0.9,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(text: title, style: titleStyle),
                          if (hasSubtitle) ...<InlineSpan>[
                            TextSpan(text: ' · ', style: separatorStyle),
                            TextSpan(
                              text: resolvedSubtitle,
                              style: subtitleStyle,
                            ),
                          ],
                          if (hasMeta) ...<InlineSpan>[
                            TextSpan(text: ' · ', style: separatorStyle),
                            TextSpan(text: resolvedMeta, style: metaStyle),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only bordered info card for pharmacy dialogs and summaries.
class PharmacyInfoCard extends StatelessWidget {
  const PharmacyInfoCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.meta,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? resolvedSubtitle = subtitle?.trim();
    final String? resolvedMeta = meta?.trim();
    final bool hasSubtitle =
        resolvedSubtitle != null && resolvedSubtitle.isNotEmpty;
    final bool hasMeta = resolvedMeta != null && resolvedMeta.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              size: theme.appTokens.listIconSize * 0.9,
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (hasSubtitle) ...<InlineSpan>[
                      TextSpan(
                        text: ' · ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: resolvedSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (hasMeta) ...<InlineSpan>[
                      TextSpan(
                        text: ' · ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: resolvedMeta,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
