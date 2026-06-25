import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Shows insurance authorization state for IPD admissions or OPD encounters.
class InsuranceAuthorizationPanel extends ConsumerStatefulWidget {
  const InsuranceAuthorizationPanel({
    this.patientId,
    this.admissionId,
    this.encounterId,
    this.canManage = false,
    this.onRequestAuthorization,
    super.key,
  });

  final String? patientId;
  final String? admissionId;
  final String? encounterId;
  final bool canManage;
  final Future<void> Function()? onRequestAuthorization;

  @override
  ConsumerState<InsuranceAuthorizationPanel> createState() =>
      _InsuranceAuthorizationPanelState();
}

class _InsuranceAuthorizationPanelState
    extends ConsumerState<InsuranceAuthorizationPanel> {
  bool _isLoading = true;
  List<PreAuthorizationRecord> _authorizations =
      const <PreAuthorizationRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant InsuranceAuthorizationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId ||
        oldWidget.admissionId != widget.admissionId ||
        oldWidget.encounterId != widget.encounterId) {
      _load();
    }
  }

  Future<void> _load() async {
    if ((widget.patientId ?? '').isEmpty &&
        (widget.admissionId ?? '').isEmpty &&
        (widget.encounterId ?? '').isEmpty) {
      setState(() {
        _isLoading = false;
        _authorizations = const <PreAuthorizationRecord>[];
      });
      return;
    }

    setState(() => _isLoading = true);
    final Result<AppPage<PreAuthorizationRecord>> result = await ref
        .read(claimsRepositoryProvider)
        .listPreAuthorizationsForContext(
          patientId: widget.patientId,
          admissionId: widget.admissionId,
          encounterId: widget.encounterId,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _authorizations = result.when(
        success: (AppPage<PreAuthorizationRecord> page) => page.items,
        failure: (_) => const <PreAuthorizationRecord>[],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PreAuthorizationRecord? active = _activeAuthorization;

    return AppReportPreviewPanel(
      title: l10n.claimsInsuranceAuthorizationTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (active == null)
            Text(
              l10n.claimsInsuranceAuthorizationEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...<Widget>[
            AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: _authorizationStatusLabel(l10n, active.status),
                tone: _authorizationTone(active.status),
                icon: Icons.verified_user_outlined,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            AppReportSummaryGrid(
              records: <AppReportSummaryItem>[
                AppReportSummaryItem(
                  label: l10n.claimsApprovedAmountLabel,
                  value: _money(context, active.approvedAmount),
                  icon: Icons.check_circle_outline,
                ),
                AppReportSummaryItem(
                  label: l10n.claimsConsumedAmountLabel,
                  value: _money(context, active.consumedAmount),
                  icon: Icons.payments_outlined,
                ),
                AppReportSummaryItem(
                  label: l10n.claimsRemainingAmountLabel,
                  value: _money(context, active.remainingAmount),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            if ((active.coveragePlanDisplayId).isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Text(
                '${l10n.claimsCoveragePlanFieldLabel}: ${active.coveragePlanDisplayId}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if ((active.reason ?? '').isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                '${l10n.claimsAuthorizationReasonLabel}: ${active.reason!}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
          if (widget.canManage) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppButton.secondary(
              label: l10n.claimsRequestAuthorizationAction,
              leadingIcon: Icons.add_moderator_outlined,
              onPressed: widget.onRequestAuthorization == null
                  ? null
                  : () async {
                      await widget.onRequestAuthorization!.call();
                      if (mounted) {
                        await _load();
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }

  PreAuthorizationRecord? get _activeAuthorization {
    for (final PreAuthorizationRecord item in _authorizations) {
      if (item.status.toUpperCase() == 'APPROVED') {
        return item;
      }
    }
    return _authorizations.isEmpty ? null : _authorizations.first;
  }

  String _money(BuildContext context, num? amount) {
    if (amount == null) {
      return context.l10n.billingNotRecorded;
    }
    return AppFormatters.currency(amount, Localizations.localeOf(context));
  }

  String _authorizationStatusLabel(AppLocalizations l10n, String status) {
    return switch (status.toUpperCase()) {
      'APPROVED' => l10n.claimsFilterAuthorizationApproved,
      'DENIED' => l10n.claimsFilterAuthorizationDenied,
      'EXPIRED' => l10n.claimsFilterAuthorizationExpired,
      _ => l10n.claimsFilterAuthorizationPending,
    };
  }

  AppWorkspaceStatusTone _authorizationTone(String status) {
    return switch (status.toUpperCase()) {
      'APPROVED' => AppWorkspaceStatusTone.success,
      'DENIED' || 'EXPIRED' => AppWorkspaceStatusTone.error,
      _ => AppWorkspaceStatusTone.warning,
    };
  }
}
