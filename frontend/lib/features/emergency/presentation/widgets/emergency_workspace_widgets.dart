import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart';

abstract final class EmergencyText {
  static const String active = 'Active';
  static const String activeCases = 'Active cases';
  static const String all = 'All';
  static const String allBoard = 'All emergency records';
  static const String ambulance = 'Ambulance';
  static const String ambulanceId = 'Ambulance ID';
  static const String arrival = 'Arrival';
  static const String arrivalNotes = 'Arrival notes';
  static const String available = 'Available';
  static const String billingDeferred = 'Billing deferred';
  static const String billingDeferredMessage =
      'Stabilize first — billing for this admission can be completed later in '
      'the Billing workspace.';
  static const String cancel = 'Cancel';
  static const String careBeforeBilling = 'Care before billing';
  static const String caseLabel = 'Case';
  static const String closed = 'Closed';
  static const String closeEmergencyCase = 'Close emergency case';
  static const String closeEmergencyCaseSubtitle =
      'Use this after the receiving unit has accepted the patient.';
  static const String completeTrip = 'Complete trip';
  static const String critical = 'Critical';
  static const String discharge = 'Discharge';
  static const String dispatch = 'Dispatch';
  static const String dispatchAmbulance = 'Dispatch ambulance';
  static const String dispatched = 'Dispatched';
  static const String dispatchStatus = 'Dispatch status';
  static const String enRoute = 'En route';
  static const String facility = 'Facility';
  static const String handoff = 'Handoff';
  static const String handoffDestination = 'Destination';
  static const String handoffNotes = 'Handoff notes';
  static const String handoffOutcome = 'Handoff outcome';
  static const String handoffOutcomeDescription =
      'The receiving workflow created when this case was handed off.';
  static const String handoffReady = 'Handoff ready';
  static const String handoffRecorded = 'Handoff recorded';
  static const String handoffTerminalDescription =
      'This case was closed at handoff. No downstream encounter was created.';
  static const String handoffTime = 'Handoff time';
  static const String high = 'High';
  static const String icu = 'ICU';
  static const String initialTriage = 'Initial triage';
  static const String ipd = 'IPD';
  static const String level1 = 'Level 1';
  static const String level2 = 'Level 2';
  static const String level3 = 'Level 3';
  static const String level4 = 'Level 4';
  static const String level5 = 'Level 5';
  static const String location = 'Location';
  static const String low = 'Low';
  static const String markResponse = 'Mark response';
  static const String medium = 'Medium';
  static const String next = 'Next';
  static const String onScene = 'On scene';
  static const String opd = 'OPD';
  static const String openCase = 'Open case';
  static const String openInPrefix = 'Open in';
  static const String outOfService = 'Out of service';
  static const String receivingReference = 'Receiving reference';
  static const String receivingStage = 'Stage';
  static const String patient = 'Patient';
  static const String patientNumber = 'Patient no.';
  static const String printSummary = 'Print summary';
  static const String priority = 'Priority';
  static const String quickArrival = 'Quick arrival';
  static const String quickEmergencyArrival = 'Quick emergency arrival';
  static const String recordHandoff = 'Record handoff';
  static const String recordTriage = 'Record triage';
  static const String referral = 'Referral';
  static const String required = 'Required';
  static const String responded = 'Responded';
  static const String response = 'Response';
  static const String responseNotes = 'Response notes';
  static const String saveTriage = 'Save triage';
  static const String searchHint = 'Search patient, case, ambulance, or status';
  static const String selectAmbulance = 'Select ambulance';
  static const String startTrip = 'Start trip';
  static const String theater = 'Theater';
  static const String scheduleTheater = 'Schedule in Theater';
  static const String transporting = 'Transporting';
  static const String triage = 'Triage';
  static const String update = 'Update';
  static const String updateDispatchStatus = 'Update dispatch status';
  static const String updatePriority = 'Update priority';
}

AppWorkspaceStatus caseStatus(EmergencyCaseSummary item) {
  final String normalized = (item.status ?? 'OPEN').toUpperCase();
  return AppWorkspaceStatus(
    label: apiLabel(normalized),
    tone: switch (normalized) {
      'CLOSED' || 'COMPLETED' => AppWorkspaceStatusTone.success,
      'CANCELLED' => AppWorkspaceStatusTone.neutral,
      _ => AppWorkspaceStatusTone.info,
    },
  );
}

AppWorkspaceStatus severityStatus(EmergencyCaseSummary item) {
  final String severity = (item.severity ?? 'MEDIUM').toUpperCase();
  return AppWorkspaceStatus(
    label: apiLabel(severity),
    tone: severityTone(severity),
    icon: severity == 'CRITICAL'
        ? Icons.priority_high_outlined
        : Icons.emergency_outlined,
  );
}

AppWorkspaceStatus triageStatus(String? triageLevel) {
  final String level = (triageLevel ?? '').toUpperCase();
  return AppWorkspaceStatus(
    label: level.isEmpty ? 'Triage pending' : apiLabel(level),
    tone: switch (level) {
      'LEVEL_1' => AppWorkspaceStatusTone.error,
      'LEVEL_2' => AppWorkspaceStatusTone.warning,
      '' => AppWorkspaceStatusTone.neutral,
      _ => AppWorkspaceStatusTone.info,
    },
    icon: Icons.monitor_heart_outlined,
  );
}

AppWorkspaceStatus responseStatus(EmergencyCaseSummary item) {
  final bool responded = item.latestResponse != null;
  return AppWorkspaceStatus(
    label: responded ? 'Responded' : 'Awaiting response',
    tone: responded
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.warning,
    icon: responded
        ? Icons.check_circle_outline
        : Icons.notification_important_outlined,
  );
}

AppWorkspaceStatusTone severityTone(String? severity) {
  return switch ((severity ?? '').toUpperCase()) {
    'CRITICAL' => AppWorkspaceStatusTone.error,
    'HIGH' => AppWorkspaceStatusTone.warning,
    'LOW' => AppWorkspaceStatusTone.neutral,
    _ => AppWorkspaceStatusTone.info,
  };
}

AppWorkspaceStatusTone ambulanceTone(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'OUT_OF_SERVICE' => AppWorkspaceStatusTone.error,
    'AVAILABLE' => AppWorkspaceStatusTone.success,
    'TRANSPORTING' ||
    'EN_ROUTE' ||
    'ON_SCENE' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.info,
  };
}

String pageLabel(BuildContext context, AppPage<EmergencyCaseSummary> page) {
  if (page.items.isEmpty) {
    return 'No emergency cases';
  }
  final String visible = '${page.firstItemNumber}-${page.lastItemNumber}';
  final int? total = page.totalItemCount;
  return total == null ? visible : '$visible of ${countLabel(context, total)}';
}

String countLabel(BuildContext context, int value) {
  return AppFormatters.compactNumber(value, Localizations.localeOf(context));
}

int pageTotal<T>(AppPage<T> page) => page.totalItemCount ?? page.items.length;

String dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return 'Not recorded';
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

String apiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

String joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String? nonEmpty(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String? firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String? normalized = nonEmpty(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return null;
}

bool hasTheaterHandoff(EmergencyCaseSummary summary) {
  final String destination = (summary.handoff?.destination ?? '')
      .trim()
      .toUpperCase();
  if (destination != 'THEATER' && destination != 'THEATRE') {
    return false;
  }
  return summary.handoff?.hasReceivingWork ?? false;
}

String normalizedOption(String? value, {required String fallback}) {
  final String normalized = value?.trim().toUpperCase() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

String? requiredText(String? value) {
  return (value ?? '').trim().isEmpty ? EmergencyText.required : null;
}

String? requiredSelect(Object? value) {
  return value == null || value.toString().trim().isEmpty
      ? EmergencyText.required
      : null;
}

String emergencyNextStepCode(EmergencyCaseSummary item) {
  final String normalizedStatus = (item.status ?? '').toUpperCase();
  if (normalizedStatus == 'CLOSED' || normalizedStatus == 'COMPLETED') {
    return 'DISPOSITION';
  }
  if (normalizedStatus == 'CANCELLED') {
    return 'DISPOSITION';
  }
  if (item.latestTriage == null) {
    return 'EMERGENCY_TRIAGE';
  }
  if (item.latestResponse == null) {
    return 'EMERGENCY_STABILIZE';
  }
  return 'EMERGENCY_STABILIZE';
}

Color? rowColor(BuildContext context, EmergencyCaseSummary item) {
  if (!item.isCritical) {
    return null;
  }
  return Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.20);
}

List<AppSelectOption<String>> severityOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'CRITICAL', label: EmergencyText.critical),
    AppSelectOption<String>(value: 'HIGH', label: EmergencyText.high),
    AppSelectOption<String>(value: 'MEDIUM', label: EmergencyText.medium),
    AppSelectOption<String>(value: 'LOW', label: EmergencyText.low),
  ];
}

List<AppSelectOption<String>> triageOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'LEVEL_1', label: EmergencyText.level1),
    AppSelectOption<String>(value: 'LEVEL_2', label: EmergencyText.level2),
    AppSelectOption<String>(value: 'LEVEL_3', label: EmergencyText.level3),
    AppSelectOption<String>(value: 'LEVEL_4', label: EmergencyText.level4),
    AppSelectOption<String>(value: 'LEVEL_5', label: EmergencyText.level5),
  ];
}

List<AppTriageOption> triageActionOptions(
  Iterable<AppSelectOption<String>> options,
) {
  return <AppTriageOption>[
    for (final AppSelectOption<String> option in options)
      AppTriageOption(value: option.value, label: option.label),
  ];
}

List<AppSelectOption<String>> ambulanceStatusOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'DISPATCHED',
      label: EmergencyText.dispatched,
    ),
    AppSelectOption<String>(value: 'EN_ROUTE', label: EmergencyText.enRoute),
    AppSelectOption<String>(value: 'ON_SCENE', label: EmergencyText.onScene),
    AppSelectOption<String>(
      value: 'TRANSPORTING',
      label: EmergencyText.transporting,
    ),
    AppSelectOption<String>(value: 'AVAILABLE', label: EmergencyText.available),
    AppSelectOption<String>(
      value: 'OUT_OF_SERVICE',
      label: EmergencyText.outOfService,
    ),
  ];
}

List<AppSelectOption<String>> handoffOptions() {
  return const <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'OPD', label: EmergencyText.opd),
    AppSelectOption<String>(value: 'IPD', label: EmergencyText.ipd),
    AppSelectOption<String>(value: 'ICU', label: EmergencyText.icu),
    AppSelectOption<String>(value: 'THEATER', label: EmergencyText.theater),
    AppSelectOption<String>(value: 'REFERRAL', label: EmergencyText.referral),
    AppSelectOption<String>(value: 'DISCHARGE', label: EmergencyText.discharge),
  ];
}

String escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String emergencySummaryHtml(BuildContext context, EmergencyCaseDetail detail) {
  final EmergencyCaseSummary summary = detail.summary;
  final StringBuffer buffer = StringBuffer()
    ..writeln(
      PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
        PrintFormMetadataItem(
          label: EmergencyText.caseLabel,
          value: summary.caseLabel,
        ),
        PrintFormMetadataItem(
          label: EmergencyText.patient,
          value: summary.displayTitle,
        ),
        PrintFormMetadataItem(
          label: EmergencyText.patientNumber,
          value: summary.patientDisplayId ?? '',
        ),
        PrintFormMetadataItem(
          label: EmergencyText.facility,
          value: summary.facilityLabel ?? '',
        ),
        PrintFormMetadataItem(
          label: EmergencyText.arrival,
          value: dateTimeLabel(context, summary.createdAt),
        ),
        PrintFormMetadataItem(
          label: EmergencyText.location,
          value: summary.currentLocation,
        ),
      ]),
    );

  final StringBuffer triageBody = StringBuffer();

  if (detail.triageAssessments.isEmpty) {
    triageBody.writeln(
      '<p class="print-template-empty">No triage recorded.</p>',
    );
  } else {
    for (final EmergencyTriageAssessment triage in detail.triageAssessments) {
      triageBody
        ..writeln(
          '<p><strong>${escapeHtml(apiLabel(triage.triageLevel ?? ''))}</strong> ${escapeHtml(dateTimeLabel(context, triage.createdAt))}</p>',
        )
        ..writeln(
          '<p class="print-template-note">${escapeHtml(triage.notes ?? '')}</p>',
        );
    }
  }

  buffer.writeln(
    PrintFormTemplate.section(title: 'Triage', bodyHtml: triageBody.toString()),
  );

  final StringBuffer responseBody = StringBuffer();
  if (detail.responses.isEmpty) {
    responseBody.writeln(
      '<p class="print-template-empty">No response recorded.</p>',
    );
  } else {
    for (final EmergencyResponseRecord response in detail.responses) {
      responseBody
        ..writeln(
          '<p><strong>Response</strong> ${escapeHtml(dateTimeLabel(context, response.responseAt ?? response.createdAt))}</p>',
        )
        ..writeln(
          '<p class="print-template-note">${escapeHtml(response.notes ?? '')}</p>',
        );
    }
  }

  buffer.writeln(
    PrintFormTemplate.section(
      title: 'Response',
      bodyHtml: responseBody.toString(),
    ),
  );

  final StringBuffer ambulanceSection = StringBuffer();
  if (detail.dispatches.isEmpty && detail.trips.isEmpty) {
    ambulanceSection.writeln(
      '<p class="print-template-empty">No ambulance activity recorded.</p>',
    );
  } else {
    for (final EmergencyAmbulanceDispatch dispatch in detail.dispatches) {
      ambulanceSection.writeln(
        '<p>${escapeHtml(joinDisplay(<String?>['Dispatch', dispatch.ambulanceLabel, apiLabel(dispatch.status ?? ''), dateTimeLabel(context, dispatch.dispatchedAt ?? dispatch.createdAt)]))}</p>',
      );
    }
    for (final EmergencyAmbulanceTrip trip in detail.trips) {
      ambulanceSection.writeln(
        '<p>${escapeHtml(joinDisplay(<String?>[trip.isActive ? 'Active trip' : 'Trip complete', trip.ambulanceLabel, dateTimeLabel(context, trip.startedAt), trip.endedAt == null ? null : 'Ended ${dateTimeLabel(context, trip.endedAt)}']))}</p>',
      );
    }
  }

  buffer.writeln(
    PrintFormTemplate.section(
      title: 'Ambulance',
      bodyHtml: ambulanceSection.toString(),
    ),
  );
  return buffer.toString();
}

void showFailureIfNeeded(
  BuildContext context,
  AppFailure? failure, {
  String? successMessage,
}) {
  showAppFailureSnackBar(context, failure);
  if (failure == null && successMessage != null) {
    showAppSuccessSnackBar(context, successMessage);
  }
}

AppListTableColumn<EmergencyCaseSummary> emergencyPatientColumn() {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'patient',
    label: EmergencyText.patient,
    alwaysVisible: true,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(left.displayTitle, right.displayTitle),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return EmergencyCaseCell(item: item);
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyPriorityColumn() {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'priority',
    label: EmergencyText.priority,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(left.severity, right.severity),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return AppWorkspaceStatusBadge(status: severityStatus(item));
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyArrivalColumn() {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'arrival',
    label: EmergencyText.arrival,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareDateTime(left.createdAt, right.createdAt),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return Text(dateTimeLabel(context, item.createdAt));
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyResponseColumn() {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'response',
    label: EmergencyText.response,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(left.responseStatus, right.responseStatus),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return AppWorkspaceStatusBadge(status: responseStatus(item));
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyLocationColumn() {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'location',
    label: EmergencyText.location,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(left.currentLocation, right.currentLocation),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return Text(item.currentLocation);
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyCaseStatusColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'status',
    label: l10n.emergencyStatusColumnLabel,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(left.status, right.status),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return AppWorkspaceStatusBadge(status: caseStatus(item));
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyTriageColumn() {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'triage',
    label: EmergencyText.triage,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(left.triageLevel, right.triageLevel),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return AppWorkspaceStatusBadge(status: triageStatus(item.triageLevel));
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyFacilityColumn() {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'facility',
    label: EmergencyText.facility,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(left.facilityLabel, right.facilityLabel),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return Text(item.facilityLabel ?? '');
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyAmbulanceColumn() {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'ambulance',
    label: EmergencyText.ambulance,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(
          left.latestDispatch?.ambulanceLabel ??
              left.activeTrip?.ambulanceLabel,
          right.latestDispatch?.ambulanceLabel ??
              right.activeTrip?.ambulanceLabel,
        ),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return Text(
        item.latestDispatch?.ambulanceLabel ??
            item.activeTrip?.ambulanceLabel ??
            '',
      );
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyAmbulanceWorkflowStatusColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'status',
    label: l10n.emergencyStatusColumnLabel,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) {
      final String leftValue = left.activeTrip != null
          ? (left.activeTrip!.isActive ? 'IN_TRANSIT' : 'COMPLETE')
          : (left.latestDispatch?.status ?? '');
      final String rightValue = right.activeTrip != null
          ? (right.activeTrip!.isActive ? 'IN_TRANSIT' : 'COMPLETE')
          : (right.latestDispatch?.status ?? '');
      return appListTableCompareText(leftValue, rightValue);
    },
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      final EmergencyAmbulanceTrip? trip = item.activeTrip;
      if (trip != null) {
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: trip.isActive
                ? l10n.emergencyInTransitLabel
                : l10n.emergencyTripCompleteLabel,
            tone: trip.isActive
                ? AppWorkspaceStatusTone.warning
                : AppWorkspaceStatusTone.success,
          ),
        );
      }
      final String? status = item.latestDispatch?.status;
      if (status == null || status.isEmpty) {
        return const SizedBox.shrink();
      }
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: apiLabel(status),
          tone: ambulanceTone(status),
        ),
      );
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyDispatchStatusColumn() {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'dispatch_status',
    label: EmergencyText.dispatchStatus,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(
          left.latestDispatch?.status,
          right.latestDispatch?.status,
        ),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      final String? status = item.latestDispatch?.status;
      if (status == null || status.isEmpty) {
        return const SizedBox.shrink();
      }
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: apiLabel(status),
          tone: ambulanceTone(status),
        ),
      );
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyTripStatusColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'trip_status',
    label: l10n.emergencyTripStatusColumnLabel,
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      final EmergencyAmbulanceTrip? trip = item.activeTrip;
      if (trip == null) {
        return Text(l10n.emergencyNoTripLabel);
      }
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: trip.isActive
              ? l10n.emergencyInTransitLabel
              : l10n.emergencyTripCompleteLabel,
          tone: trip.isActive
              ? AppWorkspaceStatusTone.warning
              : AppWorkspaceStatusTone.success,
        ),
      );
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyHandoffDestinationColumn() {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'handoff_destination',
    label: EmergencyText.handoffDestination,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(
          left.handoff?.destination,
          right.handoff?.destination,
        ),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return Text(apiLabel(item.handoff?.destination ?? ''));
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyClosedAtColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'closed_at',
    label: l10n.emergencyClosedAtColumnLabel,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareDateTime(left.updatedAt, right.updatedAt),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return Text(dateTimeLabel(context, item.updatedAt));
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyNextActionColumn(
  BuildContext context, {
  String? label,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'next_action',
    label: label ?? l10n.emergencyNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(left.nextAction, right.nextAction),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return WorkflowActionButton(
        encounterId: item.id,
        patientId: item.patientId,
        stage: item.status,
        nextStep: emergencyNextStepCode(item),
        sourceModule: 'emergency',
        compact: true,
      );
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyHandoffNextActionColumn(
  BuildContext context, {
  required AccessRequirement writeRequirement,
}) {
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'next_action',
    label: EmergencyText.recordHandoff,
    alwaysVisible: true,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(left.nextAction, right.nextAction),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return EmergencyHandoffActionCell(
        item: item,
        writeRequirement: writeRequirement,
      );
    },
  );
}

AppListTableColumn<EmergencyCaseSummary> emergencyAmbulanceNextActionColumn(
  BuildContext context, {
  required AccessRequirement writeRequirement,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<EmergencyCaseSummary>(
    id: 'next_action',
    label: l10n.emergencyNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (EmergencyCaseSummary left, EmergencyCaseSummary right) =>
        appListTableCompareText(left.nextAction, right.nextAction),
    cellBuilder: (BuildContext context, EmergencyCaseSummary item) {
      return EmergencyAmbulanceActionCell(
        item: item,
        writeRequirement: writeRequirement,
      );
    },
  );
}

bool emergencyTableSearchMatcher(EmergencyCaseSummary item, String query) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  if (item.matchesSearch(query)) {
    return true;
  }

  final EmergencyAmbulanceTrip? trip = item.activeTrip;
  return <String?>[
    item.caseLabel,
    item.displayTitle,
    item.currentLocation,
    item.facilityLabel,
    item.nextAction,
    item.triageLevel,
    item.responseStatus,
    apiLabel(item.status ?? ''),
    apiLabel(item.severity ?? ''),
    apiLabel(item.triageLevel),
    apiLabel(item.latestDispatch?.status ?? ''),
    apiLabel(item.handoff?.destination ?? ''),
    trip == null ? null : (trip.isActive ? 'In transit' : 'Complete'),
    item.createdAt?.toIso8601String(),
    item.updatedAt?.toIso8601String(),
  ].whereType<String>().any(
    (String value) => value.toLowerCase().contains(needle),
  );
}

Widget emergencyMobileListItem(
  BuildContext context,
  WidgetRef ref,
  EmergencyCaseSummary item, {
  required EmergencyBoardTab tab,
  required AccessRequirement writeRequirement,
}) {
  final ThemeData theme = Theme.of(context);
  final String contextLine = switch (tab) {
    EmergencyBoardTab.critical ||
    EmergencyBoardTab.closed ||
    EmergencyBoardTab.ambulance => dateTimeLabel(context, item.createdAt),
    _ => item.currentLocation,
  };

  return Padding(
    padding: EdgeInsets.symmetric(
      horizontal: theme.spacing.sm,
      vertical: theme.spacing.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        EmergencyCaseCell(item: item),
        SizedBox(height: theme.spacing.sm),
        Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            AppWorkspaceStatusBadge(status: severityStatus(item)),
            AppWorkspaceStatusBadge(
              status: tab == EmergencyBoardTab.ambulance
                  ? _ambulanceWorkflowStatus(context, item)
                  : caseStatus(item),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        Text(contextLine, style: theme.textTheme.bodySmall),
        SizedBox(height: theme.spacing.sm),
        switch (tab) {
          EmergencyBoardTab.ambulance => EmergencyAmbulanceActionCell(
            item: item,
            writeRequirement: writeRequirement,
          ),
          EmergencyBoardTab.handoff => EmergencyHandoffActionCell(
            item: item,
            writeRequirement: writeRequirement,
          ),
          EmergencyBoardTab.closed => const SizedBox.shrink(),
          _ => WorkflowActionButton(
            encounterId: item.id,
            patientId: item.patientId,
            stage: item.status,
            nextStep: emergencyNextStepCode(item),
            sourceModule: 'emergency',
            compact: true,
          ),
        },
      ],
    ),
  );
}

AppWorkspaceStatus _ambulanceWorkflowStatus(
  BuildContext context,
  EmergencyCaseSummary item,
) {
  final AppLocalizations l10n = context.l10n;
  final EmergencyAmbulanceTrip? trip = item.activeTrip;
  if (trip != null) {
    return AppWorkspaceStatus(
      label: trip.isActive
          ? l10n.emergencyInTransitLabel
          : l10n.emergencyTripCompleteLabel,
      tone: trip.isActive
          ? AppWorkspaceStatusTone.warning
          : AppWorkspaceStatusTone.success,
    );
  }
  final String? status = item.latestDispatch?.status;
  if (status == null || status.isEmpty) {
    return caseStatus(item);
  }
  return AppWorkspaceStatus(
    label: apiLabel(status),
    tone: ambulanceTone(status),
  );
}

class EmergencyHandoffActionCell extends ConsumerWidget {
  const EmergencyHandoffActionCell({
    required this.item,
    required this.writeRequirement,
    this.compact = true,
    super.key,
  });

  final EmergencyCaseSummary item;
  final AccessRequirement writeRequirement;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppAccessActionGate(
      requirement: writeRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppButton.primary(
          label: EmergencyText.recordHandoff,
          leadingIcon: Icons.output_outlined,
          enabled: isAllowed && item.isOpen,
          onPressed: isAllowed && item.isOpen
              ? () => unawaited(_openHandoff(context, ref))
              : null,
        );
      },
    );
  }

  Future<void> _openHandoff(BuildContext context, WidgetRef ref) async {
    final EmergencyWorkspaceController controller = ref.read(
      emergencyWorkspaceControllerProvider.notifier,
    );
    final AppFailure? selectFailure = await controller.selectCase(item);
    if (!context.mounted) {
      return;
    }
    if (selectFailure != null) {
      showFailureIfNeeded(context, selectFailure);
      return;
    }

    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HandoffDialog(
        onSubmit: (HandoffInput input) {
          return controller.handoff(
            destination: input.destination,
            notes: input.notes,
            closeCase: input.closeCase,
          );
        },
      ),
    );
    if (saved == true && context.mounted) {
      showFailureIfNeeded(
        context,
        null,
        successMessage: EmergencyText.handoffRecorded,
      );
    }
  }
}

class EmergencyAmbulanceActionCell extends ConsumerWidget {
  const EmergencyAmbulanceActionCell({
    required this.item,
    required this.writeRequirement,
    this.compact = true,
    super.key,
  });

  final EmergencyCaseSummary item;
  final AccessRequirement writeRequirement;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.latestTriage == null || item.latestResponse == null) {
      return WorkflowActionButton(
        encounterId: item.id,
        patientId: item.patientId,
        stage: item.status,
        nextStep: emergencyNextStepCode(item),
        sourceModule: 'emergency',
        compact: compact,
      );
    }

    final EmergencyWorkspaceState? state = readEmergencyState(ref);
    final EmergencyReferenceData referenceData =
        state?.referenceData ?? const EmergencyReferenceData();

    if (item.activeTrip != null) {
      return AppAccessActionGate(
        requirement: writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return AppButton.primary(
            label: EmergencyText.completeTrip,
            leadingIcon: Icons.flag_outlined,
            enabled: isAllowed,
            onPressed: isAllowed
                ? () => unawaited(_completeTrip(context, ref))
                : null,
          );
        },
      );
    }

    if (item.latestDispatch == null) {
      return AppAccessActionGate(
        requirement: writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return AppButton.primary(
            label: EmergencyText.dispatch,
            leadingIcon: Icons.airport_shuttle_outlined,
            enabled: isAllowed && item.isOpen,
            onPressed: isAllowed && item.isOpen
                ? () => unawaited(_openDispatch(context, ref, referenceData))
                : null,
          );
        },
      );
    }

    return AppAccessActionGate(
      requirement: writeRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppButton.primary(
          label: EmergencyText.startTrip,
          leadingIcon: Icons.play_arrow_outlined,
          enabled: isAllowed && item.isOpen,
          onPressed: isAllowed && item.isOpen
              ? () => unawaited(_startTrip(context, ref, referenceData))
              : null,
        );
      },
    );
  }

  Future<void> _ensureCaseSelected(BuildContext context, WidgetRef ref) async {
    final AppFailure? failure = await ref
        .read(emergencyWorkspaceControllerProvider.notifier)
        .selectCase(item);
    if (context.mounted && failure != null) {
      showFailureIfNeeded(context, failure);
    }
  }

  Future<void> _openDispatch(
    BuildContext context,
    WidgetRef ref,
    EmergencyReferenceData referenceData,
  ) async {
    await _ensureCaseSelected(context, ref);
    if (!context.mounted) {
      return;
    }

    final bool? saved = await showEmergencyDispatchDialog(
      context: context,
      referenceData: referenceData,
      onSubmit: (DispatchInput input) {
        return ref
            .read(emergencyWorkspaceControllerProvider.notifier)
            .dispatchAmbulance(
              ambulanceId: input.ambulanceId,
              status: input.status,
            );
      },
    );
    if (saved == true && context.mounted) {
      showFailureIfNeeded(
        context,
        null,
        successMessage: 'Ambulance dispatched',
      );
    }
  }

  Future<void> _startTrip(
    BuildContext context,
    WidgetRef ref,
    EmergencyReferenceData referenceData,
  ) async {
    await _ensureCaseSelected(context, ref);
    if (!context.mounted) {
      return;
    }

    final EmergencyWorkspaceController controller = ref.read(
      emergencyWorkspaceControllerProvider.notifier,
    );
    String? ambulanceId = item.latestDispatch?.ambulanceId;
    if (ambulanceId == null && referenceData.availableAmbulances.length == 1) {
      ambulanceId = referenceData.availableAmbulances.first.id;
    }
    if (ambulanceId == null) {
      final bool? saved = await showEmergencyDispatchDialog(
        context: context,
        referenceData: referenceData,
        title: EmergencyText.selectAmbulance,
        submitLabel: EmergencyText.startTrip,
        defaultStatus: 'EN_ROUTE',
        onSubmit: (DispatchInput input) {
          return controller.startAmbulanceTrip(
            ambulanceId: input.ambulanceId,
          );
        },
      );
      if (saved == true && context.mounted) {
        showFailureIfNeeded(context, null, successMessage: 'Trip started');
      }
      return;
    }

    final AppFailure? failure = await controller.startAmbulanceTrip(
      ambulanceId: ambulanceId,
    );
    if (context.mounted) {
      showFailureIfNeeded(context, failure, successMessage: 'Trip started');
    }
  }

  Future<void> _completeTrip(BuildContext context, WidgetRef ref) async {
    await _ensureCaseSelected(context, ref);
    if (!context.mounted) {
      return;
    }

    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AppConfirmActionDialog(
        title: 'Complete ambulance trip',
        body: 'This records ambulance arrival for the active emergency trip.',
        submitLabel: 'Complete trip',
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final AppFailure? failure = await ref
        .read(emergencyWorkspaceControllerProvider.notifier)
        .completeTrip();
    if (context.mounted) {
      showFailureIfNeeded(
        context,
        failure,
        successMessage: 'Complete trip done',
      );
    }
  }
}

class EmergencyCaseCell extends StatelessWidget {
  const EmergencyCaseCell({required this.item, super.key});

  final EmergencyCaseSummary item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          item.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          joinDisplay(<String?>[item.patientDisplayId, item.caseLabel]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class EmergencyDetailPanel extends ConsumerWidget {
  const EmergencyDetailPanel({
    required this.state,
    required this.writeRequirement,
    this.isDialog = false,
    super.key,
  });

  final EmergencyWorkspaceState state;
  final AccessRequirement writeRequirement;
  final bool isDialog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EmergencyCaseDetail? detail = state.selectedDetail;
    if (state.isRefreshingDetail && detail == null) {
      return const AppWorkspaceStatePanel.loading(
        title: 'Loading emergency case',
        body: 'Loading triage, response, and ambulance activity.',
      );
    }
    if (detail == null) {
      return const AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: 'No case selected',
        body:
            'Select an emergency case to record triage, ambulance activity, response, or handoff.',
        icon: Icons.emergency_outlined,
      );
    }

    final EmergencyCaseSummary summary = detail.summary;
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPatientDetails(
          patientName: summary.displayTitle,
          patientNumber: summary.patientDisplayId ?? '',
          ageLabel: summary.patientLabel,
          showAvatar: false,
          status: caseStatus(summary),
          alerts: <AppWorkspaceStatus>[
            severityStatus(summary),
            if (detail.latestTriage != null)
              triageStatus(detail.latestTriage!.triageLevel),
            if (summary.isOpen)
              const AppWorkspaceStatus(
                label: EmergencyText.careBeforeBilling,
                tone: AppWorkspaceStatusTone.info,
                icon: Icons.bolt_outlined,
              ),
            if (summary.handoff?.billingDeferred ?? false)
              const AppWorkspaceStatus(
                label: EmergencyText.billingDeferred,
                tone: AppWorkspaceStatusTone.warning,
                icon: Icons.payments_outlined,
              ),
          ],
          expandedFields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: EmergencyText.caseLabel,
              value: summary.displayId ?? '',
              icon: Icons.tag_outlined,
              copyable: true,
              copyTooltip: l10n.copyIdentifierAction,
              copiedMessage: l10n.identifierCopiedMessage,
            ),
            AppWorkspacePatientContextField(
              label: EmergencyText.arrival,
              value: dateTimeLabel(context, summary.createdAt),
              icon: Icons.event_available_outlined,
            ),
            AppWorkspacePatientContextField(
              label: EmergencyText.facility,
              value: summary.facilityLabel ?? '',
              icon: Icons.domain_outlined,
            ),
            AppWorkspacePatientContextField(
              label: EmergencyText.location,
              value: summary.currentLocation,
              icon: Icons.place_outlined,
            ),
          ],
        ),
        if (summary.handoff != null) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          EmergencyHandoffOutcomePanel(
            outcome: summary.handoff!,
            isDialog: isDialog,
          ),
        ],
        SizedBox(height: theme.spacing.md),
        EmergencyActionPanel(
          detail: detail,
          referenceData: state.referenceData,
          writeRequirement: writeRequirement,
        ),
        SizedBox(height: theme.spacing.md),
        EmergencyTimelinePanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        AmbulancePanel(detail: detail),
      ],
    );
  }
}

class EmergencyActionPanel extends ConsumerWidget {
  const EmergencyActionPanel({
    required this.detail,
    required this.referenceData,
    required this.writeRequirement,
    super.key,
  });

  static const AccessRequirement _handoffRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.emergencyWrite,
      AppPermissions.patientWrite,
      AppPermissions.clinicalWrite,
      AppPermissions.operationsWrite,
    ],
  );

  final EmergencyCaseDetail detail;
  final EmergencyReferenceData referenceData;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EmergencyWorkspaceController controller = ref.read(
      emergencyWorkspaceControllerProvider.notifier,
    );
    final bool hasDispatch = detail.latestDispatch != null;
    final bool hasTrip = detail.activeTrip != null;
    final bool canStartTrip =
        !hasTrip &&
        (detail.latestDispatch?.ambulanceId != null ||
            referenceData.availableAmbulances.isNotEmpty);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWriteEmergency = writeRequirement.isAllowed(accessPolicy);
    final bool canHandoff = _handoffRequirement.isAllowed(accessPolicy);

    return AppActionPanel(
      title: 'Actions',
      actions: <AppActionItem>[
        AppActionItem(
          label: EmergencyText.priority,
          leadingIcon: Icons.priority_high_outlined,
          enabled: canWriteEmergency && detail.summary.isOpen,
          onPressed: () => _openPriorityDialog(context),
        ),
        AppActionItem(
          label: EmergencyText.triage,
          leadingIcon: Icons.monitor_heart_outlined,
          enabled: canWriteEmergency && detail.summary.isOpen,
          onPressed: () => _openTriageDialog(context),
        ),
        AppActionItem(
          label: EmergencyText.response,
          leadingIcon: Icons.medical_services_outlined,
          enabled: canWriteEmergency && detail.summary.isOpen,
          onPressed: () => _openResponseDialog(context),
        ),
        AppActionItem(
          label: EmergencyText.dispatch,
          leadingIcon: Icons.airport_shuttle_outlined,
          enabled: canWriteEmergency && detail.summary.isOpen,
          onPressed: () => _openDispatchDialog(context, referenceData),
        ),
        AppActionItem(
          label: EmergencyText.dispatchStatus,
          leadingIcon: Icons.route_outlined,
          enabled: canWriteEmergency && detail.summary.isOpen && hasDispatch,
          onPressed: () => _openDispatchStatusDialog(context),
        ),
        AppActionItem(
          label: EmergencyText.startTrip,
          leadingIcon: Icons.play_arrow_outlined,
          enabled: canWriteEmergency && detail.summary.isOpen && canStartTrip,
          onPressed: () => _startTrip(context, referenceData),
        ),
        AppActionItem(
          label: EmergencyText.completeTrip,
          leadingIcon: Icons.flag_outlined,
          enabled: canWriteEmergency && hasTrip,
          onPressed: () => _confirmAction(
            context: context,
            title: 'Complete ambulance trip',
            body:
                'This records ambulance arrival for the active emergency trip.',
            actionLabel: 'Complete trip',
            onConfirmed: controller.completeTrip,
          ),
        ),
        AppActionItem(
          label: EmergencyText.handoff,
          leadingIcon: Icons.output_outlined,
          enabled: canHandoff && detail.summary.isOpen,
          onPressed: () => _openHandoffDialog(context),
        ),
        AppActionItem(
          label: EmergencyText.scheduleTheater,
          leadingIcon: Icons.meeting_room_outlined,
          enabled:
              canWriteEmergency &&
              detail.summary.isOpen &&
              !hasTheaterHandoff(detail.summary),
          onPressed: () => _openTheaterSchedule(context, detail.summary),
        ),
      ],
      extraActions: <Widget>[
        AppReportActionButton.print(
          label: EmergencyText.printSummary,
          onPressed: () async {
            await printFormTemplateDocument(
              ref: ref,
              context: context,
              title: 'Emergency summary',
              patientContext: buildPrintFormPatientContext(
                context.l10n,
                patientName: detail.summary.displayTitle,
                patientId:
                    detail.summary.patientId ?? detail.summary.patientDisplayId,
              ),
              contextReference: PrintFormContextReference(
                label: EmergencyText.caseLabel,
                value: detail.summary.caseLabel,
              ),
              bodyHtml: emergencySummaryHtml(context, detail),
              includeSignatures: true,
            );
          },
        ),
      ],
    );
  }

  Future<void> _openPriorityDialog(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppSelectActionDialog<String>(
        title: EmergencyText.priority,
        icon: const Icon(Icons.priority_high_outlined),
        fieldLabel: EmergencyText.priority,
        initialValue: normalizedOption(
          detail.summary.severity,
          fallback: 'HIGH',
        ),
        options: severityOptions(),
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.patientsEditAction,
        requiredMessage: l10n.validationRequired,
        submitLeadingIcon: AppActionIcons.edit,
        onSubmit: (String severity) {
          return _controller(context).updatePriority(severity);
        },
      ),
    );
    if (saved != true || !context.mounted) {
      return;
    }

    showFailureIfNeeded(context, null, successMessage: 'Priority updated');
  }

  Future<void> _openTriageDialog(BuildContext context) async {
    final EmergencyWorkspaceController controller = _controller(context);
    final bool? changed = await showAppTriageActionDialog<bool>(
      context: context,
      builder: (_) => AppTriageActionDialog(
        title: EmergencyText.recordTriage,
        submitLabel: EmergencyText.saveTriage,
        requiredMessage: EmergencyText.required,
        triageLevelLabel: 'Triage level',
        triageLevelOptions: triageActionOptions(triageOptions()),
        initialTriageLevel: normalizedOption(
          detail.latestTriage?.triageLevel,
          fallback: 'LEVEL_2',
        ),
        notesLabel: 'Triage notes',
        initialNotes: detail.latestTriage?.notes,
        onSubmit: (AppTriageActionInput input) {
          return controller.recordTriage(
            triageLevel: input.triageLevel ?? 'LEVEL_2',
            notes: input.notes,
          );
        },
      ),
    );
    if (changed != true || !context.mounted) {
      return;
    }

    showFailureIfNeeded(context, null, successMessage: 'Triage recorded');
  }

  Future<void> _openResponseDialog(BuildContext context) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppTextActionDialog(
        title: EmergencyText.response,
        icon: const Icon(Icons.medical_services_outlined),
        fieldLabel: EmergencyText.responseNotes,
        submitLabel: EmergencyText.markResponse,
        submitLeadingIcon: AppActionIcons.save,
        onSubmit: (String notes) {
          return _controller(context).markResponse(notes: notes);
        },
      ),
    );
    if (saved != true || !context.mounted) {
      return;
    }

    showFailureIfNeeded(context, null, successMessage: 'Response marked');
  }

  Future<void> _openDispatchDialog(
    BuildContext context,
    EmergencyReferenceData referenceData,
  ) async {
    final EmergencyWorkspaceController controller = _controller(context);
    final bool? saved = await showEmergencyDispatchDialog(
      context: context,
      referenceData: referenceData,
      onSubmit: (DispatchInput input) {
        return controller.dispatchAmbulance(
          ambulanceId: input.ambulanceId,
          status: input.status,
        );
      },
    );
    if (saved == true && context.mounted) {
      showFailureIfNeeded(
        context,
        null,
        successMessage: 'Ambulance dispatched',
      );
    }
  }

  Future<void> _openDispatchStatusDialog(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    final EmergencyWorkspaceController controller = _controller(context);
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppSelectActionDialog<String>(
        title: EmergencyText.updateDispatchStatus,
        icon: const Icon(Icons.route_outlined),
        fieldLabel: EmergencyText.dispatchStatus,
        initialValue: normalizedOption(
          detail.latestDispatch?.status,
          fallback: 'EN_ROUTE',
        ),
        options: ambulanceStatusOptions(),
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: EmergencyText.update,
        requiredMessage: EmergencyText.required,
        submitLeadingIcon: AppActionIcons.edit,
        onSubmit: (String status) {
          return controller.updateLatestDispatchStatus(status);
        },
      ),
    );
    if (saved == true && context.mounted) {
      showFailureIfNeeded(
        context,
        null,
        successMessage: 'Dispatch status updated',
      );
    }
  }

  Future<void> _startTrip(
    BuildContext context,
    EmergencyReferenceData referenceData,
  ) async {
    final EmergencyWorkspaceController controller = _controller(context);
    String? ambulanceId = detail.latestDispatch?.ambulanceId;
    if (ambulanceId == null && referenceData.availableAmbulances.length == 1) {
      ambulanceId = referenceData.availableAmbulances.first.id;
    }
    if (ambulanceId == null) {
      final bool? saved = await showEmergencyDispatchDialog(
        context: context,
        referenceData: referenceData,
        title: EmergencyText.selectAmbulance,
        submitLabel: EmergencyText.startTrip,
        defaultStatus: 'EN_ROUTE',
        onSubmit: (DispatchInput input) {
          return controller.startAmbulanceTrip(
            ambulanceId: input.ambulanceId,
          );
        },
      );
      if (saved == true && context.mounted) {
        showFailureIfNeeded(context, null, successMessage: 'Trip started');
      }
      return;
    }

    final AppFailure? failure = await controller.startAmbulanceTrip(
      ambulanceId: ambulanceId,
    );
    if (context.mounted) {
      showFailureIfNeeded(context, failure, successMessage: 'Trip started');
    }
  }

  void _openTheaterSchedule(
    BuildContext context,
    EmergencyCaseSummary summary,
  ) {
    final String? patientId = firstNonEmpty(<String?>[
      summary.patientDisplayId,
      summary.patientId,
    ]);
    final String? emergencyCaseId = firstNonEmpty(<String?>[
      summary.displayId,
      summary.id,
    ]);
    if (emergencyCaseId == null) {
      return;
    }
    final Map<String, String> queryParameters = <String, String>{
      'action': 'schedule',
      'emergency_case_id': emergencyCaseId,
      'patient_id': ?patientId,
    };
    context.go(AppRoutes.theater.location(queryParameters: queryParameters));
  }

  Future<void> _openHandoffDialog(BuildContext context) async {
    final EmergencyWorkspaceController controller = _controller(context);
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HandoffDialog(
        onSubmit: (HandoffInput input) {
          return controller.handoff(
            destination: input.destination,
            notes: input.notes,
            closeCase: input.closeCase,
          );
        },
      ),
    );
    if (saved == true && context.mounted) {
      showFailureIfNeeded(
        context,
        null,
        successMessage: EmergencyText.handoffRecorded,
      );
    }
  }

  Future<void> _confirmAction({
    required BuildContext context,
    required String title,
    required String body,
    required String actionLabel,
    required Future<AppFailure?> Function() onConfirmed,
  }) async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppConfirmActionDialog(
        title: title,
        body: body,
        submitLabel: actionLabel,
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final AppFailure? failure = await onConfirmed();
    if (context.mounted) {
      showFailureIfNeeded(
        context,
        failure,
        successMessage: '$actionLabel done',
      );
    }
  }

  EmergencyWorkspaceController _controller(BuildContext context) {
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(emergencyWorkspaceControllerProvider.notifier);
  }
}

class EmergencyHandoffOutcomePanel extends StatelessWidget {
  const EmergencyHandoffOutcomePanel({
    required this.outcome,
    this.isDialog = false,
    super.key,
  });

  final EmergencyHandoffOutcome outcome;
  final bool isDialog;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String moduleName = _moduleName(outcome.destination);
    final bool canOpen = outcome.hasReceivingWork;

    final List<AppInfoTileData> tiles = <AppInfoTileData>[
      AppInfoTileData(
        label: EmergencyText.handoffDestination,
        value: moduleName,
        icon: Icons.alt_route_outlined,
      ),
      if ((outcome.receivingDisplayId ?? '').trim().isNotEmpty)
        AppInfoTileData(
          label: EmergencyText.receivingReference,
          value: outcome.receivingDisplayId,
          icon: Icons.tag_outlined,
          copyable: true,
        ),
      if ((outcome.stage ?? '').trim().isNotEmpty)
        AppInfoTileData(
          label: EmergencyText.receivingStage,
          value: apiLabel(outcome.stage ?? ''),
          icon: Icons.timeline_outlined,
        ),
      if (outcome.handoffAt != null)
        AppInfoTileData(
          label: EmergencyText.handoffTime,
          value: dateTimeLabel(context, outcome.handoffAt),
          icon: Icons.schedule_outlined,
        ),
    ];

    return AppWorkspaceDetailPanel(
      title: EmergencyText.handoffOutcome,
      description: outcome.terminal
          ? EmergencyText.handoffTerminalDescription
          : EmergencyText.handoffOutcomeDescription,
      actions: <Widget>[
        if (canOpen)
          AppButton.primary(
            label: _openInModuleLabel(moduleName),
            leadingIcon: Icons.open_in_new_outlined,
            onPressed: () => _openReceivingModule(context),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppInfoTileGrid(items: tiles),
          if (outcome.billingDeferred) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            const AppMessagePanel(
              tone: AppWorkspaceStatusTone.warning,
              icon: Icons.payments_outlined,
              title: EmergencyText.billingDeferred,
              message: EmergencyText.billingDeferredMessage,
            ),
          ],
          if ((outcome.notes ?? '').trim().isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(EmergencyText.handoffNotes, style: theme.textTheme.labelLarge),
            SizedBox(height: theme.spacing.xs),
            Text(outcome.notes!.trim(), style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Future<void> _openReceivingModule(BuildContext context) async {
    final String? link = outcome.receivingDeepLink;
    if (link == null) {
      return;
    }
    if (isDialog && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (context.mounted) {
      context.go(link);
    }
  }

  static String _moduleName(String destination) {
    return switch (destination.toUpperCase()) {
      'OPD' => EmergencyText.opd,
      'IPD' => EmergencyText.ipd,
      'ICU' => EmergencyText.icu,
      'THEATER' || 'THEATRE' => EmergencyText.theater,
      'REFERRAL' => EmergencyText.referral,
      'DISCHARGE' => EmergencyText.discharge,
      _ => apiLabel(destination),
    };
  }

  static String _openInModuleLabel(String moduleName) {
    return '${EmergencyText.openInPrefix} $moduleName';
  }
}

class EmergencyTimelinePanel extends StatelessWidget {
  const EmergencyTimelinePanel({required this.detail, super.key});

  final EmergencyCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: 'Triage and response',
      description: 'Clinical activity linked to this emergency case.',
      child: AppTimeline(
        emptyTitle: 'No triage or response recorded',
        asActivityList: true,
        items: <AppTimelineItem>[
          for (final EmergencyTriageAssessment item in detail.triageAssessments)
            AppTimelineItem(
              title: joinDisplay(<String?>[
                'Triage',
                apiLabel(item.triageLevel ?? ''),
              ]),
              subtitle: dateTimeLabel(context, item.createdAt),
              description: item.notes,
              occurredAt:
                  item.updatedAt ??
                  item.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              icon: Icons.monitor_heart_outlined,
              tone: triageStatus(item.triageLevel).tone,
            ),
          for (final EmergencyResponseRecord item in detail.responses)
            AppTimelineItem(
              title: EmergencyText.response,
              subtitle: dateTimeLabel(
                context,
                item.responseAt ?? item.createdAt,
              ),
              description: (item.notes ?? '').trim().isEmpty
                  ? EmergencyText.responded
                  : item.notes,
              occurredAt:
                  item.responseAt ??
                  item.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              icon: Icons.medical_services_outlined,
              tone: AppWorkspaceStatusTone.success,
            ),
        ],
      ),
    );
  }
}

class AmbulancePanel extends StatelessWidget {
  const AmbulancePanel({required this.detail, super.key});

  final EmergencyCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: 'Ambulance',
      description: 'Dispatch and trip activity for this emergency case.',
      child: AppTimeline(
        emptyTitle: 'No ambulance activity recorded',
        asActivityList: true,
        items: <AppTimelineItem>[
          for (final EmergencyAmbulanceDispatch item in detail.dispatches)
            AppTimelineItem(
              title: joinDisplay(<String?>[
                'Dispatch',
                item.ambulanceLabel ??
                    item.ambulanceDisplayId ??
                    item.ambulanceId,
              ]),
              subtitle: dateTimeLabel(
                context,
                item.dispatchedAt ?? item.createdAt,
              ),
              occurredAt:
                  item.dispatchedAt ??
                  item.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              icon: Icons.airport_shuttle_outlined,
              tone: ambulanceTone(item.status),
            ),
          for (final EmergencyAmbulanceTrip item in detail.trips)
            AppTimelineItem(
              title: joinDisplay(<String?>[
                item.isActive ? 'Active trip' : 'Trip complete',
                item.ambulanceLabel ??
                    item.ambulanceDisplayId ??
                    item.ambulanceId,
              ]),
              subtitle: joinDisplay(<String?>[
                dateTimeLabel(context, item.startedAt),
                item.endedAt == null
                    ? null
                    : 'Ended ${dateTimeLabel(context, item.endedAt)}',
              ]),
              occurredAt:
                  item.endedAt ??
                  item.startedAt ??
                  item.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              icon: Icons.route_outlined,
              tone: item.isActive
                  ? AppWorkspaceStatusTone.warning
                  : AppWorkspaceStatusTone.success,
            ),
        ],
      ),
    );
  }
}

Future<void> openEmergencyDetailDialog(
  BuildContext context,
  WidgetRef ref,
  EmergencyWorkspaceState fallbackState,
  EmergencyCaseSummary summary,
  AccessRequirement writeRequirement,
) async {
  final EmergencyWorkspaceController controller = ref.read(
    emergencyWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectCase(summary);
  if (context.mounted) {
    showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final EmergencyWorkspaceState state =
      readEmergencyState(ref) ?? fallbackState;
  if (state.selectedDetail == null) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.emergencyCaseDialogTitle),
      icon: const Icon(Icons.emergency_outlined),
      scrollable: true,
      maxWidth: 980,
      content: EmergencyDetailPanel(
        state: state,
        writeRequirement: writeRequirement,
        isDialog: true,
      ),
    ),
  );
}

EmergencyWorkspaceState? readEmergencyState(WidgetRef ref) {
  return ref
      .read(emergencyWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (EmergencyWorkspaceState state) => state,
        failure: (_) => null,
      );
}
