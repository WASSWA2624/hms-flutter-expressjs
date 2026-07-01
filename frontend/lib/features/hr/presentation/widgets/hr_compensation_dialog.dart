import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

enum _CompensationPayType { perConsultation, monthly, daily, hourly, perVisit }

Future<void> showHrCompensationDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
  List<HrStaffCompensation> history,
) async {
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
    maxWidth: 640,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _, [
      AppFailure? failure,
    ]) {
      return _HrCompensationForm(
        key: fieldsKey,
        staff: staff,
        history: history,
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

class _HrCompensationForm extends StatefulWidget {
  const _HrCompensationForm({
    required this.staff,
    required this.history,
    super.key,
  });

  final HrStaffProfile staff;
  final List<HrStaffCompensation> history;

  @override
  State<_HrCompensationForm> createState() => _HrCompensationFormState();
}

class _HrCompensationFormState extends State<_HrCompensationForm>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _rateController;
  _CompensationPayType _payType = _CompensationPayType.monthly;
  String _currency = appDefaultCurrencyCode;
  String _payFrequency = 'MONTHLY';
  DateTime? _effectiveFrom = DateTime.now();
  DateTime? _effectiveTo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _rateController = TextEditingController();
    if (widget.history.isNotEmpty) {
      final HrStaffCompensation current = widget.history.first;
      _rateController.text = current.rate?.toString() ?? '';
      _currency = current.currency ?? appDefaultCurrencyCode;
      _payType = _payTypeFromApi(current.payType);
      _effectiveFrom = current.effectiveFrom ?? DateTime.now();
      _effectiveTo = current.effectiveTo;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  _CompensationPayType _payTypeFromApi(String? value) {
    return switch ((value ?? '').trim().toUpperCase()) {
      'PER_CONSULTATION' => _CompensationPayType.perConsultation,
      'PER_HOUR' => _CompensationPayType.hourly,
      'PER_DAY' => _CompensationPayType.daily,
      'PER_PROCEDURE' => _CompensationPayType.perVisit,
      _ => _CompensationPayType.monthly,
    };
  }

  String _payTypeApiValue(_CompensationPayType type) {
    return switch (type) {
      _CompensationPayType.perConsultation => 'PER_CONSULTATION',
      _CompensationPayType.hourly => 'PER_HOUR',
      _CompensationPayType.daily => 'PER_DAY',
      _CompensationPayType.perVisit => 'PER_PROCEDURE',
      _CompensationPayType.monthly => 'PER_MONTH',
    };
  }

  Map<String, Object?> toPayload() {
    final num? rate = num.tryParse(_rateController.text.trim());
    final List<Map<String, Object?>> compensations = <Map<String, Object?>>[];
    if (rate != null) {
      compensations.add(<String, Object?>{
        'pay_type': _payTypeApiValue(_payType),
        'rate': rate,
        'currency': _currency.trim().toUpperCase(),
        'effective_from': _datePayload(_effectiveFrom),
        'effective_to': _datePayload(_effectiveTo),
        'metadata_json': <String, Object?>{'pay_frequency': _payFrequency},
      });
    }
    for (final HrStaffCompensation item in widget.history) {
      if (compensations.any(
        (Map<String, Object?> row) => row['pay_type'] == item.payType,
      )) {
        continue;
      }
      compensations.add(<String, Object?>{
        'pay_type': item.payType,
        'rate': item.rate,
        'currency': item.currency,
        'effective_from': _datePayload(item.effectiveFrom),
        'effective_to': _datePayload(item.effectiveTo),
      });
    }
    return <String, Object?>{'compensations': compensations};
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

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
          height: 360,
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              SingleChildScrollView(
                padding: EdgeInsets.only(top: theme.spacing.md),
                child: AppFormSection(
                  title: l10n.hrStaffOnboardingCompensationSectionTitle,
                  description: l10n.hrStaffOnboardingCompensationEditHint,
                  children: <Widget>[
                    AppSelectField<String>(
                      value: _payType.name,
                      labelText: l10n.hrStaffOnboardingPayTypeLabel,
                      options: <AppSelectOption<String>>[
                        AppSelectOption<String>(
                          value: _CompensationPayType.monthly.name,
                          label: l10n.hrCompensationMonthlyRateLabel,
                        ),
                        AppSelectOption<String>(
                          value: _CompensationPayType.hourly.name,
                          label: l10n.hrCompensationHourlyRateLabel,
                        ),
                        AppSelectOption<String>(
                          value: _CompensationPayType.daily.name,
                          label: l10n.hrCompensationDailyRateLabel,
                        ),
                        AppSelectOption<String>(
                          value: _CompensationPayType.perConsultation.name,
                          label: l10n.hrCompensationConsultationRateLabel,
                        ),
                        AppSelectOption<String>(
                          value: _CompensationPayType.perVisit.name,
                          label: l10n.hrCompensationProcedureRateLabel,
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setState(
                          () => _payType =
                              _CompensationPayType.values.byName(value),
                        );
                      },
                    ),
                    AppSelectField<String>(
                      value: _payFrequency,
                      labelText: l10n.hrCompensationPayFrequencyLabel,
                      options: <AppSelectOption<String>>[
                        AppSelectOption<String>(
                          value: 'MONTHLY',
                          label: l10n.hrCompensationFrequencyMonthlyLabel,
                        ),
                        AppSelectOption<String>(
                          value: 'BIWEEKLY',
                          label: l10n.hrCompensationFrequencyBiweeklyLabel,
                        ),
                        AppSelectOption<String>(
                          value: 'WEEKLY',
                          label: l10n.hrCompensationFrequencyWeeklyLabel,
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => _payFrequency = value);
                        }
                      },
                    ),
                    AppCurrencyAmountField(
                      amountController: _rateController,
                      currency: _currency,
                      onCurrencyChanged: (String? value) {
                        setState(
                          () => _currency = value ?? appDefaultCurrencyCode,
                        );
                      },
                      amountLabelText: l10n.hrCompensationBaseRateLabel,
                      currencyLabelText: l10n.hrCompensationCurrencyLabel,
                      currencySearchLabelText: l10n.appPhoneCountrySearchLabel,
                    ),
                    AppDateField(
                      value: _effectiveFrom,
                      labelText: l10n.hrEffectiveFromLabel,
                      isRequired: true,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      currentDate: DateTime.now(),
                      pickerButtonLabel: l10n.hrPickDateAction,
                      invalidDateMessage: l10n.appDateInvalidMessage,
                      onChanged: (DateTime? value) =>
                          setState(() => _effectiveFrom = value),
                    ),
                    AppDateField(
                      value: _effectiveTo,
                      labelText: l10n.hrEffectiveToLabel,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      currentDate: DateTime.now(),
                      pickerButtonLabel: l10n.hrPickDateAction,
                      invalidDateMessage: l10n.appDateInvalidMessage,
                      onChanged: (DateTime? value) =>
                          setState(() => _effectiveTo = value),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                padding: EdgeInsets.only(top: theme.spacing.md),
                itemCount: widget.history.length,
                separatorBuilder: (_, _) => SizedBox(height: theme.spacing.xs),
                itemBuilder: (BuildContext context, int index) {
                  final HrStaffCompensation item = widget.history[index];
                  return ListTile(
                    title: Text(hrCompensationRowTitle(context, item)),
                    subtitle: Text(
                      hrDateRange(context, item.effectiveFrom, item.effectiveTo),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String? _datePayload(DateTime? value) => value?.toIso8601String();
