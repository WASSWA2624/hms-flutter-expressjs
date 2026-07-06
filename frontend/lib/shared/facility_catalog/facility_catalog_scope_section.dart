import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

@immutable
final class FacilityCatalogScopeLabels {
  const FacilityCatalogScopeLabels({
    required this.facilityContextLabel,
    required this.selectTenantFirstTooltip,
    required this.tenantLabel,
    required this.facilityLabel,
  });

  final String Function(String facilityName) facilityContextLabel;
  final String selectTenantFirstTooltip;
  final String tenantLabel;
  final String facilityLabel;
}

class FacilityCatalogScopeSection extends StatelessWidget {
  const FacilityCatalogScopeSection({
    required this.labels,
    required this.scopeReady,
    required this.showTenantSelector,
    required this.showFacilitySelector,
    required this.showScopeContextLabel,
    required this.tenantOptions,
    required this.facilityOptions,
    required this.tenantId,
    required this.facilityId,
    required this.facilitySelectorEnabled,
    required this.facilityLabel,
    required this.scopePromptMessage,
    required this.onTenantChanged,
    required this.onFacilityChanged,
    super.key,
  });

  final FacilityCatalogScopeLabels labels;
  final bool scopeReady;
  final bool showTenantSelector;
  final bool showFacilitySelector;
  final bool showScopeContextLabel;
  final List<HomeLookupOption> tenantOptions;
  final List<HomeLookupOption> facilityOptions;
  final String? tenantId;
  final String? facilityId;
  final bool facilitySelectorEnabled;
  final String? facilityLabel;
  final String scopePromptMessage;
  final ValueChanged<String?> onTenantChanged;
  final ValueChanged<String?> onFacilityChanged;

  @override
  Widget build(BuildContext context) {
    final bool hasTenantRow = showTenantSelector && tenantOptions.isNotEmpty;
    final bool hasFacilityOnlyRow =
        !hasTenantRow && showFacilitySelector && facilityOptions.isNotEmpty;
    final bool hasFixedContextLabel =
        showScopeContextLabel &&
        scopeReady &&
        facilityLabel != null &&
        facilityLabel!.isNotEmpty;

    if (!hasTenantRow && !hasFacilityOnlyRow && !hasFixedContextLabel) {
      if (!scopeReady) {
        return AppSectionPanel(
          tone: AppWorkspaceStatusTone.info,
          density: AppContentPanelDensity.compact,
          leadingIcon: Icons.domain_outlined,
          children: <Widget>[
            Text(
              scopePromptMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    if (hasFixedContextLabel && !hasTenantRow && !hasFacilityOnlyRow) {
      return AppMutedText(labels.facilityContextLabel(facilityLabel!));
    }

    final String? guidanceMessage =
        scopeReady && facilityLabel != null && facilityLabel!.isNotEmpty
        ? labels.facilityContextLabel(facilityLabel!)
        : (!scopeReady ? scopePromptMessage : null);

    return AppSectionPanel(
      tone: scopeReady
          ? AppWorkspaceStatusTone.neutral
          : AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        if (hasTenantRow)
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppSelectField<String>.searchable(
              value: tenantId,
              labelText: labels.tenantLabel,
              options: <AppSelectOption<String>>[
                for (final HomeLookupOption tenant in tenantOptions)
                  AppSelectOption<String>(
                    value: tenant.id,
                    label: tenant.label,
                  ),
              ],
              onChanged: onTenantChanged,
            ),
            right: facilitySelectorEnabled
                ? AppSelectField<String>.searchable(
                    value: facilityId,
                    labelText: labels.facilityLabel,
                    isRequired: true,
                    options: <AppSelectOption<String>>[
                      for (final HomeLookupOption facility in facilityOptions)
                        AppSelectOption<String>(
                          value: facility.id,
                          label: facility.label,
                        ),
                    ],
                    onChanged: onFacilityChanged,
                  )
                : _FacilityCatalogDisabledFacilityField(
                    tooltipMessage: labels.selectTenantFirstTooltip,
                    labelText: labels.facilityLabel,
                  ),
          )
        else if (hasFacilityOnlyRow)
          AppSelectField<String>.searchable(
            value: facilityId,
            labelText: labels.facilityLabel,
            isRequired: true,
            options: <AppSelectOption<String>>[
              for (final HomeLookupOption facility in facilityOptions)
                AppSelectOption<String>(
                  value: facility.id,
                  label: facility.label,
                ),
            ],
            onChanged: onFacilityChanged,
          ),
        if (guidanceMessage != null)
          _FacilityCatalogScopeGuidance(
            message: guidanceMessage,
            showIcon: !scopeReady,
          ),
      ],
    );
  }
}

class _FacilityCatalogScopeGuidance extends StatelessWidget {
  const _FacilityCatalogScopeGuidance({
    required this.message,
    required this.showIcon,
  });

  final String message;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? textStyle = showIcon
        ? theme.textTheme.bodyMedium
        : theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );

    if (!showIcon) {
      return Text(message, style: textStyle);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.domain_outlined,
          color: theme.colorScheme.primary,
          size: theme.appTokens.listIconSize,
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(child: Text(message, style: textStyle)),
      ],
    );
  }
}

class _FacilityCatalogDisabledFacilityField extends StatelessWidget {
  const _FacilityCatalogDisabledFacilityField({
    required this.tooltipMessage,
    required this.labelText,
  });

  final String tooltipMessage;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tooltipMessage)));
      },
      child: Tooltip(
        message: tooltipMessage,
        child: AbsorbPointer(
          child: AppSelectField<String>(
            value: null,
            labelText: labelText,
            options: const <AppSelectOption<String>>[],
          ),
        ),
      ),
    );
  }
}
