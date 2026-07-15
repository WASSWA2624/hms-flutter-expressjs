import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/access_requirement_l10n.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/actions/app_action_lifecycle.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';

/// Permission-aware async action with [AppActionRunner] lifecycle.
///
/// Controllers supply [mutate] (repository/HTTP). Widgets only trigger the
/// runner. On success [onSuccess] patches Riverpod; cancel/failure leave state
/// unchanged. Retries reuse the same idempotency key.
class AppPermissionAsyncActionButton extends ConsumerStatefulWidget {
  const AppPermissionAsyncActionButton({
    required this.requirement,
    required this.label,
    required this.icon,
    required this.mutate,
    this.onSuccess,
    this.runner,
    this.variant = AppButtonVariant.secondary,
    this.enabled = true,
    this.fullWidth = false,
    this.hideWhenDenied = true,
    this.capabilityAllowed = true,
    this.blockedReason,
    this.semanticLabel,
    this.tooltip,
    this.confirmTitle,
    this.confirmBody,
    this.confirmSubmitLabel,
    this.destructive = false,
    this.onlineOnly = false,
    this.showFailureFeedback = true,
    super.key,
  });

  final AccessRequirement requirement;
  final String label;
  final IconData icon;
  final AppActionMutate mutate;
  final VoidCallback? onSuccess;
  final AppActionRunner? runner;
  final AppButtonVariant variant;
  final bool enabled;
  final bool fullWidth;
  final bool hideWhenDenied;
  final bool capabilityAllowed;
  final String? blockedReason;
  final String? semanticLabel;
  final String? tooltip;
  final String? confirmTitle;
  final String? confirmBody;
  final String? confirmSubmitLabel;
  final bool destructive;

  /// Refuses the mutation while offline (never queues). For payments, refunds,
  /// break-glass, etc.
  final bool onlineOnly;

  /// When true, surfaces retryable failures via a snackbar with Try again.
  final bool showFailureFeedback;

  bool get requiresConfirmation {
    final String? title = confirmTitle?.trim();
    final String? body = confirmBody?.trim();
    return title != null && title.isNotEmpty && body != null && body.isNotEmpty;
  }

  @override
  ConsumerState<AppPermissionAsyncActionButton> createState() =>
      _AppPermissionAsyncActionButtonState();
}

class _AppPermissionAsyncActionButtonState
    extends ConsumerState<AppPermissionAsyncActionButton> {
  late AppActionRunner _runner;
  late bool _ownsRunner;

  @override
  void initState() {
    super.initState();
    _ownsRunner = widget.runner == null;
    _runner = widget.runner ?? AppActionRunner(onlineOnly: widget.onlineOnly);
    _runner.addListener(_onRunnerChanged);
  }

  @override
  void didUpdateWidget(covariant AppPermissionAsyncActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runner != widget.runner) {
      _runner.removeListener(_onRunnerChanged);
      if (_ownsRunner) {
        _runner.dispose();
      }
      _ownsRunner = widget.runner == null;
      _runner = widget.runner ?? AppActionRunner(onlineOnly: widget.onlineOnly);
      _runner.addListener(_onRunnerChanged);
    }
  }

  @override
  void dispose() {
    _runner.removeListener(_onRunnerChanged);
    if (_ownsRunner) {
      _runner.dispose();
    }
    super.dispose();
  }

  void _onRunnerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool? get _isOnline {
    if (!widget.onlineOnly && !_runner.onlineOnly) {
      return null;
    }
    final AsyncValue<AppConnectivityStatus> status = ref.read(
      appConnectivityStatusProvider,
    );
    return status.maybeWhen(
      data: (AppConnectivityStatus value) => value.isOnline,
      orElse: () => true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final policy = ref.watch(appAccessPolicyProvider);
    final bool isAllowed = widget.requirement.isAllowed(policy);

    if (!isAllowed && widget.hideWhenDenied) {
      return const SizedBox.shrink();
    }

    final bool inFlight = _runner.isInFlight;
    final bool canPress =
        widget.enabled &&
        isAllowed &&
        widget.capabilityAllowed &&
        !inFlight &&
        !_runner.snapshot.isBusy;
    final String resolvedTooltip = canPress
        ? (widget.tooltip ?? widget.label)
        : (!isAllowed
              ? accessRequirementDenialMessage(l10n, widget.requirement, policy)
              : (widget.blockedReason ?? widget.tooltip ?? widget.label));

    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AppButton(
      label: widget.label,
      leadingIcon: widget.icon,
      variant: widget.variant,
      enabled: canPress,
      isLoading: inFlight,
      fullWidth: widget.fullWidth,
      semanticLabel: widget.semanticLabel,
      tooltip: resolvedTooltip,
      color: widget.destructive && canPress ? colorScheme.error : null,
      onPressed: canPress ? () => _handlePress(context) : null,
    );
  }

  Future<void> _handlePress(BuildContext context) async {
    if (widget.requiresConfirmation) {
      await _runWithConfirmation(context);
      return;
    }
    await _execute(context, reuseKey: false);
  }

  Future<void> _runWithConfirmation(BuildContext context) async {
    _runner.markConfirming();
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppConfirmActionDialog(
          title: widget.confirmTitle!,
          body: widget.confirmBody!,
          submitLabel: widget.confirmSubmitLabel ?? widget.label,
          destructive: widget.destructive,
          icon: Icon(widget.icon),
          onConfirm: () => _invokeMutate(reuseKey: _runner.canRetry),
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (confirmed != true) {
      // Cancel/failure leave domain state unchanged; clear runner for the next
      // logical press (idempotency key is not reused across abandoned actions).
      _runner.reset();
      return;
    }

    if (_runner.snapshot.isSuccess) {
      widget.onSuccess?.call();
      _runner.reset();
    }
  }

  Future<void> _execute(BuildContext context, {required bool reuseKey}) async {
    final AppFailure? failure = await _invokeMutate(reuseKey: reuseKey);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      widget.onSuccess?.call();
      _runner.reset();
      return;
    }
    if (failure.category == AppFailureCategory.cancelled) {
      return;
    }
    if (widget.showFailureFeedback) {
      _showFailureFeedback(this.context, failure);
    }
  }

  Future<AppFailure?> _invokeMutate({required bool reuseKey}) {
    if (reuseKey) {
      return _runner.retry(widget.mutate, isOnline: _isOnline);
    }
    return _runner.run(widget.mutate, isOnline: _isOnline);
  }

  void _showFailureFeedback(BuildContext context, AppFailure failure) {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.failureMessage(failure)),
        action: failure.isRetryable
            ? SnackBarAction(
                label: l10n.commonRetryActionLabel,
                onPressed: () {
                  if (!context.mounted) {
                    return;
                  }
                  _execute(context, reuseKey: true);
                },
              )
            : null,
      ),
    );
  }
}
