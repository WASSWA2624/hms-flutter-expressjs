import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_report_admins_dialog.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_upgrade_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Shows a one-shot action dialog when the tenant subscription is expired.
class SubscriptionExpiredPromptHost extends StatefulWidget {
  const SubscriptionExpiredPromptHost({
    required this.summary,
    required this.platformAdminContact,
    required this.child,
    this.tenantAdminContacts = const <OrgAdminContact>[],
    this.facilityAdminContacts = const <OrgAdminContact>[],
    this.canManageBilling = false,
    this.onRenewed,
    super.key,
  });

  final TenantSubscriptionSummary? summary;
  final PlatformAdminContact? platformAdminContact;
  final List<OrgAdminContact> tenantAdminContacts;
  final List<OrgAdminContact> facilityAdminContacts;
  final Widget child;
  final bool canManageBilling;
  final Future<void> Function()? onRenewed;

  @override
  State<SubscriptionExpiredPromptHost> createState() =>
      _SubscriptionExpiredPromptHostState();
}

class _SubscriptionExpiredPromptHostState
    extends State<SubscriptionExpiredPromptHost> {
  String? _promptedForKey;
  bool _dialogOpen = false;

  String? _promptKeyFor(TenantSubscriptionSummary? summary) {
    if (summary == null ||
        summary.headerState != TenantSubscriptionHeaderState.expired) {
      return null;
    }
    return '${summary.subscriptionId ?? summary.planId ?? 'tenant'}:expired';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePromptIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SubscriptionExpiredPromptHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary?.headerState != widget.summary?.headerState ||
        oldWidget.summary?.subscriptionId != widget.summary?.subscriptionId ||
        oldWidget.canManageBilling != widget.canManageBilling) {
      _schedulePromptIfNeeded();
    }
  }

  void _schedulePromptIfNeeded() {
    final String? promptKey = _promptKeyFor(widget.summary);
    if (promptKey == null || _promptedForKey == promptKey || _dialogOpen) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dialogOpen) {
        return;
      }
      final TenantSubscriptionSummary? current = widget.summary;
      final String? key = _promptKeyFor(current);
      if (key == null || _promptedForKey == key || current == null) {
        return;
      }
      _promptedForKey = key;
      unawaited(_showExpiredPrompt(current));
    });
  }

  Future<void> _showExpiredPrompt(TenantSubscriptionSummary summary) async {
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    setState(() => _dialogOpen = true);

    if (!widget.canManageBilling) {
      await showSubscriptionReportAdminsDialog(
        context,
        headerState: summary.headerState,
        tenantAdmins: widget.tenantAdminContacts,
        facilityAdmins: widget.facilityAdminContacts,
        platformAdminContact: widget.platformAdminContact,
      );
      if (mounted) {
        setState(() => _dialogOpen = false);
      }
      return;
    }

    final bool? renewNow = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialog(
          title: Text(l10n.subscriptionExpiredPromptTitle),
          icon: const Icon(Icons.warning_amber_rounded),
          maxWidth: 440,
          initialMaximized: false,
          showMaximizeButton: false,
          resizable: false,
          content: Text(
            l10n.subscriptionExpiredPromptBody,
            style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: <Widget>[
            AppButton.secondary(
              label: l10n.subscriptionExpiredPromptLaterAction,
              leadingIcon: Icons.schedule,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppButton.primary(
              label: l10n.subscriptionExpiredPromptRenewAction,
              leadingIcon: Icons.workspace_premium_outlined,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (renewNow == true) {
      final bool? submitted = await showSubscriptionUpgradeDialog(
        context,
        initialSummary: summary,
        initialAdminContact: widget.platformAdminContact,
      );
      if (submitted == true) {
        await widget.onRenewed?.call();
      }
    }

    if (mounted) {
      setState(() => _dialogOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
