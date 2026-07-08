import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

/// Manager roles assigned as extras that should not override day-to-day dashboards.
const Set<String> homeDashboardManagerOverlayRoleValues = <String>{
  'UNIT_MANAGER',
  'WARD_MANAGER',
  'ICU_MANAGER',
  'THEATRE_MANAGER',
  'HOUSEKEEPING_MANAGER',
  'BIOMED_MANAGER',
  'MORTUARY_MANAGER',
};

List<HomeStatusCard> scopeHomeStatusCards({
  required HomeDashboardProfile profile,
  required List<HomeStatusCard> apiCards,
}) {
  final Map<String, HomeStatusCard> apiById = <String, HomeStatusCard>{
    for (final HomeStatusCard card in apiCards) card.id: card,
  };

  return profile.statusCards
      .map((HomeStatusCardTemplate template) {
        final HomeStatusCard? fromApi = apiById[template.id];
        return HomeStatusCard(
          id: template.id,
          label: template.label,
          value: fromApi?.value ?? 0,
          format: template.format,
        );
      })
      .toList(growable: false);
}

List<String> scopeHomeActionIds({
  required List<String> profileIds,
  required List<String> apiIds,
}) {
  if (profileIds.isEmpty) {
    return apiIds;
  }
  if (apiIds.isEmpty) {
    return profileIds;
  }

  final Set<String> allowed = profileIds.toSet();
  final Set<String> fromApi = apiIds.where(allowed.contains).toSet();
  if (fromApi.isEmpty) {
    return profileIds;
  }

  return profileIds.where(fromApi.contains).toList(growable: false);
}

HomeDashboard mergeHomeDashboardForProfile({
  required HomeDashboardProfile profile,
  required HomeDashboard dashboard,
}) {
  return dashboard.copyWith(
    profile: profile,
    statusCards: scopeHomeStatusCards(
      profile: profile,
      apiCards: dashboard.statusCards,
    ),
    quickActionIds: profile.suppressHomeQuickActions
        ? const <String>[]
        : scopeHomeActionIds(
            profileIds: profile.quickActionIds,
            apiIds: dashboard.quickActionIds,
          ),
    shortcutIds: profile.suppressHomeShortcuts
        ? const <String>[]
        : scopeHomeActionIds(
            profileIds: profile.shortcutIds,
            apiIds: dashboard.shortcutIds,
          ),
  );
}
