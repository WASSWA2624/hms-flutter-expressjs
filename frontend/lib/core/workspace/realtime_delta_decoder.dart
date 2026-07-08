import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/workspace/realtime_delta.dart';
import 'package:hosspi_hms/core/workspace/realtime_sync_action.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

/// Decodes [RealtimeMessage] payloads into [RealtimeDelta] values.
abstract final class RealtimeDeltaDecoder {
  static RealtimeDelta? tryDecode(RealtimeMessage message) {
    final Map<String, Object?> payload = _effectivePayload(message);
    final RealtimeSyncAction? action = _resolveAction(message.event, payload);
    if (action == null) {
      return null;
    }

    if (action == RealtimeSyncAction.invalidate) {
      return RealtimeDelta(
        action: action,
        resourceId: _string(payload['resource_id']) ?? _string(payload['id']),
        resourceType: _string(payload['resource_type']),
      );
    }

    final Map<String, Object?>? entity = _map(payload['entity']);
    final Map<String, Object?>? listEntry = _map(payload['list_entry']);
    final Map<String, Object?>? flowSummary = _map(payload['flow_summary']);
    final String? encounterId =
        _string(payload['encounter_id']) ??
        _string(payload['encounter_public_id']) ??
        _string(listEntry?['encounter'] is Map
            ? (_map(listEntry!['encounter'])?['id'])
            : null);

    if (entity != null || listEntry != null) {
      return RealtimeDelta(
        action: action,
        entity: entity,
        listEntry: listEntry,
        resourceId:
            _string(entity?['id']) ??
            _string(payload['resource_id']) ??
            _string(payload['queue_id']) ??
            encounterId,
        resourceType: _string(payload['resource_type']),
        encounterId: encounterId,
      );
    }

    if (flowSummary != null && encounterId != null) {
      return RealtimeDelta(
        action: action,
        partialFlowSummary: flowSummary,
        encounterId: encounterId,
        resourceId: encounterId,
        resourceType: 'opd_flow',
      );
    }

    if (_isVisitQueueEvent(message.event)) {
      final Map<String, Object?>? queueEntity = _visitQueueEntityFromPayload(
        payload,
        action,
      );
      if (queueEntity != null) {
        return RealtimeDelta(
          action: action,
          entity: queueEntity,
          resourceId:
              _string(queueEntity['id']) ?? _string(payload['queue_id']),
          resourceType: 'visit_queue',
        );
      }
    }

    return null;
  }

  /// Slices that still need HTTP after a partial local patch.
  static WorkspaceRefreshPlan residualPlan(
    RealtimeMessage message,
    WorkspaceRefreshPlan fallback,
  ) {
    final RealtimeDelta? delta = tryDecode(message);
    if (delta == null || !delta.canApplyLocally) {
      return fallback;
    }

    if (delta.partialFlowSummary != null) {
      return const WorkspaceRefreshPlan(summaryCounts: true);
    }

    if (delta.resourceType == 'visit_queue') {
      return fallback.queue || fallback.flows
          ? WorkspaceRefreshPlan(
              summaryCounts: fallback.summaryCounts,
              flows: fallback.flows,
              triage: fallback.triage,
              selectedDetail: fallback.selectedDetail,
            )
          : WorkspaceRefreshPlan.none;
    }

    return WorkspaceRefreshPlan.none;
  }

  static Map<String, Object?> _effectivePayload(RealtimeMessage message) {
    final Map<String, Object?> outer = Map<String, Object?>.from(
      message.payload,
    );
    final Object? nested = outer['payload'];
    if (nested is Map<String, Object?>) {
      return <String, Object?>{
        ...outer,
        ...nested,
      };
    }
    if (nested is Map<Object?, Object?>) {
      return <String, Object?>{
        ...outer,
        ...Map<String, Object?>.fromEntries(
          nested.entries.where((entry) => entry.key != null).map(
            (entry) => MapEntry<String, Object?>(
              entry.key.toString(),
              entry.value,
            ),
          ),
        ),
      };
    }
    return outer;
  }

  static RealtimeSyncAction? _resolveAction(
    String event,
    Map<String, Object?> payload,
  ) {
    final String? operation = _string(payload['operation'])?.toLowerCase();
    if (operation == 'deleted' || operation == 'canceled') {
      return RealtimeSyncAction.remove;
    }
    if (operation == 'invalidate') {
      return RealtimeSyncAction.invalidate;
    }

    if (event.endsWith('.deleted') || event.contains('_deleted')) {
      return RealtimeSyncAction.remove;
    }
    if (event == RealtimeEvents.appointmentCanceled) {
      return RealtimeSyncAction.remove;
    }
    if (event.endsWith('.created') ||
        event.endsWith('.updated') ||
        event.endsWith('.rescheduled') ||
        event.contains('_changed') ||
        event.contains('_updated')) {
      return RealtimeSyncAction.upsert;
    }
    return RealtimeSyncAction.upsert;
  }

  static bool _isVisitQueueEvent(String event) {
    return event == RealtimeEvents.visitQueueCreated ||
        event == RealtimeEvents.visitQueueUpdated ||
        event == RealtimeEvents.visitQueueDeleted ||
        event == RealtimeEvents.visitQueuePositionChanged ||
        event == RealtimeEvents.visitQueueTriageUpdated;
  }

  static Map<String, Object?>? _visitQueueEntityFromPayload(
    Map<String, Object?> payload,
    RealtimeSyncAction action,
  ) {
    final Map<String, Object?>? entity = _map(payload['entity']);
    if (entity != null) {
      return entity;
    }

    final String? id =
        _string(payload['queue_id']) ?? _string(payload['resource_id']);
    if (id == null || id.isEmpty) {
      return null;
    }

    if (action == RealtimeSyncAction.remove) {
      return <String, Object?>{'id': id};
    }

    final Map<String, Object?> built = <String, Object?>{'id': id};
    for (final String key in <String>[
      'tenant_id',
      'facility_id',
      'patient_id',
      'appointment_id',
      'provider_user_id',
      'status',
      'queued_at',
      'human_friendly_id',
      'queue_public_id',
      'patient_display_name',
      'patient_primary_phone',
      'patient_primary_identifier',
      'provider_display_name',
      'appointment_reason',
      'payment_status',
      'amount_to_pay',
      'amount_paid',
      'currency',
    ]) {
      final Object? value = payload[key];
      if (value != null) {
        built[key] = value;
      }
    }
    if (built['human_friendly_id'] == null &&
        built['queue_public_id'] != null) {
      built['human_friendly_id'] = built['queue_public_id'];
    }
    return built.length > 1 ? built : null;
  }

  static String? _string(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, Object?>? _map(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map<Object?, Object?>) {
      return Map<String, Object?>.fromEntries(
        value.entries
            .where((MapEntry<Object?, Object?> entry) => entry.key != null)
            .map(
              (MapEntry<Object?, Object?> entry) => MapEntry<String, Object?>(
                entry.key.toString(),
                entry.value,
              ),
            ),
      );
    }
    return null;
  }
}
