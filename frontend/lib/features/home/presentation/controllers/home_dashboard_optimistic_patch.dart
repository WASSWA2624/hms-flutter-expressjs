import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

final homeDashboardOptimisticPatchProvider =
    StateProvider.family<HomeDashboardOptimisticPatchState?, HomeDashboardRequest>(
      (Ref ref, HomeDashboardRequest request) => null,
    );

/// Snapshot captured when a patch is first applied.
final class HomeDashboardOptimisticPatchState {
  const HomeDashboardOptimisticPatchState({
    required this.patch,
    required this.baseline,
  });

  final HomeDashboardOptimisticPatch patch;
  final HomeDashboard baseline;

  HomeDashboardOptimisticPatchState mergePatch(
    HomeDashboardOptimisticPatch nextPatch,
  ) {
    return HomeDashboardOptimisticPatchState(
      patch: patch.merge(nextPatch),
      baseline: baseline,
    );
  }

  bool isSatisfiedBy(HomeDashboard server) {
    if (patch.isEmpty) {
      return true;
    }

    final HomeDashboard expected = patch.applyTo(baseline);
    return _dashboardMetricsMatch(expected, server);
  }
}

bool _dashboardMetricsMatch(HomeDashboard left, HomeDashboard right) {
  for (final HomeStatusCard card in left.statusCards) {
    HomeStatusCard? other;
    for (final HomeStatusCard entry in right.statusCards) {
      if (entry.id == card.id) {
        other = entry;
        break;
      }
    }
    if (other == null) {
      continue;
    }
    if (other.value != card.value) {
      return false;
    }

    final num leftSecondary = card.secondaryValue ?? card.value;
    final num rightSecondary = other.secondaryValue ?? other.value;
    if (leftSecondary != rightSecondary) {
      return false;
    }
  }

  for (final HomeAlertItem alert in left.alerts) {
    HomeAlertItem? other;
    for (final HomeAlertItem entry in right.alerts) {
      if (entry.id == alert.id) {
        other = entry;
        break;
      }
    }
    if (other == null) {
      continue;
    }
    if (other.count != alert.count) {
      return false;
    }
  }

  return true;
}

/// Local count adjustments applied before HTTP refresh completes.
final class HomeDashboardOptimisticPatch {
  const HomeDashboardOptimisticPatch({
    this.statusCardValueDeltas = const <String, int>{},
    this.statusCardSecondaryDeltas = const <String, int>{},
    this.alertCountDeltas = const <String, int>{},
  });

  final Map<String, int> statusCardValueDeltas;
  final Map<String, int> statusCardSecondaryDeltas;
  final Map<String, int> alertCountDeltas;

  bool get isEmpty {
    return statusCardValueDeltas.isEmpty &&
        statusCardSecondaryDeltas.isEmpty &&
        alertCountDeltas.isEmpty;
  }

  factory HomeDashboardOptimisticPatch.tenantCreated({bool isActive = true}) {
    return HomeDashboardOptimisticPatch(
      statusCardValueDeltas: isActive
          ? const <String, int>{'tenants_active': 1}
          : const <String, int>{},
      statusCardSecondaryDeltas: const <String, int>{
        'tenants_active': 1,
        'subscriptions_health': 1,
      },
      alertCountDeltas: const <String, int>{'tenants_without_subscription': 1},
    );
  }

  factory HomeDashboardOptimisticPatch.tenantDeleted({bool isActive = true}) {
    return HomeDashboardOptimisticPatch(
      statusCardValueDeltas: isActive
          ? const <String, int>{'tenants_active': -1}
          : const <String, int>{},
      statusCardSecondaryDeltas: const <String, int>{
        'tenants_active': -1,
        'subscriptions_health': -1,
      },
    );
  }

  factory HomeDashboardOptimisticPatch.tenantActiveChanged({
    required bool wasActive,
    required bool isActive,
  }) {
    if (wasActive == isActive) {
      return const HomeDashboardOptimisticPatch();
    }

    final int sign = isActive ? 1 : -1;
    return HomeDashboardOptimisticPatch(
      statusCardValueDeltas: <String, int>{'tenants_active': sign},
    );
  }

  factory HomeDashboardOptimisticPatch.facilityCreated({bool isActive = true}) {
    return HomeDashboardOptimisticPatch(
      statusCardValueDeltas: isActive
          ? const <String, int>{'facilities_active': 1}
          : const <String, int>{},
      statusCardSecondaryDeltas: const <String, int>{'facilities_active': 1},
    );
  }

  factory HomeDashboardOptimisticPatch.facilityDeleted({bool isActive = true}) {
    return HomeDashboardOptimisticPatch(
      statusCardValueDeltas: isActive
          ? const <String, int>{'facilities_active': -1}
          : const <String, int>{},
      statusCardSecondaryDeltas: const <String, int>{'facilities_active': -1},
    );
  }

  HomeDashboardOptimisticPatch merge(HomeDashboardOptimisticPatch other) {
    return HomeDashboardOptimisticPatch(
      statusCardValueDeltas: _mergeMaps(
        statusCardValueDeltas,
        other.statusCardValueDeltas,
      ),
      statusCardSecondaryDeltas: _mergeMaps(
        statusCardSecondaryDeltas,
        other.statusCardSecondaryDeltas,
      ),
      alertCountDeltas: _mergeMaps(alertCountDeltas, other.alertCountDeltas),
    );
  }

  static HomeDashboardOptimisticPatch? fromRealtimePayload(
    Map<String, Object?> payload,
  ) {
    final Map<String, Object?>? deltas = _map(payload['dashboard_deltas']);
    if (deltas == null || deltas.isEmpty) {
      return null;
    }

    final Map<String, int> valueDeltas = <String, int>{};
    final Map<String, int> secondaryDeltas = <String, int>{};
    final Map<String, int> alertDeltas = <String, int>{};

    final Map<String, Object?>? statusCards = _map(deltas['status_cards']);
    if (statusCards != null) {
      for (final MapEntry<String, Object?> entry in statusCards.entries) {
        final Map<String, Object?>? cardDelta = _map(entry.value);
        if (cardDelta == null) {
          continue;
        }
        final int? valueDelta = _int(cardDelta['value_delta']);
        final int? secondaryDelta = _int(cardDelta['secondary_delta']);
        if (valueDelta != null && valueDelta != 0) {
          valueDeltas[entry.key] = valueDelta;
        }
        if (secondaryDelta != null && secondaryDelta != 0) {
          secondaryDeltas[entry.key] = secondaryDelta;
        }
      }
    }

    final Map<String, Object?>? alerts = _map(deltas['alerts']);
    if (alerts != null) {
      for (final MapEntry<String, Object?> entry in alerts.entries) {
        final Map<String, Object?>? alertDelta = _map(entry.value);
        final int? countDelta = _int(alertDelta?['count_delta']);
        if (countDelta != null && countDelta != 0) {
          alertDeltas[entry.key] = countDelta;
        }
      }
    }

    if (valueDeltas.isEmpty && secondaryDeltas.isEmpty && alertDeltas.isEmpty) {
      return null;
    }

    return HomeDashboardOptimisticPatch(
      statusCardValueDeltas: valueDeltas,
      statusCardSecondaryDeltas: secondaryDeltas,
      alertCountDeltas: alertDeltas,
    );
  }

  HomeDashboard applyTo(HomeDashboard dashboard) {
    if (isEmpty) {
      return dashboard;
    }

    final List<HomeStatusCard> statusCards = dashboard.statusCards
        .map((HomeStatusCard card) {
          final int valueDelta = statusCardValueDeltas[card.id] ?? 0;
          final int secondaryDelta = statusCardSecondaryDeltas[card.id] ?? 0;
          if (valueDelta == 0 && secondaryDelta == 0) {
            return card;
          }

          return HomeStatusCard(
            id: card.id,
            label: card.label,
            value: card.value + valueDelta,
            secondaryValue: card.secondaryValue == null && secondaryDelta == 0
                ? null
                : (card.secondaryValue ?? card.value) + secondaryDelta,
            hint: card.hint,
            format: card.format,
          );
        })
        .toList(growable: false);

    final List<HomeAlertItem> alerts = dashboard.alerts
        .map((HomeAlertItem alert) {
          final int countDelta = alertCountDeltas[alert.id] ?? 0;
          if (countDelta == 0) {
            return alert;
          }

          return HomeAlertItem(
            id: alert.id,
            label: alert.label,
            severity: alert.severity,
            count: (alert.count + countDelta).clamp(0, 1 << 30),
            target: alert.target,
          );
        })
        .toList(growable: false);

    return dashboard.copyWith(statusCards: statusCards, alerts: alerts);
  }

  static Map<String, int> _mergeMaps(
    Map<String, int> left,
    Map<String, int> right,
  ) {
    if (left.isEmpty) {
      return Map<String, int>.from(right);
    }
    if (right.isEmpty) {
      return Map<String, int>.from(left);
    }

    final Map<String, int> merged = Map<String, int>.from(left);
    for (final MapEntry<String, int> entry in right.entries) {
      merged.update(
        entry.key,
        (int value) => value + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    return merged;
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
              (MapEntry<Object?, Object?> entry) =>
                  MapEntry<String, Object?>(entry.key.toString(), entry.value),
            ),
      );
    }
    return null;
  }

  static int? _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return null;
  }
}
