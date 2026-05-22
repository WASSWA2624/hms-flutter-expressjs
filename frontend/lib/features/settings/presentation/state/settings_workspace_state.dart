import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';

@immutable
final class SettingsWorkspaceState {
  const SettingsWorkspaceState({
    required this.query,
    required this.workspace,
    required this.referenceData,
    this.isRefreshing = false,
  });

  final SettingsWorkspaceQuery query;
  final SettingsWorkspace workspace;
  final SettingsReferenceData referenceData;
  final bool isRefreshing;

  SettingsWorkspaceState copyWith({
    SettingsWorkspaceQuery? query,
    SettingsWorkspace? workspace,
    SettingsReferenceData? referenceData,
    bool? isRefreshing,
  }) {
    return SettingsWorkspaceState(
      query: query ?? this.query,
      workspace: workspace ?? this.workspace,
      referenceData: referenceData ?? this.referenceData,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
