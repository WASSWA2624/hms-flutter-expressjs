import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session-persisted lab desk preferences (SharedPreferences; no backend store).
abstract final class LabDeskPreferences {
  static const String defaultTabKey = 'lab_desk_default_tab';
  static const String pageSizeKey = 'lab_desk_page_size';
  static const List<int> pageSizeChoices = <int>[10, 25, 50];
  static const int defaultPageSize = 25;

  static LabDeskSection? readDefaultTab(SharedPreferences prefs) {
    final String? raw = prefs.getString(defaultTabKey)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final LabDeskSection section in LabDeskSection.values) {
      if (section.name == raw) {
        return section;
      }
    }
    return null;
  }

  static Future<void> writeDefaultTab(
    SharedPreferences prefs,
    LabDeskSection? section,
  ) async {
    if (section == null) {
      await prefs.remove(defaultTabKey);
      return;
    }
    await prefs.setString(defaultTabKey, section.name);
  }

  static int readPageSize(SharedPreferences prefs) {
    final int? value = prefs.getInt(pageSizeKey);
    if (value == null || !pageSizeChoices.contains(value)) {
      return defaultPageSize;
    }
    return value;
  }

  static Future<void> writePageSize(
    SharedPreferences prefs,
    int pageSize,
  ) async {
    final int resolved = pageSizeChoices.contains(pageSize)
        ? pageSize
        : defaultPageSize;
    await prefs.setInt(pageSizeKey, resolved);
  }
}
