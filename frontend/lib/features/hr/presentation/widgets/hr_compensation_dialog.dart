import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_compensation_line_editor.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
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
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_HrCompensationFormState> fieldsKey =
      GlobalKey<_HrCompensationFormState>();

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrCompensationDialogTitle),
    icon: const Icon(Icons.price_change_outlined),
    submitLabel: l10n.hrCompensationAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    maxWidth: 720,
    scrollable: true,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return _HrCompensationForm(
            key: fieldsKey,
            staff: staff,
            history: history,
            focusPayType: focusPayType,
          );
        },
    onSubmit: () => controller.updateSelectedStaffProfile(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<void> showHrCompensationDetailDialog(
  BuildContext context,
  HrStaffCompensation compensation,
  VoidCallback onEdit,
) async {
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

class _HrCompensationForm extends ConsumerStatefulWidget {
  const _HrCompensationForm({
    required this.staff,
    required this.history,
    this.focusPayType,
    super.key,
  });

  final HrStaffProfile staff;
  final List<HrStaffCompensation> history;
  final String? focusPayType;

  @override
  ConsumerState<_HrCompensationForm> createState() =>
      _HrCompensationFormState();
}

class _HrCompensationFormState extends ConsumerState<_HrCompensationForm>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<HrCompensationLineData> _lines = <HrCompensationLineData>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _hydrateLines();
    final String? focus = widget.focusPayType?.trim().toUpperCase();
    if (focus != null && focus.isNotEmpty) {
      final bool hasLine = _lines.any(
        (HrCompensationLineData line) => line.payType == focus,
      );
      if (!hasLine) {
        _addLine(defaultPayType: focus);
      }
    }
  }

  void _hydrateLines() {
    final List<HrStaffCompensation> active = widget.history
        .where((HrStaffCompensation row) => row.isActive)
        .toList(growable: false);
    if (active.isEmpty) {
      _addLine();
      return;
    }
    for (final HrStaffCompensation row in active) {
      _lines.add(
        HrCompensationLineData(
          payType: row.payType ?? 'PER_MONTH',
          rateController: TextEditingController(
            text: row.rate?.toString() ?? '',
          ),
          currency: row.currency ?? appDefaultCurrencyCode,
          payFrequency: row.payFrequency ?? 'MONTHLY',
          effectiveFrom: row.effectiveFrom ?? DateTime.now(),
          effectiveTo: row.effectiveTo,
        ),
      );
    }
  }

  void _focusPayStructure({String? payType}) {
    final String? focus = payType?.trim().toUpperCase();
    if (focus != null && focus.isNotEmpty) {
      final bool hasLine = _lines.any(
        (HrCompensationLineData line) => !line.removed && line.payType == focus,
      );
      if (!hasLine) {
        _addLine(defaultPayType: focus);
      }
    }
    _tabController.index = 0;
    setState(() {});
  }

  void _addLine({String? defaultPayType}) {
    final Set<String> used = _lines
        .where((HrCompensationLineData line) => !line.removed)
        .map((HrCompensationLineData line) => line.payType)
        .toSet();
    final String payType =
        defaultPayType ??
        kHrCompensationPayTypeCodes.firstWhere(
          (String code) => !used.contains(code),
          orElse: () => kHrCompensationPayTypeCodes.first,
        );
    _lines.add(
      HrCompensationLineData(
        payType: payType,
        rateController: TextEditingController(),
        effectiveFrom: DateTime.now(),
      ),
    );
  }

  Set<String> get _usedPayTypes => _lines
      .where((HrCompensationLineData line) => !line.removed)
      .map((HrCompensationLineData line) => line.payType)
      .toSet();

  Map<String, Object?> toPayload() {
    final List<Map<String, Object?>> compensations = _lines
        .where((HrCompensationLineData line) => !line.removed)
        .map((HrCompensationLineData line) => line.toPayload())
        .where((Map<String, Object?> row) => row.isNotEmpty)
        .toList(growable: false);
    return <String, Object?>{'compensations': compensations};
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final HrCompensationLineData line in _lines) {
      line.rateController.dispose();
    }
    super.dispose();
  }

  Map<String, List<HrStaffCompensation>> _groupedHistory() {
    final Map<String, List<HrStaffCompensation>> grouped =
        <String, List<HrStaffCompensation>>{};
    for (final HrStaffCompensation row in widget.history) {
      final String key = (row.payType ?? 'UNKNOWN').toUpperCase();
      grouped.putIfAbsent(key, () => <HrStaffCompensation>[]).add(row);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Map<String, List<HrStaffCompensation>> groupedHistory =
        _groupedHistory();
    // Responsive tab body height: fills available space on large screens while
    // staying compact enough to avoid overflow on mobile/tablet. The enclosing
    // dialog is scrollable, so this height is a target rather than a hard limit.
    final double tabBodyHeight = (MediaQuery.sizeOf(context).height * 0.6).clamp(
      260.0,
      460.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TabBar(
          controller: _tabController,
          tabs: <Widget>[
            Tab(text: l10n.hrCompensationPayStructureTabLabel),
            Tab(text: l10n.hrCompensationHistoryTabLabel),
          ],
        ),
        SizedBox(
          height: tabBodyHeight,
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              SingleChildScrollView(
                primary: false,
                padding: EdgeInsets.only(top: theme.spacing.md),
                child: AppFormSection(
                  title: l10n.hrStaffOnboardingCompensationSectionTitle,
                  description: l10n.hrStaffOnboardingCompensationEditHint,
                  children: <Widget>[
                    for (final HrCompensationLineData line in _lines)
                      if (!line.removed)
                        HrCompensationLineEditor(
                          line: line,
                          usedPayTypes: _usedPayTypes,
                          onChanged: () => setState(() {}),
                          onRemove: () {
                            setState(() {
                              line.removed = true;
                              if (_lines.every(
                                (HrCompensationLineData row) => row.removed,
                              )) {
                                _addLine();
                              }
                            });
                          },
                        ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton.secondary(
                        label: l10n.hrCompensationAddPayLineAction,
                        leadingIcon: Icons.add,
                        onPressed:
                            _usedPayTypes.length >=
                                kHrCompensationPayTypeCodes.length
                            ? null
                            : () => setState(() => _addLine()),
                      ),
                    ),
                  ],
                ),
              ),
              ListView(
                primary: false,
                padding: EdgeInsets.only(top: theme.spacing.md),
                children: <Widget>[
                  for (final MapEntry<String, List<HrStaffCompensation>> entry
                      in groupedHistory.entries)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.only(
                            top: theme.spacing.sm,
                            bottom: theme.spacing.xs,
                          ),
                          child: Text(
                            hrCompensationPayTypeLabel(l10n, entry.key),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        for (final HrStaffCompensation item in entry.value)
                          ListTile(
                            title: Text(hrCompensationRowTitle(context, item)),
                            subtitle: Text(
                              hrDateRange(
                                context,
                                item.effectiveFrom,
                                item.effectiveTo,
                              ),
                            ),
                            trailing: AppWorkspaceStatusBadge(
                              status: AppWorkspaceStatus(
                                label: item.isActive
                                    ? l10n.hrCompensationActiveStatusLabel
                                    : l10n.hrCompensationEndedStatusLabel,
                                tone: item.isActive
                                    ? AppWorkspaceStatusTone.success
                                    : AppWorkspaceStatusTone.neutral,
                              ),
                            ),
                            onTap: () => showHrCompensationDetailDialog(
                              context,
                              item,
                              () {
                                if (!mounted) {
                                  return;
                                }
                                _focusPayStructure(payType: item.payType);
                              },
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
