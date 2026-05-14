final class HomeReadinessSnapshot {
  const HomeReadinessSnapshot({
    required this.providerGraphReady,
    required this.dependenciesOverrideable,
    required this.asyncStateReady,
  });

  const HomeReadinessSnapshot.ready()
    : providerGraphReady = true,
      dependenciesOverrideable = true,
      asyncStateReady = true;

  final bool providerGraphReady;
  final bool dependenciesOverrideable;
  final bool asyncStateReady;

  bool get isReady {
    return providerGraphReady && dependenciesOverrideable && asyncStateReady;
  }
}
