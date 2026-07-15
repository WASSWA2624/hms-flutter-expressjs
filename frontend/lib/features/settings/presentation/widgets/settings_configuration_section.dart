import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

const AccessRequirement _tenantConfigRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.tenantAdmin,
    AppPermissions.systemAdmin,
  ],
  anyRoles: <AppRole>[AppRole.superAdmin, AppRole.tenantAdmin],
  requiresTenantContext: true,
);

const AccessRequirement _facilityConfigRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ],
  anyRoles: <AppRole>[
    AppRole.superAdmin,
    AppRole.tenantAdmin,
    AppRole.facilityAdmin,
  ],
  requiresFacilityContext: true,
);

class SettingsConfigurationSection extends ConsumerWidget {
  const SettingsConfigurationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canConfigureTenant = _tenantConfigRequirement.isAllowed(
      accessPolicy,
    );
    final bool canConfigureFacility = _facilityConfigRequirement.isAllowed(
      accessPolicy,
    );

    if (!canConfigureTenant && !canConfigureFacility) {
      return const SizedBox.shrink();
    }

    final AsyncValue<Result<FacilitySetupSnapshot>> setupAsync = ref.watch(
      tenantFacilitySetupControllerProvider,
    );

    return AppScreenSection(
      title: l10n.settingsConfigurationSectionTitle,
      body: l10n.settingsConfigurationSectionBody,
      child: setupAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, _) => AppStateView(
          title: l10n.settingsConfigurationSaveError,
          body: l10n.settingsConfigurationSectionBody,
          action: AppButton.secondary(
            label: l10n.commonRefreshActionLabel,
            leadingIcon: Icons.refresh,
            onPressed: () =>
                ref.invalidate(tenantFacilitySetupControllerProvider),
          ),
        ),
        data: (Result<FacilitySetupSnapshot> result) => result.when(
          success: (FacilitySetupSnapshot snapshot) => _ConfigurationContent(
            snapshot: snapshot,
            canConfigureTenant: canConfigureTenant,
            canConfigureFacility: canConfigureFacility,
          ),
          failure: (_) => AppStateView(
            title: l10n.settingsConfigurationSaveError,
            body: l10n.settingsConfigurationSectionBody,
            action: AppButton.secondary(
              label: l10n.commonRefreshActionLabel,
              leadingIcon: Icons.refresh,
              onPressed: () =>
                  ref.invalidate(tenantFacilitySetupControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigurationContent extends ConsumerWidget {
  const _ConfigurationContent({
    required this.snapshot,
    required this.canConfigureTenant,
    required this.canConfigureFacility,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canConfigureTenant;
  final bool canConfigureFacility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final TenantProfile? tenant = snapshot.tenant;
    final FacilityProfile? facility = snapshot.facility;

    if (tenant == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
        child: Text(
          l10n.settingsConfigurationNoTenantContext,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final bool showTenant = canConfigureTenant;
    final bool showFacility = canConfigureFacility && facility != null;

    if (!showTenant && !showFacility) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
        child: Text(
          l10n.settingsConfigurationNoTenantContext,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showTenant) ...<Widget>[
          _TenantConfigPanel(tenant: tenant),
          if (showFacility) SizedBox(height: theme.spacing.md),
        ],
        if (showFacility)
          _FacilityConfigPanel(tenant: tenant, facility: facility),
      ],
    );
  }
}

class _TenantConfigPanel extends ConsumerStatefulWidget {
  const _TenantConfigPanel({required this.tenant});

  final TenantProfile tenant;

  @override
  ConsumerState<_TenantConfigPanel> createState() => _TenantConfigPanelState();
}

class _TenantConfigPanelState extends ConsumerState<_TenantConfigPanel> {
  late TextEditingController _feeController;
  late String? _currency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currency = widget.tenant.currency;
    _feeController = TextEditingController(
      text: widget.tenant.standardConsultationFee ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _TenantConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenant.id != widget.tenant.id) {
      _currency = widget.tenant.currency;
      _feeController.text = widget.tenant.standardConsultationFee ?? '';
    }
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String resolvedCurrency = resolveDefaultCurrency(
      tenantCurrency: _currency,
    );

    return AppSectionPanel(
      title: l10n.settingsConfigurationTenantTitle,
      leadingIcon: Icons.domain_outlined,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 600;

            final Widget currencyField = AppCurrencySelectField(
              value: _currency,
              labelText: l10n.settingsConfigurationCurrencyLabel,
              helperText: l10n.settingsConfigurationCurrencyHelper,
              enabled: !_saving,
              onChanged: (String? value) {
                setState(() => _currency = value);
              },
            );

            final Widget feeField = AppCurrencyAmountField(
              amountController: _feeController,
              currency: resolvedCurrency,
              onCurrencyChanged: (String? value) {
                if (value != null) {
                  setState(() => _currency = value);
                }
              },
              amountLabelText: l10n.settingsConfigurationConsultationFeeLabel,
              currencyLabelText: l10n.settingsConfigurationCurrencyLabel,
              helperText: l10n.settingsConfigurationConsultationFeeHelper,
              enabled: !_saving,
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: currencyField),
                  SizedBox(width: theme.spacing.lg),
                  Expanded(child: feeField),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                currencyField,
                SizedBox(height: theme.spacing.md),
                feeField,
              ],
            );
          },
        ),
        SizedBox(height: theme.spacing.lg),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            AppButton.tertiary(
              label: l10n.settingsConfigurationResetAction,
              leadingIcon: Icons.restart_alt_outlined,
              enabled: !_saving && _hasValues,
              onPressed: _saving ? null : _confirmReset,
            ),
            AppButton.primary(
              label: l10n.settingsConfigurationSaveAction,
              leadingIcon: Icons.save_outlined,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ],
    );
  }

  bool get _hasValues =>
      (_currency != null && _currency!.isNotEmpty) ||
      _feeController.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    final TenantProfile tenant = widget.tenant;
    final String fee = normalizeCurrencyAmount(_feeController.text);

    final bool success = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveTenantConfiguration(
          id: tenant.mutationId,
          name: tenant.name,
          slug: tenant.slug,
          isActive: tenant.isActive,
          currency: _currency,
          standardConsultationFee: fee.isEmpty ? null : fee,
          clearCurrency: _currency == null || _currency!.isEmpty,
          clearStandardConsultationFee: fee.isEmpty,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    final AppLocalizations l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? l10n.settingsConfigurationSaveSuccess
                : l10n.settingsConfigurationSaveError,
          ),
        ),
      );
  }

  Future<void> _confirmReset() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppDialog(
        title: Text(l10n.settingsConfigurationResetConfirmTitle),
        icon: const Icon(Icons.restart_alt_outlined),
        content: Text(l10n.settingsConfigurationResetConfirmBody),
        actions: <Widget>[
          AppButton.tertiary(
            label: MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.primary(
            label: l10n.settingsConfigurationResetAction,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _currency = null;
      _feeController.text = '';
      _saving = true;
    });

    final TenantProfile tenant = widget.tenant;
    final bool success = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveTenantConfiguration(
          id: tenant.mutationId,
          name: tenant.name,
          slug: tenant.slug,
          isActive: tenant.isActive,
          clearCurrency: true,
          clearStandardConsultationFee: true,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    final AppLocalizations resetL10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? resetL10n.settingsConfigurationSaveSuccess
                : resetL10n.settingsConfigurationSaveError,
          ),
        ),
      );
  }
}

class _FacilityConfigPanel extends ConsumerStatefulWidget {
  const _FacilityConfigPanel({required this.tenant, required this.facility});

  final TenantProfile tenant;
  final FacilityProfile facility;

  @override
  ConsumerState<_FacilityConfigPanel> createState() =>
      _FacilityConfigPanelState();
}

class _FacilityConfigPanelState extends ConsumerState<_FacilityConfigPanel> {
  late TextEditingController _feeController;
  late String? _currency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currency = widget.facility.currency;
    _feeController = TextEditingController(
      text: widget.facility.standardConsultationFee ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _FacilityConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facility.id != widget.facility.id) {
      _currency = widget.facility.currency;
      _feeController.text = widget.facility.standardConsultationFee ?? '';
    }
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String resolvedCurrency = resolveDefaultCurrency(
      facilityCurrency: _currency,
      tenantCurrency: widget.tenant.currency,
    );

    return AppSectionPanel(
      title: l10n.settingsConfigurationFacilityTitle,
      leadingIcon: Icons.business_outlined,
      children: <Widget>[
        Text(
          l10n.settingsConfigurationFacilityOverrideHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 600;

            final Widget currencyField = AppCurrencySelectField(
              value: _currency,
              labelText: l10n.settingsConfigurationCurrencyLabel,
              helperText: l10n.settingsConfigurationCurrencyHelper,
              enabled: !_saving,
              onChanged: (String? value) {
                setState(() => _currency = value);
              },
            );

            final Widget feeField = AppCurrencyAmountField(
              amountController: _feeController,
              currency: resolvedCurrency,
              onCurrencyChanged: (String? value) {
                if (value != null) {
                  setState(() => _currency = value);
                }
              },
              amountLabelText: l10n.settingsConfigurationConsultationFeeLabel,
              currencyLabelText: l10n.settingsConfigurationCurrencyLabel,
              helperText: l10n.settingsConfigurationConsultationFeeHelper,
              enabled: !_saving,
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: currencyField),
                  SizedBox(width: theme.spacing.lg),
                  Expanded(child: feeField),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                currencyField,
                SizedBox(height: theme.spacing.md),
                feeField,
              ],
            );
          },
        ),
        SizedBox(height: theme.spacing.lg),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            AppButton.tertiary(
              label: l10n.settingsConfigurationResetAction,
              leadingIcon: Icons.restart_alt_outlined,
              enabled: !_saving && _hasValues,
              onPressed: _saving ? null : _confirmReset,
            ),
            AppButton.primary(
              label: l10n.settingsConfigurationSaveAction,
              leadingIcon: Icons.save_outlined,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ],
    );
  }

  bool get _hasValues =>
      (_currency != null && _currency!.isNotEmpty) ||
      _feeController.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    final FacilityProfile facility = widget.facility;
    final String fee = normalizeCurrencyAmount(_feeController.text);

    final bool success = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveFacilityConfiguration(
          id: facility.mutationId,
          tenantId: facility.tenantId,
          name: facility.name,
          type: facility.type,
          isActive: facility.isActive,
          currency: _currency,
          standardConsultationFee: fee.isEmpty ? null : fee,
          clearCurrency: _currency == null || _currency!.isEmpty,
          clearStandardConsultationFee: fee.isEmpty,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    final AppLocalizations l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? l10n.settingsConfigurationSaveSuccess
                : l10n.settingsConfigurationSaveError,
          ),
        ),
      );
  }

  Future<void> _confirmReset() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppDialog(
        title: Text(l10n.settingsConfigurationResetConfirmTitle),
        icon: const Icon(Icons.restart_alt_outlined),
        content: Text(l10n.settingsConfigurationResetConfirmBody),
        actions: <Widget>[
          AppButton.tertiary(
            label: MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.primary(
            label: l10n.settingsConfigurationResetAction,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _currency = null;
      _feeController.text = '';
      _saving = true;
    });

    final FacilityProfile facility = widget.facility;
    final bool success = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveFacilityConfiguration(
          id: facility.mutationId,
          tenantId: facility.tenantId,
          name: facility.name,
          type: facility.type,
          isActive: facility.isActive,
          clearCurrency: true,
          clearStandardConsultationFee: true,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    final AppLocalizations resetL10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? resetL10n.settingsConfigurationSaveSuccess
                : resetL10n.settingsConfigurationSaveError,
          ),
        ),
      );
  }
}
