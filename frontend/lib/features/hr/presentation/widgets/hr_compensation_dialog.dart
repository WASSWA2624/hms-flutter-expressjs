import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_compensation_line_editor.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> showHrCompensationDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
  List<HrStaffCompensation> history, {
  String? focusPayType,
}) async {
  if (!HrHumanResourcesAtomPermissions.compensation.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => _HrPayAndCompensationDialog(
      staff: staff,
      history: history,
      focusPayType: focusPayType,
    ),
  );
}

Future<void> showHrCompensationDetailDialog(
  BuildContext context,
  HrStaffCompensation compensation, {
  VoidCallback? onEdit,
}) async {
  final AppLocalizations l10n = context.l10n;
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.hrCompensationDetailDialogTitle),
      icon: const Icon(Icons.price_change_outlined),
      content: AppInfoTileGrid(
        emptyValue: l10n.profileUnknownValue,
        items: <AppInfoTileData>[
          AppInfoTileData(
            label: l10n.hrStaffOnboardingPayTypeLabel,
            value: l10n.hrReferenceCompensationPayTypeLabel(
              compensation.payType ?? '',
              fallback: compensation.payType,
            ),
            icon: Icons.payments_outlined,
          ),
          AppInfoTileData(
            label: l10n.hrCompensationBaseRateLabel,
            value: hrJoinDisplay(<String?>[
              compensation.rate?.toString(),
              compensation.currency,
            ]),
            icon: Icons.attach_money,
          ),
          AppInfoTileData(
            label: l10n.hrEffectiveFromLabel,
            value: compensation.effectiveFrom?.toIso8601String(),
            icon: Icons.date_range_outlined,
          ),
          AppInfoTileData(
            label: l10n.hrEffectiveToLabel,
            value: compensation.effectiveTo?.toIso8601String(),
            icon: Icons.event_outlined,
          ),
        ],
      ),
      actions: <Widget>[
        if (onEdit != null)
          AppButton.secondary(
            label: l10n.hrCompensationAddNewRateAction,
            leadingIcon: Icons.add,
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
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

class _PayLineRow {
  const _PayLineRow({
    required this.key,
    required this.payType,
    required this.rate,
    required this.currency,
    required this.effectiveFrom,
    this.payFrequency = 'MONTHLY',
    this.payZone,
    this.effectiveTo,
    this.deductions = const <HrPayrollDeduction>[],
  });

  final String key;
  final String payType;
  final num rate;
  final String currency;
  final String payFrequency;
  final String? payZone;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final List<HrPayrollDeduction> deductions;

  Map<String, Object?> toPayload() {
    final String? zone = payZone?.trim();
    final Map<String, Object?> metadata = <String, Object?>{
      'pay_frequency': payFrequency,
      if (zone != null && zone.isNotEmpty) 'pay_zone': zone,
      if (deductions.isNotEmpty)
        'deductions': deductions
            .map(
              (HrPayrollDeduction row) => <String, Object?>{
                'code': row.code,
                if ((row.label ?? '').trim().isNotEmpty) 'label': row.label,
                'mode': row.mode,
                'value': row.value,
              },
            )
            .toList(growable: false),
    };
    return <String, Object?>{
      'pay_type': payType,
      'rate': rate,
      'currency': currency.trim().toUpperCase(),
      'effective_from': effectiveFrom.toIso8601String(),
      'effective_to': effectiveTo?.toIso8601String(),
      'metadata_json': metadata,
    };
  }
}

class _HrPayAndCompensationDialog extends ConsumerStatefulWidget {
  const _HrPayAndCompensationDialog({
    required this.staff,
    required this.history,
    this.focusPayType,
  });

  final HrStaffProfile staff;
  final List<HrStaffCompensation> history;
  final String? focusPayType;

  @override
  ConsumerState<_HrPayAndCompensationDialog> createState() =>
      _HrPayAndCompensationDialogState();
}

class _HrPayAndCompensationDialogState
    extends ConsumerState<_HrPayAndCompensationDialog> {
  static const String _payTypeFilterKey = 'pay_type';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<_PayLineRow> _columnController =
      AppListTableColumnVisibilityController<_PayLineRow>(
        storageKey: 'hr.pay_compensation.table',
      );

  late List<_PayLineRow> _rows;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue();
  bool _saving = false;
  int _rowSeed = 0;

  @override
  void initState() {
    super.initState();
    _rows = _rowsFromHistory(widget.history);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? focus = widget.focusPayType?.trim().toUpperCase();
      if (focus == null || focus.isEmpty) {
        return;
      }
      final bool exists = _rows.any((_PayLineRow row) => row.payType == focus);
      if (!exists && mounted) {
        unawaited(_openPayLineForm(initialPayType: focus));
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnController.dispose();
    super.dispose();
  }

  List<_PayLineRow> _rowsFromHistory(List<HrStaffCompensation> history) {
    final List<_PayLineRow> rows = <_PayLineRow>[];
    for (final HrStaffCompensation item in history) {
      if (!item.isActive || item.rate == null || item.effectiveFrom == null) {
        continue;
      }
      _rowSeed += 1;
      rows.add(
        _PayLineRow(
          key: item.id.isNotEmpty ? item.id : 'local-$_rowSeed',
          payType: (item.payType ?? 'PER_MONTH').trim().toUpperCase(),
          rate: item.rate!,
          currency: item.currency ?? appDefaultCurrencyCode,
          payFrequency:
              item.payFrequency ??
              hrDefaultPayFrequencyForType(item.payType ?? 'PER_MONTH'),
          payZone: item.payZone,
          effectiveFrom: item.effectiveFrom!,
          effectiveTo: item.effectiveTo,
          deductions: item.deductions,
        ),
      );
    }
    return rows;
  }

  Set<String> get _usedPayTypes =>
      _rows.map((_PayLineRow row) => row.payType).toSet();

  bool get _canAddMore =>
      _usedPayTypes.length < kHrCompensationPayTypeCodes.length;

  Future<void> _persist(List<_PayLineRow> next) async {
    setState(() => _saving = true);
    _PayLineRow? consultation;
    for (final _PayLineRow row in next) {
      if (row.payType == 'PER_CONSULTATION') {
        consultation = row;
        break;
      }
    }
    final Map<String, Object?> payload = <String, Object?>{
      'compensations': next
          .map((_PayLineRow row) => row.toPayload())
          .toList(growable: false),
      // Keep legacy consultation fee catalog fields aligned with the pay line
      // so OPD billing and payroll both use the same rate.
      'consultation_fee': consultation?.rate,
      'consultation_currency': consultation?.currency,
    };
    final AppFailure? failure = await ref
        .read(hrWorkspaceControllerProvider.notifier)
        .updateSelectedStaffProfile(payload);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (failure != null) {
      showHrMutationSnackBar(context, failure);
      return;
    }
    setState(() => _rows = next);
    showHrMutationSnackBar(context, null);
  }

  Future<void> _openPayLineForm({
    _PayLineRow? editing,
    String? initialPayType,
  }) async {
    if (_saving) {
      return;
    }
    if (editing == null && !_canAddMore) {
      return;
    }

    final Set<String> used = Set<String>.from(_usedPayTypes);
    if (editing != null) {
      used.remove(editing.payType);
    }

    final _PayLineRow? result = await showAppDialog<_PayLineRow>(
      context: context,
      builder: (BuildContext dialogContext) => _HrPayLineFormDialog(
        usedPayTypes: used,
        editing: editing,
        initialPayType: initialPayType,
        newKey: 'local-${++_rowSeed}',
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    final List<_PayLineRow> next = List<_PayLineRow>.from(_rows);
    final int index = next.indexWhere((_PayLineRow row) => row.key == result.key);
    if (index >= 0) {
      next[index] = result;
    } else {
      if (next.any((_PayLineRow row) => row.payType == result.payType)) {
        showHrMutationSnackBar(context, AppFailure.validation());
        return;
      }
      next.add(result);
    }
    await _persist(next);
  }

  Future<void> _deletePayLine(_PayLineRow row) async {
    if (_saving) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final String label = l10n.hrReferenceCompensationPayTypeLabel(
      row.payType,
      fallback: row.payType,
    );
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.hrDeletePayLineTitle,
        body: l10n.hrDeletePayLineBody(label),
        highlightedText: label,
        submitLabel: l10n.commonDeleteActionLabel,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async => null,
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final List<_PayLineRow> next = _rows
        .where((_PayLineRow item) => item.key != row.key)
        .toList(growable: false);
    await _persist(next);
  }

  bool _matchesFilters(_PayLineRow row) {
    final String? payType = _filterValue.option(_payTypeFilterKey);
    if (payType != null && payType.isNotEmpty && row.payType != payType) {
      return false;
    }
    return true;
  }

  List<_PayLineRow> get _visibleRows =>
      _rows.where(_matchesFilters).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final bool canWrite = HrHumanResourcesAtomPermissions.compensation.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );

    return AppDialog(
      title: Text(l10n.hrCompensationDialogTitle),
      icon: const Icon(Icons.price_change_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 980,
      content: AppListTable<_PayLineRow>(
        items: _visibleRows,
        isLoading: _saving,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columnVisibilityController: _columnController,
        columnVisibilityStorageKey: 'hr.pay_compensation.table',
        columnWidthStorageKey: 'hr.pay_compensation.table.widths',
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        columnVisibilityTitle: l10n.commonTableSettingsTitle,
        columnVisibilityApplyLabel: l10n.opdApplyFiltersAction,
        columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
        columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
        exportLabel: l10n.commonTableExportActionLabel,
        exportDialogTitle: l10n.commonTableExportDialogTitle,
        exportCancelLabel: l10n.commonCancelActionLabel,
        exportColumnsSectionLabel: l10n.commonTableExportColumnsSectionLabel,
        exportFiltersSectionLabel: l10n.commonTableExportFiltersSectionLabel,
        exportEmptyColumnsMessage: l10n.commonTableExportEmptyColumnsMessage,
        exportEmptyRowsMessage: l10n.commonTableExportEmptyRowsMessage,
        exportSuccessMessage: l10n.commonTableExportSuccessMessage,
        exportFailureMessage: l10n.commonTableExportFailureMessage,
        exportConfig: AppListTableExportConfig<_PayLineRow>(
          fileNameStem: 'staff_pay_compensation',
          dateOf: (_PayLineRow item) => item.effectiveFrom,
          sheetName: l10n.hrCompensationDialogTitle,
        ),
        emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
          title: l10n.hrNoCompensationLabel,
          body: l10n.hrCompensationPayLinesEmptyBody,
        ),
        search: AppListTableSearch<_PayLineRow>(
          controller: _searchController,
          semanticLabel: l10n.hrPayLinesSearchHint,
          hintText: l10n.hrPayLinesSearchHint,
          matcher: (_PayLineRow item, String query) {
            final String needle = query.trim().toLowerCase();
            if (needle.isEmpty) {
              return true;
            }
            final String typeLabel = l10n
                .hrReferenceCompensationPayTypeLabel(
                  item.payType,
                  fallback: item.payType,
                )
                .toLowerCase();
            return typeLabel.contains(needle) ||
                item.payType.toLowerCase().contains(needle) ||
                item.currency.toLowerCase().contains(needle) ||
                item.rate.toString().contains(needle) ||
                (item.payZone ?? '').toLowerCase().contains(needle);
          },
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
          advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.hrClearFiltersAction,
          allFieldsLabel: l10n.opdAllFieldsFilterLabel,
          filterGroups: <AppSearchBarFilterGroup>[
            AppSearchBarFilterGroup(
              key: _payTypeFilterKey,
              label: l10n.hrStaffOnboardingPayTypeLabel,
              allLabel: l10n.opdAllFieldsFilterLabel,
              choices: kHrCompensationPayTypeCodes
                  .map(
                    (String code) => AppSearchBarFilterChoice(
                      value: code,
                      label: l10n.hrReferenceCompensationPayTypeLabel(
                        code,
                        fallback: code,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          filterValue: _filterValue,
          hasActiveFilters:
              (_filterValue.option(_payTypeFilterKey) ?? '').isNotEmpty,
          onFilterChanged: (AppSearchBarFilterValue value) {
            setState(() => _filterValue = value);
          },
          trailingActions: <AppSearchBarAction>[
            if (canWrite)
              AppSearchBarAction(
                label: l10n.hrCompensationAddPayLineAction,
                icon: Icons.add_outlined,
                enabled: !_saving && _canAddMore,
                onPressed: () => unawaited(_openPayLineForm()),
              ),
          ],
        ),
        columns: <AppListTableColumn<_PayLineRow>>[
          AppListTableColumn<_PayLineRow>(
            id: 'pay_type',
            label: l10n.hrStaffOnboardingPayTypeLabel,
            alwaysVisible: true,
            cellBuilder: (_, _PayLineRow item) => Text(
              l10n.hrReferenceCompensationPayTypeLabel(
                item.payType,
                fallback: item.payType,
              ),
            ),
            sortComparator: (_PayLineRow a, _PayLineRow b) =>
                a.payType.compareTo(b.payType),
            exportValue: (_PayLineRow item) =>
                l10n.hrReferenceCompensationPayTypeLabel(
                  item.payType,
                  fallback: item.payType,
                ),
          ),
          AppListTableColumn<_PayLineRow>(
            id: 'rate',
            label: l10n.hrCompensationBaseRateLabel,
            alwaysVisible: true,
            cellBuilder: (_, _PayLineRow item) => Text(
              hrJoinDisplay(<String?>[item.rate.toString(), item.currency]),
            ),
            sortComparator: (_PayLineRow a, _PayLineRow b) =>
                a.rate.compareTo(b.rate),
            exportValue: (_PayLineRow item) =>
                hrJoinDisplay(<String?>[item.rate.toString(), item.currency]),
          ),
          AppListTableColumn<_PayLineRow>(
            id: 'frequency',
            label: l10n.hrCompensationPayFrequencyLabel,
            cellBuilder: (_, _PayLineRow item) {
              return Text(hrCompensationPayFrequencyLabel(l10n, item.payFrequency));
            },
            exportValue: (_PayLineRow item) =>
                hrCompensationPayFrequencyLabel(l10n, item.payFrequency),
          ),
          AppListTableColumn<_PayLineRow>(
            id: 'pay_zone',
            label: l10n.hrCompensationPayZoneLabel,
            cellBuilder: (_, _PayLineRow item) => Text(
              (item.payZone ?? '').trim().isEmpty ? '—' : item.payZone!.trim(),
            ),
            exportValue: (_PayLineRow item) => (item.payZone ?? '').trim(),
          ),
          AppListTableColumn<_PayLineRow>(
            id: 'effective_from',
            label: l10n.hrEffectiveFromLabel,
            cellBuilder: (_, _PayLineRow item) =>
                Text(AppFormatters.shortDate(item.effectiveFrom, locale)),
            sortComparator: (_PayLineRow a, _PayLineRow b) =>
                a.effectiveFrom.compareTo(b.effectiveFrom),
            exportValue: (_PayLineRow item) =>
                AppFormatters.shortDate(item.effectiveFrom, locale),
          ),
          AppListTableColumn<_PayLineRow>(
            id: 'effective_to',
            label: l10n.hrEffectiveToLabel,
            cellBuilder: (_, _PayLineRow item) => Text(
              item.effectiveTo == null
                  ? l10n.hrDateRangeOngoingLabel
                  : AppFormatters.shortDate(item.effectiveTo!, locale),
            ),
            exportValue: (_PayLineRow item) => item.effectiveTo == null
                ? l10n.hrDateRangeOngoingLabel
                : AppFormatters.shortDate(item.effectiveTo!, locale),
          ),
          AppListTableColumn<_PayLineRow>(
            id: 'actions',
            label: l10n.hrPositionsActionsColumnLabel,
            alwaysVisible: true,
            preferredWidth: 200,
            cellBuilder: (BuildContext context, _PayLineRow item) {
              if (!canWrite) {
                return const SizedBox.shrink();
              }
              final double gap = theme.spacing.xs;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  AppButton.tertiary(
                    leadingIcon: Icons.edit_outlined,
                    label: l10n.commonEditActionLabel,
                    tooltip: l10n.commonEditActionLabel,
                    dense: true,
                    enabled: !_saving,
                    onPressed: _saving
                        ? null
                        : () => unawaited(_openPayLineForm(editing: item)),
                  ),
                  AppButton.tertiary(
                    leadingIcon: Icons.delete_outline,
                    label: l10n.commonDeleteActionLabel,
                    tooltip: l10n.commonDeleteActionLabel,
                    dense: true,
                    color: theme.colorScheme.error,
                    enabled: !_saving,
                    onPressed: _saving
                        ? null
                        : () => unawaited(_deletePayLine(item)),
                  ),
                ],
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, _PayLineRow item) {
          return AppListTableMobileItem(
            title: l10n.hrReferenceCompensationPayTypeLabel(
              item.payType,
              fallback: item.payType,
            ),
            caption: hrJoinDisplay(<String?>[
              item.rate.toString(),
              item.currency,
            ]),
            trailing: canWrite
                ? IconButton(
                    tooltip: l10n.commonEditActionLabel,
                    onPressed: _saving
                        ? null
                        : () => unawaited(_openPayLineForm(editing: item)),
                    icon: const Icon(Icons.edit_outlined),
                  )
                : null,
          );
        },
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _HrPayLineFormDialog extends StatefulWidget {
  const _HrPayLineFormDialog({
    required this.usedPayTypes,
    required this.newKey,
    this.editing,
    this.initialPayType,
  });

  final Set<String> usedPayTypes;
  final String newKey;
  final _PayLineRow? editing;
  final String? initialPayType;

  @override
  State<_HrPayLineFormDialog> createState() => _HrPayLineFormDialogState();
}

class _HrPayLineFormDialogState extends State<_HrPayLineFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final HrCompensationLineData _line;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final _PayLineRow? editing = widget.editing;
    if (editing != null) {
      _line = HrCompensationLineData(
        payType: editing.payType,
        rateController: TextEditingController(text: editing.rate.toString()),
        currency: editing.currency,
        payFrequency: editing.payFrequency,
        payZone: editing.payZone,
        effectiveFrom: editing.effectiveFrom,
        effectiveTo: editing.effectiveTo,
        deductions: editing.deductions,
      );
    } else {
      final String payType =
          widget.initialPayType ??
          kHrCompensationPayTypeCodes.firstWhere(
            (String code) => !widget.usedPayTypes.contains(code),
            orElse: () => kHrCompensationPayTypeCodes.first,
          );
      _line = HrCompensationLineData(
        payType: payType,
        rateController: TextEditingController(),
        effectiveFrom: DateTime.now(),
      );
    }
  }

  @override
  void dispose() {
    _line.rateController.dispose();
    super.dispose();
  }

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final num? rate = num.tryParse(
      normalizeCurrencyAmount(_line.rateController.text),
    );
    final DateTime? from = _line.effectiveFrom;
    if (rate == null || from == null) {
      return;
    }
    if (widget.usedPayTypes.contains(_line.payType) &&
        widget.editing?.payType != _line.payType) {
      return;
    }
    Navigator.of(context).pop(
      _PayLineRow(
        key: widget.editing?.key ?? widget.newKey,
        payType: _line.payType,
        rate: rate,
        currency: _line.currency,
        payFrequency: _line.payFrequency,
        payZone: _line.payZone,
        effectiveFrom: from,
        effectiveTo: _line.effectiveTo,
        deductions: _line.deductions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(
        _isEdit ? l10n.hrEditPayLineDialogTitle : l10n.hrAddPayLineDialogTitle,
      ),
      icon: const Icon(Icons.price_change_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 920,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          description: l10n.hrAddPayLineFormHint,
          children: <Widget>[
            HrCompensationLineEditor(
              line: _line,
              usedPayTypes: widget.usedPayTypes,
              showHeader: false,
              onChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: _isEdit
              ? l10n.commonSaveActionLabel
              : l10n.hrCompensationAddPayLineAction,
          leadingIcon: _isEdit ? Icons.save_outlined : Icons.add,
          onPressed: _submit,
        ),
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
