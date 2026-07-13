import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Coverage verification shown when OPD consultation payment uses insurance.
/// Selects insurance company first, then scheme under that company.
class OpdCoverageVerificationPanel extends ConsumerStatefulWidget {
  const OpdCoverageVerificationPanel({
    required this.patientId,
    required this.encounterId,
    required this.enabled,
    required this.onVerifiedChanged,
    super.key,
  });

  final String? patientId;
  final String? encounterId;
  final bool enabled;
  final ValueChanged<
    ({
      bool verified,
      String? insuranceCompanyId,
      String? insuranceCompanyName,
      String? coveragePlanId,
      String? coveragePlanName,
      int? coveragePercentage,
      String? copayType,
      num? copayValue,
    })
  >
  onVerifiedChanged;

  @override
  ConsumerState<OpdCoverageVerificationPanel> createState() =>
      _OpdCoverageVerificationPanelState();
}

class _OpdCoverageVerificationPanelState
    extends ConsumerState<OpdCoverageVerificationPanel> {
  bool _isLoading = true;
  List<InsuranceCompanyOption> _companies = const <InsuranceCompanyOption>[];
  List<CoveragePlanOption> _plans = const <CoveragePlanOption>[];
  String? _selectedCompanyId;
  String? _selectedPlanId;
  bool _verified = false;

  List<CoveragePlanOption> get _schemesForCompany {
    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      return _plans;
    }
    return _plans
        .where(
          (CoveragePlanOption plan) =>
              plan.insuranceCompanyId == _selectedCompanyId,
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    final Result<ClaimsReferenceData> result = await ref
        .read(claimsRepositoryProvider)
        .loadReferenceData();
    if (!mounted) {
      return;
    }
    final ClaimsReferenceData data = result.when(
      success: (ClaimsReferenceData value) => value,
      failure: (_) => const ClaimsReferenceData(),
    );
    final List<CoveragePlanOption> plans = data.coveragePlans;
    List<InsuranceCompanyOption> companies = data.insuranceCompanies;
    if (companies.isEmpty) {
      final Map<String, InsuranceCompanyOption> derived =
          <String, InsuranceCompanyOption>{};
      for (final CoveragePlanOption plan in plans) {
        final String? companyId = plan.insuranceCompanyId;
        if (companyId == null || companyId.isEmpty) {
          continue;
        }
        derived.putIfAbsent(
          companyId,
          () => InsuranceCompanyOption(
            id: companyId,
            displayId: companyId,
            name: plan.insuranceCompanyName ?? plan.providerName,
            code: plan.insuranceCompanyCode,
          ),
        );
      }
      companies = derived.values.toList(growable: false);
    }

    setState(() {
      _isLoading = false;
      _companies = companies;
      _plans = plans;
      if (_selectedCompanyId == null && companies.isNotEmpty) {
        _selectedCompanyId = companies.first.id;
      }
      final List<CoveragePlanOption> scoped = _schemesForCompany;
      if (_selectedPlanId == null && scoped.isNotEmpty) {
        _selectedPlanId = scoped.first.apiId;
      }
    });
    _notifyVerified();
  }

  void _notifyVerified() {
    CoveragePlanOption? selected;
    for (final CoveragePlanOption plan in _plans) {
      if (plan.apiId == _selectedPlanId) {
        selected = plan;
        break;
      }
    }
    InsuranceCompanyOption? company;
    for (final InsuranceCompanyOption item in _companies) {
      if (item.id == _selectedCompanyId || item.apiId == _selectedCompanyId) {
        company = item;
        break;
      }
    }
    widget.onVerifiedChanged((
      verified: _verified && (_selectedPlanId ?? '').trim().isNotEmpty,
      insuranceCompanyId:
          selected?.insuranceCompanyId ?? company?.id ?? _selectedCompanyId,
      insuranceCompanyName:
          selected?.insuranceCompanyName ??
          company?.title ??
          selected?.providerName,
      coveragePlanId: _selectedPlanId,
      coveragePlanName: selected?.title,
      coveragePercentage: selected?.coveragePercentage,
      copayType: selected?.defaultCopayType,
      copayValue: selected?.defaultCopayValue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (_isLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (_plans.isEmpty) {
      return Text(
        l10n.claimsCoveragePlansUnavailable,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }

    final List<CoveragePlanOption> schemes = _schemesForCompany;

    return AppFormSection(
      title: l10n.opdCoverageVerificationTitle,
      children: <Widget>[
        Text(
          l10n.opdCoverageVerificationBody,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_companies.isNotEmpty)
          AppSelectField<String>(
            value: _selectedCompanyId,
            labelText: l10n.claimsInsuranceCompanyFieldLabel,
            enabled: widget.enabled,
            onChanged: (String? value) {
              setState(() {
                _selectedCompanyId = value;
                _verified = false;
                final List<CoveragePlanOption> next = _plans
                    .where(
                      (CoveragePlanOption plan) =>
                          plan.insuranceCompanyId == value,
                    )
                    .toList(growable: false);
                _selectedPlanId = next.isEmpty ? null : next.first.apiId;
              });
              _notifyVerified();
            },
            options: <AppSelectOption<String>>[
              for (final InsuranceCompanyOption company in _companies)
                AppSelectOption<String>(
                  value: company.id,
                  label: company.title,
                ),
            ],
          ),
        AppSelectField<String>(
          value: _selectedPlanId,
          labelText: l10n.claimsCoverageSchemeFieldLabel,
          enabled: widget.enabled && schemes.isNotEmpty,
          onChanged: (String? value) {
            setState(() {
              _selectedPlanId = value;
              _verified = false;
            });
            _notifyVerified();
          },
          options: <AppSelectOption<String>>[
            for (final CoveragePlanOption plan in schemes)
              AppSelectOption<String>(
                value: plan.apiId,
                label: plan.subtitle == null
                    ? plan.title
                    : '${plan.title} (${plan.subtitle})',
              ),
          ],
        ),
        CheckboxListTile(
          value: _verified,
          title: Text(l10n.opdCoverageVerifiedLabel),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          enabled: widget.enabled && (_selectedPlanId ?? '').isNotEmpty,
          onChanged: (bool? value) {
            setState(() => _verified = value ?? false);
            _notifyVerified();
          },
        ),
      ],
    );
  }
}
