import 'package:hosspi_hms/core/workspace/realtime_sync_action.dart';

/// A decoded realtime change that can be applied locally without HTTP.
final class RealtimeDelta {
  const RealtimeDelta({
    required this.action,
    this.entity,
    this.listEntry,
    this.resourceId,
    this.resourceType,
    this.partialFlowSummary,
    this.encounterId,
  });

  final RealtimeSyncAction action;
  final Map<String, Object?>? entity;
  final Map<String, Object?>? listEntry;
  final String? resourceId;
  final String? resourceType;
  final Map<String, Object?>? partialFlowSummary;
  final String? encounterId;

  bool get canApplyLocally {
    if (action == RealtimeSyncAction.invalidate) {
      return false;
    }
    if (entity != null ||
        listEntry != null ||
        (partialFlowSummary != null && encounterId != null)) {
      return true;
    }
    return action == RealtimeSyncAction.remove &&
        resourceId != null &&
        resourceId!.isNotEmpty;
  }
}
