import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

const List<String> kHrCompensationPayTypeCodes = <String>[
  'PER_CONSULTATION',
  'PER_MONTH',
  'PER_DAY',
  'PER_HOUR',
  'PER_PROCEDURE',
];

class HrCompensationLineData {
  HrCompensationLineData({
    required this.payType,
    required this.rateController,
    this.currency = appDefaultCurrencyCode,
    this.payFrequency = 'MONTHLY',
    this.effectiveFrom,
    this.effectiveTo,
    this.removed = false,
  });

  String payType;
  final TextEditingController rateController;
  String currency;
  String payFrequency;
  DateTime? effectiveFrom;
  DateTime? effectiveTo;
  bool removed;

  Map<String, Object?> toPayload() {
    final num? rate = num.tryParse(rateController.text.trim());
    if (rate == null || removed) {
      return <String, Object?>{};
    }
    return <String, Object?>{
      'pay_type': payType,
      'rate': rate,
      'currency': currency.trim().toUpperCase(),
      'effective_from': effectiveFrom?.toIso8601String(),
      'effective_to': effectiveTo?.toIso8601String(),
      if (payType == 'PER_MONTH')
        'metadata_json': <String, Object?>{'pay_frequency': payFrequency},
    };
  }
}

class HrCompensationLineEditor extends StatelessWidget {
  const HrCompensationLineEditor({
    required this.line,
    required this.usedPayTypes,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final HrCompensationLineData line;
  final Set<String> usedPayTypes;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

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
                  l10n.hrReferenceCompensationPayTypeLabel(
                    line.payType,
                    fallback: line.payType,
                  ),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: l10n.hrCompensationRemovePayLineAction,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          AppSelectField<String>(
            value: line.payType,
            labelText: l10n.hrStaffOnboardingPayTypeLabel,
            options: kHrCompensationPayTypeCodes
                .where(
                  (String code) =>
                      code == line.payType || !usedPayTypes.contains(code),
                )
                .map(
                  (String code) => AppSelectOption<String>(
                    value: code,
                    label: l10n.hrReferenceCompensationPayTypeLabel(
                      code,
                      fallback: code,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              line.payType = value;
              onChanged();
            },
          ),
          if (line.payType == 'PER_MONTH')
            AppSelectField<String>(
              value: line.payFrequency,
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
                  line.payFrequency = value;
                  onChanged();
                }
              },
            ),
          AppCurrencyAmountField(
            amountController: line.rateController,
            currency: line.currency,
            onCurrencyChanged: (String? value) {
              line.currency = value ?? appDefaultCurrencyCode;
              onChanged();
            },
            amountLabelText: l10n.hrCompensationBaseRateLabel,
            currencyLabelText: l10n.hrCompensationCurrencyLabel,
            currencySearchLabelText: l10n.appPhoneCountrySearchLabel,
          ),
          AppDateField(
            value: line.effectiveFrom,
            labelText: l10n.hrEffectiveFromLabel,
            isRequired: true,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.hrPickDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            onChanged: (DateTime? value) {
              line.effectiveFrom = value;
              onChanged();
            },
          ),
          AppDateField(
            value: line.effectiveTo,
            labelText: l10n.hrEffectiveToLabel,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.hrPickDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            onChanged: (DateTime? value) {
              line.effectiveTo = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

List<AppSelectOption<String>> hrCompensationPayTypeSelectOptions(
  AppLocalizations l10n,
) {
  return kHrCompensationPayTypeCodes
      .map(
        (String code) => AppSelectOption<String>(
          value: code,
          label: hrCompensationPayTypeLabel(l10n, code),
        ),
      )
      .toList(growable: false);
}

String hrCompensationRateLabel(AppLocalizations l10n, String payType) {
  return hrCompensationPayTypeLabel(l10n, payType);
}

String hrCompensationPayTypeFromApi(String? value) {
  final String normalized = (value ?? '').trim().toUpperCase();
  if (kHrCompensationPayTypeCodes.contains(normalized)) {
    return normalized;
  }
  return 'PER_MONTH';
}

String hrCompensationPayTypeLabel(AppLocalizations l10n, String payType) {
  return l10n.hrReferenceCompensationPayTypeLabel(payType, fallback: payType);
}
