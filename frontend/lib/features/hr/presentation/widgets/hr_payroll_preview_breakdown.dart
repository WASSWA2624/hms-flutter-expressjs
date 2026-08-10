import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_labels.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

class HrPayrollPreviewBreakdown extends StatelessWidget {
  const HrPayrollPreviewBreakdown({
    required this.item,
    this.defaultStaffName,
    super.key,
  });

  final HrPayrollPreviewItem item;
  final String? defaultStaffName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final HrPayrollPreviewCalculation? calculation = item.calculation;
    final List<HrPayrollCalculationComponent> components =
        calculation?.components ?? const <HrPayrollCalculationComponent>[];
    final String currency = (item.currency ?? '').trim().toUpperCase();
    final String amountLabel = hrPayrollAmountLabel(
      item.amount,
      locale,
      treatZeroAsEmpty: false,
    );

    return Card(
      margin: EdgeInsets.only(bottom: theme.spacing.sm),
      child: ExpansionTile(
        title: Text(
          item.staffName ?? defaultStaffName ?? item.staffNumber ?? '',
        ),
        subtitle: Text(
          hrJoinDisplay(<String?>[
            l10n.hrGrossPayLabel,
            currency.isEmpty ? amountLabel : '$amountLabel ($currency)',
          ]),
        ),
        children: <Widget>[
          if (components.isEmpty)
            Padding(
              padding: EdgeInsets.all(theme.spacing.md),
              child: Text(l10n.hrPayrollWizardNoStaffItemsLabel),
            )
          else
            for (final HrPayrollCalculationComponent component in components)
              ListTile(
                dense: true,
                title: Text(
                  l10n.hrReferenceCompensationPayTypeLabel(
                    component.payType ?? '',
                    fallback: component.payType,
                  ),
                ),
                subtitle: Text(
                  l10n.hrPayrollComponentBreakdownLabel(
                    component.quantity.toString(),
                    component.unit ?? '',
                    hrPayrollAmountLabel(
                      component.rate,
                      locale,
                      treatZeroAsEmpty: false,
                    ),
                    component.currency ?? item.currency ?? '',
                    hrPayrollAmountLabel(
                      component.amount,
                      locale,
                      treatZeroAsEmpty: false,
                    ),
                  ),
                ),
              ),
          for (final HrPayrollPreviewWarning warning
              in calculation?.warnings ?? const <HrPayrollPreviewWarning>[])
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.md,
                0,
                theme.spacing.md,
                theme.spacing.sm,
              ),
              child: Text(
                l10n.hrPayrollZeroQuantityWarning(
                  l10n.hrReferenceCompensationPayTypeLabel(
                    warning.payType ?? '',
                    fallback: warning.payType,
                  ),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (calculation?.mixedCurrency == true)
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.md,
                0,
                theme.spacing.md,
                theme.spacing.sm,
              ),
              child: Text(
                l10n.hrPayrollMixedCurrencyWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
