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
  final ValueChanged<({bool verified, String? coveragePlanId})> onVerifiedChanged;

  @override
  ConsumerState<OpdCoverageVerificationPanel> createState() =>
      _OpdCoverageVerificationPanelState();
}

class _OpdCoverageVerificationPanelState
    extends ConsumerState<OpdCoverageVerificationPanel> {
  bool _isLoading = true;
  List<CoveragePlanOption> _plans = const <CoveragePlanOption>[];
  String? _selectedPlanId;
  bool _verified = false;

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
    final List<CoveragePlanOption> plans = result.when(
      success: (ClaimsReferenceData data) => data.coveragePlans,
      failure: (_) => const <CoveragePlanOption>[],
    );
    setState(() {
      _isLoading = false;
      _plans = plans;
      if (_selectedPlanId == null && plans.isNotEmpty) {
        _selectedPlanId = plans.first.apiId;
      }
    });
    _notifyVerified();
  }

  void _notifyVerified() {
    widget.onVerifiedChanged((
      verified: _verified && (_selectedPlanId ?? '').trim().isNotEmpty,
      coveragePlanId: _selectedPlanId,
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

    return AppFormSection(
      title: l10n.opdCoverageVerificationTitle,
      children: <Widget>[
        Text(
          l10n.opdCoverageVerificationBody,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        AppSelectField<String>(
          value: _selectedPlanId,
          labelText: l10n.claimsCoveragePlanFieldLabel,
          enabled: widget.enabled,
          onChanged: (String? value) {
            setState(() {
              _selectedPlanId = value;
              _verified = false;
            });
            _notifyVerified();
          },
          options: <AppSelectOption<String>>[
            for (final CoveragePlanOption plan in _plans)
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

  String? get selectedCoveragePlanId => _selectedPlanId;
}
