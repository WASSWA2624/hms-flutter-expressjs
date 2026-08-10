import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
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
  if (!HrHumanResourcesAtomPermissions.compensation.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_HrCompensationFormState> fieldsKey =
      GlobalKey<_HrCompensationFormState>();
  final bool hasExisting = staffHasPayOrCompensation(staff, history);
  final String actionLabel = hrPayAndCompensationActionLabel(
    l10n,
    hasExisting: hasExisting,
  );

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrCompensationDialogTitle),
    icon: const Icon(Icons.price_change_outlined),
    submitLabel: actionLabel,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: hasExisting ? Icons.save_outlined : Icons.add,
    maxWidth: 760,
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

class _HrCompensationFormState extends ConsumerState<_HrCompensationForm> {
  final List<HrCompensationLineData> _lines = <HrCompensationLineData>[];

  @override
  void initState() {
    super.initState();
    _hydrateLines();
    final String? focus = widget.focusPayType?.trim().toUpperCase();
    if (focus != null && focus.isNotEmpty) {
      final bool hasLine = _lines.any(
        (HrCompensationLineData line) =>
            !line.removed && line.payType == focus,
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
          deductions: row.deductions,
        ),
      );
    }
  }

  void _addLine({String? defaultPayType}) {
    final Set<String> used = _usedPayTypes;
    final String payType =
        defaultPayType ??
        kHrCompensationPayTypeCodes.firstWhere(
          (String code) => !used.contains(code),
          orElse: () => kHrCompensationPayTypeCodes.first,
        );
    setState(() {
      _lines.add(
        HrCompensationLineData(
          payType: payType,
          rateController: TextEditingController(),
          effectiveFrom: DateTime.now(),
        ),
      );
    });
  }

  Set<String> get _usedPayTypes => _lines
      .where((HrCompensationLineData line) => !line.removed)
      .map((HrCompensationLineData line) => line.payType)
      .toSet();

  List<HrCompensationLineData> get _visibleLines => _lines
      .where((HrCompensationLineData line) => !line.removed)
      .toList(growable: false);

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
    for (final HrCompensationLineData line in _lines) {
      line.rateController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<HrStaffCompensation> records = widget.history;
    final bool canAddMore =
        _usedPayTypes.length < kHrCompensationPayTypeCodes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCollapsibleSection(
          title: l10n.hrCompensationCurrentSectionTitle,
          titleIcon: Icons.info_outline,
          child: records.isEmpty && widget.staff.consultationFee == null
              ? Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacing.md,
                    theme.spacing.md,
                    theme.spacing.md,
                    0,
                  ),
                  child: Text(l10n.hrCompensationCurrentEmptyBody),
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacing.md,
                    theme.spacing.sm,
                    theme.spacing.md,
                    theme.spacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (widget.staff.consultationFee != null) ...<Widget>[
                        AppInfoSheetGrid(
                          emptyValue: l10n.profileUnknownValue,
                          spacing: theme.spacing.lg,
                          runSpacing: theme.spacing.sm,
                          layout: AppInfoSheetLayout.inline,
                          items: <AppInfoSheetItem>[
                            AppInfoSheetItem(
                              label: l10n.hrConsultationFeeLabel,
                              value: hrJoinDisplay(<String?>[
                                widget.staff.consultationFee?.toString(),
                                widget.staff.consultationCurrency,
                              ]),
                            ),
                          ],
                        ),
                        if (records.isNotEmpty)
                          SizedBox(height: theme.spacing.md),
                      ],
                      for (int index = 0; index < records.length; index++) ...<
                        Widget
                      >[
                        if (index > 0) SizedBox(height: theme.spacing.md),
                        _CompensationRecordOverview(
                          compensation: records[index],
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        SizedBox(height: theme.spacing.lg),
        AppFormSection(
          title: l10n.hrCompensationPayLinesSectionTitle,
          description: l10n.hrCompensationPayLinesSectionHint,
          children: <Widget>[
            if (_visibleLines.isEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.sm),
                child: Text(l10n.hrCompensationPayLinesEmptyBody),
              ),
            for (final HrCompensationLineData line in _visibleLines)
              HrCompensationLineEditor(
                line: line,
                usedPayTypes: _usedPayTypes,
                onChanged: () => setState(() {}),
                onRemove: () {
                  setState(() {
                    line.removed = true;
                  });
                },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton.secondary(
                label: l10n.hrCompensationAddPayLineAction,
                leadingIcon: Icons.add,
                onPressed: canAddMore ? () => _addLine() : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompensationRecordOverview extends StatelessWidget {
  const _CompensationRecordOverview({required this.compensation});

  final HrStaffCompensation compensation;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  hrCompensationRowTitle(context, compensation),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label: compensation.isActive
                      ? l10n.hrCompensationActiveStatusLabel
                      : l10n.hrCompensationEndedStatusLabel,
                  tone: compensation.isActive
                      ? AppWorkspaceStatusTone.success
                      : AppWorkspaceStatusTone.neutral,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          AppInfoSheetGrid(
            emptyValue: l10n.profileUnknownValue,
            spacing: theme.spacing.lg,
            runSpacing: theme.spacing.sm,
            layout: AppInfoSheetLayout.inline,
            items: <AppInfoSheetItem>[
              AppInfoSheetItem(
                label: l10n.hrStaffOnboardingPayTypeLabel,
                value: l10n.hrReferenceCompensationPayTypeLabel(
                  compensation.payType ?? '',
                  fallback: compensation.payType,
                ),
              ),
              AppInfoSheetItem(
                label: l10n.hrCompensationBaseRateLabel,
                value: hrJoinDisplay(<String?>[
                  compensation.rate?.toString(),
                  compensation.currency,
                ]),
              ),
              AppInfoSheetItem(
                label: l10n.hrPeriodColumnLabel,
                value: hrDateRange(
                  context,
                  compensation.effectiveFrom,
                  compensation.effectiveTo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
