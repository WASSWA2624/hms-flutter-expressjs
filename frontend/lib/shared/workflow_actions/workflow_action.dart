import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';

/// How a workflow action should be executed when triggered.
enum WorkflowActionMode {
  /// Open an in-context dialog/bottom-sheet over the current page.
  dialog,

  /// Navigate to a targeted route with enough query params to auto-open the
  /// required action at the destination.
  route,

  /// Perform an inline command (e.g. mark-complete) without UI navigation.
  inlineCommand,

  /// Read-only detail view (no mutable action available).
  readOnly,
}

/// Availability state of a workflow action.
enum WorkflowActionAvailability {
  /// The action can be executed by the current user.
  available,

  /// The user lacks the required permission or role.
  permissionDenied,

  /// The required module is not entitled/active for this facility.
  moduleUnavailable,

  /// The action was already completed (stale state).
  alreadyCompleted,

  /// The target record was deleted or cancelled.
  targetUnavailable,

  /// No handler is registered for this action code.
  unsupported,
}

/// Canonical model representing an executable workflow action.
///
/// Contains everything needed to execute the action without module-specific
/// guessing. Created by the [WorkflowActionRegistry] from backend action codes.
@immutable
final class WorkflowAction {
  const WorkflowAction({
    required this.code,
    required this.label,
    required this.icon,
    required this.mode,
    required this.targetModule,
    this.sourceModule,
    this.legacyAliases = const <String>[],
    this.encounterId,
    this.patientId,
    this.admissionId,
    this.orderId,
    this.invoiceId,
    this.queueEntryId,
    this.sourceRecordId,
    this.targetPanel,
    this.targetAction,
    this.accessRequirement,
    this.availability = WorkflowActionAvailability.available,
    this.unavailableReason,
    this.tooltip,
    this.route,
    this.routeQueryParameters = const <String, String>{},
  });

  /// Stable canonical action code (e.g. 'PAY_CONSULTATION').
  final String code;

  /// Human-readable localized label displayed on the button.
  final String label;

  /// Icon displayed alongside the action.
  final IconData icon;

  /// Execution mode determining how the action is presented.
  final WorkflowActionMode mode;

  /// The module that owns and can execute this action.
  final String targetModule;

  /// The module from which this action originates.
  final String? sourceModule;

  /// Backend codes that should be normalized to [code].
  final List<String> legacyAliases;

  // --- Record identifiers ---

  final String? encounterId;
  final String? patientId;
  final String? admissionId;
  final String? orderId;
  final String? invoiceId;
  final String? queueEntryId;
  final String? sourceRecordId;

  // --- Target navigation context ---

  /// Panel/tab identifier at the destination (e.g. 'vitals', 'results').
  final String? targetPanel;

  /// Specific action to auto-open at the destination.
  final String? targetAction;

  /// Route path for [WorkflowActionMode.route] execution.
  final String? route;

  /// Query parameters for route-based navigation.
  final Map<String, String> routeQueryParameters;

  // --- Authorization ---

  /// Permission and module requirements for executing this action.
  final AccessRequirement? accessRequirement;

  // --- Availability ---

  final WorkflowActionAvailability availability;

  /// Localized reason when action is not available.
  final String? unavailableReason;

  /// Tooltip describing the destination or owner.
  final String? tooltip;

  bool get isAvailable => availability == WorkflowActionAvailability.available;

  bool get isPermissionDenied =>
      availability == WorkflowActionAvailability.permissionDenied;

  bool get isUnsupported =>
      availability == WorkflowActionAvailability.unsupported;

  WorkflowAction copyWith({
    String? code,
    String? label,
    IconData? icon,
    WorkflowActionMode? mode,
    String? targetModule,
    String? sourceModule,
    List<String>? legacyAliases,
    String? encounterId,
    String? patientId,
    String? admissionId,
    String? orderId,
    String? invoiceId,
    String? queueEntryId,
    String? sourceRecordId,
    String? targetPanel,
    String? targetAction,
    AccessRequirement? accessRequirement,
    WorkflowActionAvailability? availability,
    String? unavailableReason,
    String? tooltip,
    String? route,
    Map<String, String>? routeQueryParameters,
  }) {
    return WorkflowAction(
      code: code ?? this.code,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      mode: mode ?? this.mode,
      targetModule: targetModule ?? this.targetModule,
      sourceModule: sourceModule ?? this.sourceModule,
      legacyAliases: legacyAliases ?? this.legacyAliases,
      encounterId: encounterId ?? this.encounterId,
      patientId: patientId ?? this.patientId,
      admissionId: admissionId ?? this.admissionId,
      orderId: orderId ?? this.orderId,
      invoiceId: invoiceId ?? this.invoiceId,
      queueEntryId: queueEntryId ?? this.queueEntryId,
      sourceRecordId: sourceRecordId ?? this.sourceRecordId,
      targetPanel: targetPanel ?? this.targetPanel,
      targetAction: targetAction ?? this.targetAction,
      accessRequirement: accessRequirement ?? this.accessRequirement,
      availability: availability ?? this.availability,
      unavailableReason: unavailableReason ?? this.unavailableReason,
      tooltip: tooltip ?? this.tooltip,
      route: route ?? this.route,
      routeQueryParameters: routeQueryParameters ?? this.routeQueryParameters,
    );
  }

  /// Check whether the current user can execute this action.
  WorkflowAction withAccessCheck(AppAccessPolicy policy) {
    if (accessRequirement == null || accessRequirement!.isEmpty) {
      return this;
    }
    if (!accessRequirement!.isAllowed(policy)) {
      return copyWith(
        availability: WorkflowActionAvailability.permissionDenied,
        unavailableReason: 'Requires $targetModule access',
      );
    }
    return this;
  }
}

/// Input context passed when resolving which workflow action to show.
@immutable
final class WorkflowActionContext {
  const WorkflowActionContext({
    required this.encounterId,
    this.patientId,
    this.admissionId,
    this.orderId,
    this.invoiceId,
    this.queueEntryId,
    this.stage,
    this.nextStep,
    this.displayNextStep,
    this.assignedStaffId,
    this.sourceModule,
  });

  final String encounterId;
  final String? patientId;
  final String? admissionId;
  final String? orderId;
  final String? invoiceId;
  final String? queueEntryId;
  final String? stage;
  final String? nextStep;
  final String? displayNextStep;
  final String? assignedStaffId;
  final String? sourceModule;

  /// The effective action code to resolve: prefer displayNextStep → nextStep → stage.
  String get effectiveActionCode =>
      (displayNextStep ?? nextStep ?? stage ?? '').trim().toUpperCase();
}
