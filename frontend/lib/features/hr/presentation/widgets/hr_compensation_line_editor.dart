import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
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

const List<String> kHrCompensationPayFrequencyCodes = <String>[
  'MONTHLY',
  'BIWEEKLY',
  'WEEKLY',
  'PER_SERVICE',
];

class HrCompensationLineData {
  HrCompensationLineData({
    required this.payType,
    required this.rateController,
    this.currency = appDefaultCurrencyCode,
    String? payFrequency,
    this.payZone,
    this.effectiveFrom,
    this.effectiveTo,
    this.deductions = const <HrPayrollDeduction>[],
    this.removed = false,
  }) : payFrequency = payFrequency ?? hrDefaultPayFrequencyForType(payType);

  String payType;
  final TextEditingController rateController;
  String currency;
  String payFrequency;
  String? payZone;
  DateTime? effectiveFrom;
  DateTime? effectiveTo;
  List<HrPayrollDeduction> deductions;
  bool removed;

  Map<String, Object?> toPayload() {
    final num? rate = num.tryParse(
      normalizeCurrencyAmount(rateController.text),
    );
    if (rate == null || removed) {
      return <String, Object?>{};
    }
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
      'effective_from': effectiveFrom?.toIso8601String(),
      'effective_to': effectiveTo?.toIso8601String(),
      'metadata_json': metadata,
    };
  }
}

class HrCompensationLineEditor extends StatelessWidget {
  const HrCompensationLineEditor({
    required this.line,
    required this.usedPayTypes,
    required this.onChanged,
    this.onRemove,
    this.showHeader = true,
    super.key,
  });

  final HrCompensationLineData line;
  final Set<String> usedPayTypes;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    final Widget rateField = AppCurrencyAmountField(
      amountController: line.rateController,
      currency: line.currency,
      onCurrencyChanged: (String? value) {
        line.currency = value ?? appDefaultCurrencyCode;
        onChanged();
      },
      amountLabelText: l10n.hrCompensationBaseRateLabel,
      currencyLabelText: l10n.hrCompensationCurrencyLabel,
      currencySearchLabelText: l10n.appPhoneCountrySearchLabel,
      isRequired: true,
    );

    final Widget payTypeField = AppSelectField<String>(
      value: line.payType,
      labelText: l10n.hrStaffOnboardingPayTypeLabel,
      isRequired: true,
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
        line.payFrequency = hrDefaultPayFrequencyForType(value);
        onChanged();
      },
    );

    final Widget frequencyField = AppSelectField<String>(
      value: line.payFrequency,
      labelText: l10n.hrCompensationPayFrequencyLabel,
      options: kHrCompensationPayFrequencyCodes
          .map(
            (String code) => AppSelectOption<String>(
              value: code,
              label: hrCompensationPayFrequencyLabel(l10n, code),
            ),
          )
          .toList(growable: false),
      onChanged: (String? value) {
        if (value != null) {
          line.payFrequency = value;
          onChanged();
        }
      },
    );

    final Widget fromField = AppDateField(
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
    );

    final Widget toField = AppDateField(
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
    );

    final Widget zoneField = AppTextField(
      initialValue: line.payZone,
      labelText: l10n.hrCompensationPayZoneLabel,
      helperText: l10n.hrCompensationPayZoneHelper,
      onChanged: (String value) {
        line.payZone = value;
        onChanged();
      },
    );

    final Widget fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showHeader)
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
              if (onRemove != null)
                IconButton(
                  tooltip: l10n.hrCompensationRemovePayLineAction,
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final double formGap = theme.spacing.md;
            final double stackGap = theme.appTokens.formGapCompact;

            // Large: Base rate | Pay type | Pay frequency
            //        Effective from | Effective to
            //        Pay zone
            if (width >= 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 5, child: rateField),
                      SizedBox(width: formGap),
                      Expanded(flex: 4, child: payTypeField),
                      SizedBox(width: formGap),
                      Expanded(flex: 4, child: frequencyField),
                    ],
                  ),
                  SizedBox(height: stackGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: fromField),
                      SizedBox(width: formGap),
                      Expanded(child: toField),
                    ],
                  ),
                  SizedBox(height: stackGap),
                  zoneField,
                ],
              );
            }

            // Medium: Base rate full width, then Pay type | Frequency,
            //         Effective from | Effective to, then zone.
            if (width >= AppBreakpoints.md) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  rateField,
                  SizedBox(height: stackGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: payTypeField),
                      SizedBox(width: formGap),
                      Expanded(child: frequencyField),
                    ],
                  ),
                  SizedBox(height: stackGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: fromField),
                      SizedBox(width: formGap),
                      Expanded(child: toField),
                    ],
                  ),
                  SizedBox(height: stackGap),
                  zoneField,
                ],
              );
            }

            // Narrow: stack everything.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                rateField,
                SizedBox(height: stackGap),
                payTypeField,
                SizedBox(height: stackGap),
                frequencyField,
                SizedBox(height: stackGap),
                fromField,
                SizedBox(height: stackGap),
                toField,
                SizedBox(height: stackGap),
                zoneField,
              ],
            );
          },
        ),
      ],
    );

    if (!showHeader) {
      return fields;
    }

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: fields,
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

String hrDefaultPayFrequencyForType(String payType) {
  return switch (payType.trim().toUpperCase()) {
    'PER_CONSULTATION' || 'PER_PROCEDURE' => 'PER_SERVICE',
    'PER_DAY' => 'WEEKLY',
    'PER_HOUR' => 'WEEKLY',
    _ => 'MONTHLY',
  };
}

String hrCompensationPayFrequencyLabel(AppLocalizations l10n, String code) {
  return switch (code.trim().toUpperCase()) {
    'BIWEEKLY' => l10n.hrCompensationFrequencyBiweeklyLabel,
    'WEEKLY' => l10n.hrCompensationFrequencyWeeklyLabel,
    'PER_SERVICE' => l10n.hrCompensationFrequencyPerServiceLabel,
    _ => l10n.hrCompensationFrequencyMonthlyLabel,
  };
}
