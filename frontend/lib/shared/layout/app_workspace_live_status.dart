import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Standardized live/sync status badge factory for module workspaces.
abstract final class AppWorkspaceLiveStatus {
  const AppWorkspaceLiveStatus._();

  static AppWorkspaceStatus idle({required String label}) {
    return AppWorkspaceStatus(
      label: label,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.sync,
    );
  }

  static AppWorkspaceStatus saving({required String label}) {
    return AppWorkspaceStatus(
      label: label,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.sync,
    );
  }

  static AppWorkspaceStatus fromSavingState({
    required bool isSaving,
    required String liveLabel,
    required String savingLabel,
  }) {
    return isSaving ? saving(label: savingLabel) : idle(label: liveLabel);
  }
}
