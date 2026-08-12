import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_cancel_reasons.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_print_options_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Checkbox catalog of cancel reasons with select-all and optional custom reason.
class PharmacyCancelReasonsSection extends StatelessWidget {
  const PharmacyCancelReasonsSection({
    required this.selectedReasons,
    required this.onChanged,
    required this.customReasonController,
    required this.enabled,
    this.showValidationError = false,
    super.key,
  });

  final Set<PharmacyCancelReason> selectedReasons;
  final ValueChanged<Set<PharmacyCancelReason>> onChanged;
  final TextEditingController customReasonController;
  final bool enabled;
  final bool showValidationError;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<PharmacyCancelReason> reasons = pharmacyCancelReasonsCatalog();
    final int selectedCount = selectedReasons.length;
    final int totalCount = reasons.length;
    final bool someSelected = selectedCount > 0;
    final bool customFilled = customReasonController.text.trim().isNotEmpty;
    final bool hasValidSelection = someSelected || customFilled;

    return AppFormSection(
      title: l10n.pharmacyCancelReasonsSectionLabel,
      description: l10n.pharmacyCancelReasonsSectionBody,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            tristate: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            secondary: Icon(
              Icons.checklist_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            value: selectedCount == 0
                ? false
                : selectedCount == totalCount
                ? true
                : null,
            title: Text(
              selectedCount == totalCount && totalCount > 0
                  ? l10n.commonDeselectAllActionLabel
                  : l10n.commonSelectAllActionLabel,
            ),
            subtitle: selectedCount > 0 && selectedCount < totalCount
                ? Text(
                    l10n.pharmacyCancelReasonsSelectedCountLabel(
                      selectedCount,
                      totalCount,
                    ),
                  )
                : null,
            onChanged: enabled
                ? (bool? checked) {
                    onChanged(
                      checked == true
                          ? reasons.toSet()
                          : <PharmacyCancelReason>{},
                    );
                  }
                : null,
          ),
        ),
        ...reasons.map((PharmacyCancelReason reason) {
          final bool selected = selectedReasons.contains(reason);
          return PharmacyPrintSelectableTile(
            selected: selected,
            emphasizeTitle: false,
            icon: reason.icon,
            title: reason.label(l10n),
            onChanged: enabled
                ? (bool next) {
                    final Set<PharmacyCancelReason> updated =
                        Set<PharmacyCancelReason>.from(selectedReasons);
                    if (next) {
                      updated.add(reason);
                    } else {
                      updated.remove(reason);
                    }
                    onChanged(updated);
                  }
                : (_) {},
          );
        }),
        AppTextField(
          controller: customReasonController,
          labelText: l10n.pharmacyCancelCustomReasonLabel,
          enabled: enabled,
          maxLines: 2,
          isRequired: !someSelected,
          helperText: someSelected
              ? l10n.pharmacyCancelCustomReasonOptionalHelper
              : l10n.pharmacyCancelCustomReasonRequiredHelper,
          validator: (String? value) {
            if (someSelected) {
              return null;
            }
            if ((value ?? '').trim().isEmpty) {
              return l10n.pharmacyCancelReasonRequiredMessage;
            }
            return null;
          },
        ),
        if (showValidationError && !hasValidSelection)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Text(
              l10n.pharmacyCancelReasonRequiredMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
