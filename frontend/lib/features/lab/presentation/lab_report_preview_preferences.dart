import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Non-PHI keys for optional report header / print metadata.
abstract final class LabReportMetadataKeys {
  static const String patientId = 'patient_id';
  static const String encounter = 'encounter';
  static const String orderIds = 'order_ids';
  static const String orderStatus = 'order_status';
  static const String orderedAt = 'ordered_at';
  static const String ordersIncluded = 'orders_included';
  static const String patientGender = 'patient_gender';
  static const String patientAge = 'patient_age';

  static const List<String> all = <String>[
    patientId,
    encounter,
    orderIds,
    orderStatus,
    orderedAt,
    ordersIncluded,
    patientGender,
    patientAge,
  ];

  static const Set<String> defaults = <String>{
    patientId,
    encounter,
    orderIds,
    orderStatus,
    ordersIncluded,
  };
}

/// Session-persisted lab result report preview / printout preferences.
final class LabReportPreviewSettings {
  const LabReportPreviewSettings({
    required this.decimalPlaces,
    required this.showRangeLabel,
    required this.showRangeMethod,
    required this.showRangeGender,
    required this.showRangeAge,
    required this.metadataKeys,
  });

  static const List<int> decimalPlaceChoices = <int>[0, 1, 2, 3, 4];
  static const int defaultDecimalPlaces = 2;

  static const LabReportPreviewSettings defaults = LabReportPreviewSettings(
    decimalPlaces: defaultDecimalPlaces,
    showRangeLabel: true,
    showRangeMethod: true,
    showRangeGender: true,
    showRangeAge: true,
    metadataKeys: LabReportMetadataKeys.defaults,
  );

  final int decimalPlaces;
  final bool showRangeLabel;
  final bool showRangeMethod;
  final bool showRangeGender;
  final bool showRangeAge;
  final Set<String> metadataKeys;

  bool showsMetadata(String key) => metadataKeys.contains(key);

  LabReportPreviewSettings copyWith({
    int? decimalPlaces,
    bool? showRangeLabel,
    bool? showRangeMethod,
    bool? showRangeGender,
    bool? showRangeAge,
    Set<String>? metadataKeys,
  }) {
    return LabReportPreviewSettings(
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
      showRangeLabel: showRangeLabel ?? this.showRangeLabel,
      showRangeMethod: showRangeMethod ?? this.showRangeMethod,
      showRangeGender: showRangeGender ?? this.showRangeGender,
      showRangeAge: showRangeAge ?? this.showRangeAge,
      metadataKeys: metadataKeys ?? this.metadataKeys,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'decimalPlaces': decimalPlaces,
      'showRangeLabel': showRangeLabel,
      'showRangeMethod': showRangeMethod,
      'showRangeGender': showRangeGender,
      'showRangeAge': showRangeAge,
      'metadataKeys': metadataKeys.toList(growable: false)..sort(),
    };
  }

  static LabReportPreviewSettings fromJson(Map<String, Object?> json) {
    final Object? rawDecimals = json['decimalPlaces'];
    final int parsedDecimals = rawDecimals is int
        ? rawDecimals
        : int.tryParse(rawDecimals?.toString() ?? '') ??
              defaultDecimalPlaces;
    final int decimalPlaces = decimalPlaceChoices.contains(parsedDecimals)
        ? parsedDecimals
        : defaultDecimalPlaces;

    final Object? rawKeys = json['metadataKeys'];
    final Set<String> metadataKeys = <String>{};
    if (rawKeys is List) {
      for (final Object? entry in rawKeys) {
        final String key = entry?.toString().trim() ?? '';
        if (LabReportMetadataKeys.all.contains(key)) {
          metadataKeys.add(key);
        }
      }
    }

    return LabReportPreviewSettings(
      decimalPlaces: decimalPlaces,
      showRangeLabel: json['showRangeLabel'] != false,
      showRangeMethod: json['showRangeMethod'] != false,
      showRangeGender: json['showRangeGender'] != false,
      showRangeAge: json['showRangeAge'] != false,
      metadataKeys: metadataKeys.isEmpty
          ? LabReportMetadataKeys.defaults
          : metadataKeys,
    );
  }
}

abstract final class LabReportPreviewPreferences {
  /// UI-only preference blob. Never store PHI with this key.
  static const String settingsKey = 'lab_report_preview.settings';

  static LabReportPreviewSettings read(SharedPreferences prefs) {
    final String? raw = prefs.getString(settingsKey)?.trim();
    if (raw == null || raw.isEmpty) {
      return LabReportPreviewSettings.defaults;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return LabReportPreviewSettings.defaults;
      }
      return LabReportPreviewSettings.fromJson(
        decoded.map(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        ),
      );
    } catch (_) {
      return LabReportPreviewSettings.defaults;
    }
  }

  static Future<void> write(
    SharedPreferences prefs,
    LabReportPreviewSettings settings,
  ) async {
    await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }
}
