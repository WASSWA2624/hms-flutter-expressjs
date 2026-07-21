import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/controllers/reception_follow_up_controller.dart';

/// Optional encounter-type scope for clinical Follow-ups worklists.
///
/// Use an empty [encounterType] for hospital-wide lists (Reception). Pass
/// `OPD`, `IPD`, `ICU`, or `THEATRE` for workspace-scoped tabs.
@immutable
final class FollowUpWorklistScope {
  const FollowUpWorklistScope({this.encounterType});

  final String? encounterType;

  String? get normalizedType {
    final String? value = encounterType?.trim().toUpperCase();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  bool operator ==(Object other) {
    return other is FollowUpWorklistScope &&
        other.normalizedType == normalizedType;
  }

  @override
  int get hashCode => normalizedType.hashCode;
}

final scopedFollowUpControllerProvider = FutureProvider.family<
  Result<ReceptionFollowUpState>,
  FollowUpWorklistScope
>((Ref ref, FollowUpWorklistScope scope) async {
  watchSessionEpoch(ref);
  listenForRealtimeRefresh(
    ref: ref,
    events: RealtimeEventGroups.clinical,
    includeCrudMutations: true,
    onRefresh: (_) async {
      ref.invalidateSelf();
    },
  );

  final Result<List<ReceptionFollowUpEntry>> result = await ref
      .read(receptionFollowUpRepositoryProvider)
      .listScheduledFollowUps(encounterType: scope.normalizedType);
  return result.when(
    success: (List<ReceptionFollowUpEntry> entries) {
      final List<ReceptionFollowUpEntry> sorted =
          List<ReceptionFollowUpEntry>.of(entries)
            ..sort(
              (ReceptionFollowUpEntry a, ReceptionFollowUpEntry b) =>
                  a.scheduledAt.compareTo(b.scheduledAt),
            );
      return Result<ReceptionFollowUpState>.success(
        ReceptionFollowUpState(entries: List.unmodifiable(sorted)),
      );
    },
    failure: Result<ReceptionFollowUpState>.failure,
  );
});

/// Scheduled follow-up count for a workspace Follow-ups tab badge.
final followUpTabCountProvider = Provider.family<int?, FollowUpWorklistScope>((
  Ref ref,
  FollowUpWorklistScope scope,
) {
  final AsyncValue<Result<ReceptionFollowUpState>> async = ref.watch(
    scopedFollowUpControllerProvider(scope),
  );
  return async.asData?.value.when(
    success: (ReceptionFollowUpState state) => state.entries.length,
    failure: (_) => null,
  );
});

Future<AppFailure?> refreshScopedFollowUps(
  WidgetRef ref,
  FollowUpWorklistScope scope,
) async {
  ref.invalidate(scopedFollowUpControllerProvider(scope));
  final Result<ReceptionFollowUpState> result = await ref.read(
    scopedFollowUpControllerProvider(scope).future,
  );
  return result.when(
    success: (_) => null,
    failure: (AppFailure failure) => failure,
  );
}
