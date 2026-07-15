import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action.dart';

/// Definition of how to handle a specific workflow action code.
@immutable
final class WorkflowActionDefinition {
  const WorkflowActionDefinition({
    required this.code,
    this.legacyAliases = const <String>[],
    required this.labelBuilder,
    required this.icon,
    required this.targetModule,
    required this.mode,
    this.accessRequirement,
    required this.routeBuilder,
    this.panelId,
    this.actionId,
    this.tooltipBuilder,
  });

  final String code;
  final List<String> legacyAliases;
  final String Function(AppLocalizations l10n) labelBuilder;
  final IconData icon;
  final String targetModule;
  final WorkflowActionMode mode;
  final AccessRequirement? accessRequirement;
  final String Function(WorkflowActionContext ctx) routeBuilder;
  final String? panelId;
  final String? actionId;
  final String Function(AppLocalizations l10n)? tooltipBuilder;
}

/// Central registry of all workflow action handlers.
///
/// Each registered action defines its canonical code, accepted legacy aliases,
/// localized label, icon, authorization requirements, execution strategy, and
/// route/dialog builder.
///
/// The registry fails visibly in debug mode when an active backend action code
/// has no handler. In production, it returns a controlled unavailable state.
final class WorkflowActionRegistry {
  WorkflowActionRegistry._();

  static final WorkflowActionRegistry instance = WorkflowActionRegistry._();

  final Map<String, WorkflowActionDefinition> _definitions =
      <String, WorkflowActionDefinition>{};
  final Map<String, String> _aliasIndex = <String, String>{};

  /// Register a new action definition. Overwrites existing registrations for
  /// the same code.
  void register(WorkflowActionDefinition definition) {
    _definitions[definition.code] = definition;
    for (final String alias in definition.legacyAliases) {
      _aliasIndex[alias] = definition.code;
    }
  }

  /// Register multiple definitions at once.
  void registerAll(Iterable<WorkflowActionDefinition> definitions) {
    for (final WorkflowActionDefinition def in definitions) {
      register(def);
    }
  }

  /// Resolve a raw action code (possibly a legacy alias) to its canonical code.
  String canonicalize(String rawCode) {
    final String normalized = rawCode.trim().toUpperCase();
    return _aliasIndex[normalized] ?? normalized;
  }

  /// Look up the definition for a canonical code.
  WorkflowActionDefinition? definitionFor(String canonicalCode) {
    return _definitions[canonicalCode];
  }

  /// Resolve a workflow action context into an executable [WorkflowAction].
  ///
  /// Returns a fully-populated action with route, label, icon, access
  /// requirement, and availability. Applies authorization check via [policy].
  WorkflowAction? resolve(
    BuildContext context,
    WorkflowActionContext actionContext, {
    AppAccessPolicy? policy,
  }) {
    final String rawCode = actionContext.effectiveActionCode;
    if (rawCode.isEmpty) return null;

    final String canonical = canonicalize(rawCode);
    final WorkflowActionDefinition? definition = _definitions[canonical];

    if (definition == null) {
      if (kDebugMode) {
        debugPrint(
          '[WorkflowActionRegistry] No handler for action code: $canonical '
          '(raw: $rawCode, encounter: ${actionContext.encounterId})',
        );
      }
      return WorkflowAction(
        code: canonical,
        label: _fallbackLabel(canonical),
        icon: Icons.arrow_forward_outlined,
        mode: WorkflowActionMode.route,
        targetModule: 'unknown',
        availability: WorkflowActionAvailability.unsupported,
        unavailableReason: 'No handler registered for "$canonical"',
        encounterId: actionContext.encounterId,
        patientId: actionContext.patientId,
      );
    }

    final AppLocalizations l10n = context.l10n;
    final String route = definition.routeBuilder(actionContext);

    WorkflowAction action = WorkflowAction(
      code: canonical,
      label: definition.labelBuilder(l10n),
      icon: definition.icon,
      mode: definition.mode,
      targetModule: definition.targetModule,
      sourceModule: actionContext.sourceModule,
      legacyAliases: definition.legacyAliases,
      encounterId: actionContext.encounterId,
      patientId: actionContext.patientId,
      admissionId: actionContext.admissionId,
      orderId: actionContext.orderId,
      invoiceId: actionContext.invoiceId,
      queueEntryId: actionContext.queueEntryId,
      targetPanel: definition.panelId,
      targetAction: definition.actionId,
      accessRequirement: definition.accessRequirement,
      route: route,
      tooltip: definition.tooltipBuilder?.call(l10n),
    );

    if (policy != null) {
      action = action.withAccessCheck(policy);
    }

    return action;
  }

  /// All registered canonical action codes.
  Iterable<String> get registeredCodes => _definitions.keys;

  /// Whether a canonical or alias code is registered.
  bool isRegistered(String code) {
    final String normalized = code.trim().toUpperCase();
    final String canonical = _aliasIndex[normalized] ?? normalized;
    return _definitions.containsKey(canonical);
  }

  String _fallbackLabel(String code) {
    return code
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map(
          (String word) =>
              word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

// ---------------------------------------------------------------------------
// Default action definitions
// ---------------------------------------------------------------------------

/// Initialize the global action registry with all known workflow actions.
///
/// Call once during app bootstrap (e.g. in main.dart or a startup service).
void initializeWorkflowActionRegistry() {
  final WorkflowActionRegistry registry = WorkflowActionRegistry.instance;
  registry.registerAll(_billingActions);
  registry.registerAll(_nursingActions);
  registry.registerAll(_doctorAssignmentActions);
  registry.registerAll(_clinicalActions);
  registry.registerAll(_labActions);
  registry.registerAll(_radiologyActions);
  registry.registerAll(_pharmacyActions);
  registry.registerAll(_dispositionActions);
  registry.registerAll(_admissionActions);
  registry.registerAll(_ipdActions);
  registry.registerAll(_dischargeActions);
  registry.registerAll(_emergencyActions);
  registry.registerAll(_theatreActions);
  registry.registerAll(_physiotherapyActions);
  registry.registerAll(_insuranceActions);
  registry.registerAll(_roomsBedActions);
}

// --- Billing ---

final List<WorkflowActionDefinition> _billingActions = <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'PAY_CONSULTATION',
    legacyAliases: const <String>[
      'WAITING_CONSULTATION_PAYMENT',
      'PAYMENT_DUE',
      'CONSULTATION_PAYMENT_PENDING',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdPayConsultationAction,
    icon: Icons.payments_outlined,
    targetModule: 'billing',
    mode: WorkflowActionMode.dialog,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
      ],
      activeModules: <String>['billing-payments'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.billing.location(
      queryParameters: <String, String>{
        'encounter': ctx.encounterId,
        if (ctx.invoiceId != null) 'invoice': ctx.invoiceId!,
        'action': 'pay',
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationBillingLabel,
  ),
  WorkflowActionDefinition(
    code: 'PAY_SERVICE',
    legacyAliases: const <String>['SERVICE_PAYMENT_DUE'],
    labelBuilder: (AppLocalizations l10n) => l10n.opdPayConsultationAction,
    icon: Icons.payments_outlined,
    targetModule: 'billing',
    mode: WorkflowActionMode.dialog,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
      ],
      activeModules: <String>['billing-payments'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.billing.location(
      queryParameters: <String, String>{
        'encounter': ctx.encounterId,
        if (ctx.invoiceId != null) 'invoice': ctx.invoiceId!,
        'action': 'pay',
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationBillingLabel,
  ),
];

// --- Nursing / Vitals ---

final List<WorkflowActionDefinition> _nursingActions = <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'RECORD_VITALS',
    legacyAliases: const <String>[
      'WAITING_VITALS',
      'VITALS_NEEDED',
      'VITALS_PENDING',
      'TRIAGE_PENDING',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdRecordVitalsAction,
    icon: Icons.monitor_heart_outlined,
    targetModule: 'nursing',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      ],
      activeModules: <String>['encounters-vitals'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.nursing.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        'panel': 'vitals',
      },
    ),
    panelId: 'vitals',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationNursingLabel,
  ),
  WorkflowActionDefinition(
    code: 'NURSING_ASSESSMENT',
    legacyAliases: const <String>['NURSING_CARE_PLAN', 'NURSING_TASK'],
    labelBuilder: (AppLocalizations l10n) => l10n.opdRecordVitalsAction,
    icon: Icons.monitor_heart_outlined,
    targetModule: 'nursing',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      ],
      activeModules: <String>['encounters-vitals'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.nursing.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        'panel': 'assessment',
      },
    ),
    panelId: 'assessment',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationNursingLabel,
  ),
];

// --- Doctor Assignment ---

final List<WorkflowActionDefinition> _doctorAssignmentActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'ASSIGN_DOCTOR',
    legacyAliases: const <String>[
      'WAITING_DOCTOR_ASSIGNMENT',
      'DOCTOR_NEEDED',
      'AWAITING_DOCTOR',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdAssignDoctorAction,
    icon: Icons.assignment_ind_outlined,
    targetModule: 'opd',
    mode: WorkflowActionMode.dialog,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.patientRead,
      ],
      activeModules: <String>['scheduling-queue'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.opd.location(
      queryParameters: <String, String>{
        'flowId': ctx.encounterId,
        'panel': 'DOCTOR',
      },
    ),
    panelId: 'DOCTOR',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationOpdLabel,
  ),
];

// --- Clinical / Doctor Review ---

final List<WorkflowActionDefinition> _clinicalActions = <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'DOCTOR_REVIEW',
    legacyAliases: const <String>[
      'WAITING_DOCTOR_REVIEW',
      'WITH_DOCTOR',
      'CLINICAL_REVIEW',
      'DOCTOR_CONSULTATION',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdDoctorReviewAction,
    icon: Icons.edit_note_outlined,
    targetModule: 'clinical',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      ],
      activeModules: <String>['encounters-vitals'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.clinical.location(
      queryParameters: <String, String>{'encounterId': ctx.encounterId},
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationClinicalLabel,
  ),
  WorkflowActionDefinition(
    code: 'REVIEW_RESULTS',
    legacyAliases: const <String>['RESULTS_READY', 'LAB_RESULTS_READY'],
    labelBuilder: (AppLocalizations l10n) => l10n.opdReviewResultsAction,
    icon: Icons.biotech_outlined,
    targetModule: 'clinical',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.labRead,
      ],
      activeModules: <String>['encounters-vitals'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.clinical.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        'panel': 'results',
      },
    ),
    panelId: 'results',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationClinicalLabel,
  ),
  WorkflowActionDefinition(
    code: 'REVIEW_REPORT',
    legacyAliases: const <String>['REPORT_READY', 'IMAGING_REPORT_READY'],
    labelBuilder: (AppLocalizations l10n) => l10n.opdReviewReportAction,
    icon: Icons.image_outlined,
    targetModule: 'clinical',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.radiologyRead,
      ],
      activeModules: <String>['encounters-vitals'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.clinical.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        'panel': 'imaging',
      },
    ),
    panelId: 'imaging',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationClinicalLabel,
  ),
  WorkflowActionDefinition(
    code: 'MEDICINES_DISPENSED',
    legacyAliases: const <String>['MEDICATION_COMPLETE'],
    labelBuilder: (AppLocalizations l10n) => l10n.opdMedicinesDispensedAction,
    icon: Icons.task_alt_outlined,
    targetModule: 'clinical',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      ],
      activeModules: <String>['encounters-vitals'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.clinical.location(
      queryParameters: <String, String>{'encounterId': ctx.encounterId},
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationClinicalLabel,
  ),
];

// --- Laboratory ---

final List<WorkflowActionDefinition> _labActions = <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'COLLECT_SAMPLE',
    legacyAliases: const <String>[
      'PROCESS_LAB',
      'LAB_WORKSPACE',
      'LAB_REQUESTED',
      'LAB_PENDING',
      'SAMPLE_PENDING',
      'IN_LAB',
      'LAB_ORDER_CREATED',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdCollectSampleAction,
    icon: Icons.science_outlined,
    targetModule: 'laboratory',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.labRead,
        AppPermissions.labWrite,
      ],
      activeModules: <String>['lab-workflows'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.lab.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        if (ctx.orderId != null) 'orderId': ctx.orderId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationLabLabel,
  ),
  WorkflowActionDefinition(
    code: 'LAB_AND_RADIOLOGY_REQUESTED',
    legacyAliases: const <String>['DIAGNOSTICS_PENDING'],
    labelBuilder: (AppLocalizations l10n) => l10n.opdDiagnosticsPendingAction,
    icon: Icons.science_outlined,
    targetModule: 'laboratory',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.labRead,
        AppPermissions.labWrite,
      ],
      activeModules: <String>['lab-workflows'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.lab.location(
      queryParameters: <String, String>{'encounterId': ctx.encounterId},
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationLabLabel,
  ),
];

// --- Radiology ---

final List<WorkflowActionDefinition> _radiologyActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'PERFORM_IMAGING',
    legacyAliases: const <String>[
      'COMPLETE_IMAGING_REPORT',
      'RADIOLOGY_WORKSPACE',
      'RADIOLOGY_REQUESTED',
      'IMAGING_PENDING',
      'REPORT_PENDING',
      'RADIOLOGY_ORDER_CREATED',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdPerformImagingAction,
    icon: Icons.image_search_outlined,
    targetModule: 'radiology',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.radiologyRead,
        AppPermissions.radiologyWrite,
      ],
      activeModules: <String>['radiology-workflows'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.radiology.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        if (ctx.orderId != null) 'orderId': ctx.orderId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationRadiologyLabel,
  ),
];

// --- Pharmacy ---

final List<WorkflowActionDefinition> _pharmacyActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'DISPENSE_MEDICINE',
    legacyAliases: const <String>[
      'PHARMACY_WORKSPACE',
      'PHARMACY_REQUESTED',
      'PHARMACY_PENDING',
      'PRESCRIPTION_READY',
      'AWAITING_DISPENSING',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdDispenseMedicineAction,
    icon: Icons.medication_outlined,
    targetModule: 'pharmacy',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.pharmacyRead,
        AppPermissions.pharmacyWrite,
      ],
      activeModules: <String>['pharmacy-dispensing'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.pharmacy.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        if (ctx.orderId != null) 'orderId': ctx.orderId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationPharmacyLabel,
  ),
];

// --- Disposition ---

final List<WorkflowActionDefinition> _dispositionActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'DISPOSITION',
    legacyAliases: const <String>[
      'DECISION_NEEDED',
      'WAITING_DISPOSITION',
      'ENCOUNTER_COMPLETE',
      'CLOSE_ENCOUNTER',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdDispositionAction,
    icon: Icons.task_alt_outlined,
    targetModule: 'clinical',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      ],
      activeModules: <String>['encounters-vitals'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.clinical.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        'panel': 'disposition',
      },
    ),
    panelId: 'disposition',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationClinicalLabel,
  ),
];

// --- Admission / IPD ---

final List<WorkflowActionDefinition> _admissionActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'ADMISSION_HANDOFF',
    legacyAliases: const <String>[
      'ADMISSION_PENDING',
      'ADMIT_PATIENT',
      'IPD_ADMISSION',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdAdmissionHandoffAction,
    icon: Icons.bed_outlined,
    targetModule: 'ipd',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsRead,
      ],
      activeModules: <String>['inpatient-bed-management'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.ipd.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationIpdLabel,
  ),
  WorkflowActionDefinition(
    code: 'ADMITTED',
    legacyAliases: const <String>['IN_IPD', 'IPD_ACTIVE'],
    labelBuilder: (AppLocalizations l10n) => l10n.opdAdmittedAction,
    icon: Icons.bed_outlined,
    targetModule: 'ipd',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsRead,
      ],
      activeModules: <String>['inpatient-bed-management'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.ipd.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationIpdLabel,
  ),
];

// --- IPD (Inpatient) ---

final List<WorkflowActionDefinition> _ipdActions = <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'APPROVE_ADMISSION',
    legacyAliases: const <String>['ADMISSION_REQUESTED'],
    labelBuilder: (AppLocalizations l10n) => l10n.opdAdmissionHandoffAction,
    icon: Icons.how_to_reg_outlined,
    targetModule: 'ipd',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsRead,
      ],
      activeModules: <String>['inpatient-bed-management'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.ipd.location(
      queryParameters: <String, String>{
        if (ctx.encounterId.isNotEmpty) 'encounterId': ctx.encounterId,
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
        'action': 'approve',
      },
    ),
    actionId: 'approve',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationIpdLabel,
  ),
  WorkflowActionDefinition(
    code: 'RECORD_NURSING_NOTE',
    legacyAliases: const <String>['NURSING_NOTE_PENDING'],
    labelBuilder: (AppLocalizations l10n) => l10n.ipdNextRecordNursingNote,
    icon: Icons.note_add_outlined,
    targetModule: 'nursing',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      ],
      activeModules: <String>['inpatient-bed-management'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.nursing.location(
      queryParameters: <String, String>{
        if (ctx.encounterId.isNotEmpty) 'encounterId': ctx.encounterId,
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
        'panel': 'notes',
      },
    ),
    panelId: 'notes',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationNursingLabel,
  ),
  WorkflowActionDefinition(
    code: 'APPROVE_TRANSFER',
    legacyAliases: const <String>['TRANSFER_APPROVAL_PENDING'],
    labelBuilder: (AppLocalizations l10n) => l10n.ipdNextApproveTransfer,
    icon: Icons.swap_horiz_outlined,
    targetModule: 'ipd',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsWrite,
      ],
      activeModules: <String>['inpatient-bed-management'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.ipd.location(
      queryParameters: <String, String>{
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
        if (ctx.encounterId.isNotEmpty) 'encounterId': ctx.encounterId,
        'panel': 'transfers',
        'action': 'approve',
      },
    ),
    panelId: 'transfers',
    actionId: 'approve',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationIpdLabel,
  ),
  WorkflowActionDefinition(
    code: 'START_TRANSFER',
    legacyAliases: const <String>['TRANSFER_PENDING'],
    labelBuilder: (AppLocalizations l10n) => l10n.ipdNextStartTransfer,
    icon: Icons.swap_horiz_outlined,
    targetModule: 'ipd',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsWrite,
      ],
      activeModules: <String>['inpatient-bed-management'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.ipd.location(
      queryParameters: <String, String>{
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
        if (ctx.encounterId.isNotEmpty) 'encounterId': ctx.encounterId,
        'panel': 'transfers',
        'action': 'start',
      },
    ),
    panelId: 'transfers',
    actionId: 'start',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationIpdLabel,
  ),
  WorkflowActionDefinition(
    code: 'COMPLETE_TRANSFER',
    legacyAliases: const <String>['TRANSFER_IN_PROGRESS'],
    labelBuilder: (AppLocalizations l10n) => l10n.ipdNextCompleteTransfer,
    icon: Icons.swap_horiz_outlined,
    targetModule: 'ipd',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsWrite,
      ],
      activeModules: <String>['inpatient-bed-management'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.ipd.location(
      queryParameters: <String, String>{
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
        if (ctx.encounterId.isNotEmpty) 'encounterId': ctx.encounterId,
        'panel': 'transfers',
        'action': 'complete',
      },
    ),
    panelId: 'transfers',
    actionId: 'complete',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationIpdLabel,
  ),
  WorkflowActionDefinition(
    code: 'COMPLETE_THEATRE_HANDOVER',
    legacyAliases: const <String>['THEATRE_HANDOVER_PENDING'],
    labelBuilder: (AppLocalizations l10n) =>
        l10n.ipdNextCompleteTheatreHandover,
    icon: Icons.event_note_outlined,
    targetModule: 'theater',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsRead,
      ],
      activeModules: <String>['operating-theater'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.theater.location(
      queryParameters: <String, String>{
        if (ctx.encounterId.isNotEmpty) 'encounterId': ctx.encounterId,
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
        'action': 'handover',
      },
    ),
    actionId: 'handover',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationTheaterLabel,
  ),
  WorkflowActionDefinition(
    code: 'FINALIZE_DISCHARGE',
    legacyAliases: const <String>['DISCHARGE_CLEARANCE_PENDING'],
    labelBuilder: (AppLocalizations l10n) => l10n.ipdNextFinalizeDischarge,
    icon: Icons.exit_to_app_outlined,
    targetModule: 'discharge',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      ],
      activeModules: <String>['inpatient-bed-management'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.discharge.location(
      queryParameters: <String, String>{
        if (ctx.encounterId.isNotEmpty) 'encounterId': ctx.encounterId,
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationDischargeLabel,
  ),
];

// --- Discharge ---

final List<WorkflowActionDefinition> _dischargeActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'DISCHARGE_PLANNING',
    legacyAliases: const <String>[
      'DISCHARGE_PENDING',
      'AWAITING_DISCHARGE',
      'PLAN_DISCHARGE',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdDischargeAction,
    icon: Icons.exit_to_app_outlined,
    targetModule: 'discharge',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      ],
      activeModules: <String>['inpatient-bed-management'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.discharge.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationDischargeLabel,
  ),
];

// --- Emergency ---

final List<WorkflowActionDefinition> _emergencyActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'EMERGENCY_TRIAGE',
    legacyAliases: const <String>[
      'ER_TRIAGE',
      'EMERGENCY_ASSESSMENT',
      'ER_ASSESSMENT',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdRecordVitalsAction,
    icon: Icons.emergency_outlined,
    targetModule: 'emergency',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
      ],
      activeModules: <String>['scheduling-queue'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.emergency.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        'panel': 'triage',
      },
    ),
    panelId: 'triage',
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationEmergencyLabel,
  ),
  WorkflowActionDefinition(
    code: 'EMERGENCY_STABILIZE',
    legacyAliases: const <String>['ER_STABILIZE', 'RESUSCITATION'],
    labelBuilder: (AppLocalizations l10n) => l10n.opdDoctorReviewAction,
    icon: Icons.emergency_outlined,
    targetModule: 'emergency',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
      ],
      activeModules: <String>['scheduling-queue'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.emergency.location(
      queryParameters: <String, String>{'encounterId': ctx.encounterId},
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationEmergencyLabel,
  ),
];

// --- Theatre / Operating Theatre ---

final List<WorkflowActionDefinition> _theatreActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'THEATRE_SCHEDULING',
    legacyAliases: const <String>[
      'SCHEDULE_THEATRE',
      'OT_SCHEDULING',
      'SURGERY_SCHEDULING',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdTheatreSchedulingAction,
    icon: Icons.event_note_outlined,
    targetModule: 'theater',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsRead,
      ],
      activeModules: <String>['operating-theater'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.theater.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        if (ctx.orderId != null) 'caseId': ctx.orderId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationTheaterLabel,
  ),
  WorkflowActionDefinition(
    code: 'THEATRE_IN_PROGRESS',
    legacyAliases: const <String>[
      'IN_THEATRE',
      'SURGERY_IN_PROGRESS',
      'OT_IN_PROGRESS',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdTheatreSchedulingAction,
    icon: Icons.event_note_outlined,
    targetModule: 'theater',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsRead,
      ],
      activeModules: <String>['operating-theater'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.theater.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        if (ctx.orderId != null) 'caseId': ctx.orderId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationTheaterLabel,
  ),
];

// --- Physiotherapy ---

final List<WorkflowActionDefinition> _physiotherapyActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'PHYSIOTHERAPY_SESSION',
    legacyAliases: const <String>[
      'PHYSIO_REFERRAL',
      'PHYSIO_SESSION',
      'PHYSIOTHERAPY_REFERRAL',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdPhysiotherapyAction,
    icon: Icons.accessibility_new_outlined,
    targetModule: 'physiotherapy',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      ],
      activeModules: <String>['physiotherapy'],
    ),
    routeBuilder: (WorkflowActionContext ctx) =>
        AppRoutes.physiotherapy.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        if (ctx.orderId != null) 'sessionId': ctx.orderId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) =>
        l10n.navigationPhysiotherapyLabel,
  ),
];

// --- Insurance ---

final List<WorkflowActionDefinition> _insuranceActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'INSURANCE_PREAUTH',
    legacyAliases: const <String>[
      'PRE_AUTHORIZATION',
      'PREAUTH_PENDING',
      'AWAITING_PREAUTH',
      'INSURANCE_VERIFICATION',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdInsurancePreauthAction,
    icon: Icons.verified_user_outlined,
    targetModule: 'claims',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
      ],
      activeModules: <String>['insurance-claims'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.claims.location(
      queryParameters: <String, String>{
        'encounter': ctx.encounterId,
        if (ctx.patientId != null) 'patient': ctx.patientId!,
        'action': 'preauth',
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationClaimsLabel,
  ),
];

// --- Rooms & Beds ---

final List<WorkflowActionDefinition> _roomsBedActions =
    <WorkflowActionDefinition>[
  WorkflowActionDefinition(
    code: 'ASSIGN_BED',
    legacyAliases: const <String>[
      'BED_ASSIGNMENT_REQUIRED',
      'ROOM_ASSIGNMENT',
      'AWAITING_BED',
    ],
    labelBuilder: (AppLocalizations l10n) => l10n.opdAssignBedAction,
    icon: Icons.single_bed_outlined,
    targetModule: 'rooms_beds',
    mode: WorkflowActionMode.route,
    accessRequirement: const AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.operationsRead,
        AppPermissions.operationsWrite,
      ],
      activeModules: <String>['inpatient-bed-management'],
    ),
    routeBuilder: (WorkflowActionContext ctx) => AppRoutes.roomsBeds.location(
      queryParameters: <String, String>{
        'encounterId': ctx.encounterId,
        if (ctx.admissionId != null) 'admissionId': ctx.admissionId!,
        if (ctx.patientId != null) 'patientId': ctx.patientId!,
      },
    ),
    tooltipBuilder: (AppLocalizations l10n) => l10n.navigationRoomsBedsLabel,
  ),
];
