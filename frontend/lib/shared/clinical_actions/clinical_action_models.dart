import 'package:flutter/foundation.dart';

@immutable
final class ClinicalActionCatalogOption {
  const ClinicalActionCatalogOption({
    required this.id,
    this.publicId,
    this.name,
    this.code,
    this.category,
    this.secondaryText,
    this.status,
    this.parentId,
    this.secondaryId,
    this.searchText,
    this.childIds = const <String>[],
    this.childCodes = const <String>[],
  });

  final String id;
  final String? publicId;
  final String? name;
  final String? code;
  final String? category;
  final String? secondaryText;
  final String? status;
  final String? parentId;
  final String? secondaryId;
  final String? searchText;
  final List<String> childIds;
  final List<String> childCodes;

  String get apiId => publicId ?? id;

  String get displayTitle {
    return _joinDisplay(<String?>[name, code]) ?? apiId;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[category, secondaryText, status]);
  }
}

@immutable
final class ClinicalActionReferenceData {
  const ClinicalActionReferenceData({
    this.labTests = const <ClinicalActionCatalogOption>[],
    this.labPanels = const <ClinicalActionCatalogOption>[],
    this.radiologyTests = const <ClinicalActionCatalogOption>[],
    this.drugs = const <ClinicalActionCatalogOption>[],
    this.availableBeds = const <ClinicalActionCatalogOption>[],
    this.wards = const <ClinicalActionCatalogOption>[],
    this.rooms = const <ClinicalActionCatalogOption>[],
  });

  final List<ClinicalActionCatalogOption> labTests;
  final List<ClinicalActionCatalogOption> labPanels;
  final List<ClinicalActionCatalogOption> radiologyTests;
  final List<ClinicalActionCatalogOption> drugs;
  final List<ClinicalActionCatalogOption> availableBeds;
  final List<ClinicalActionCatalogOption> wards;
  final List<ClinicalActionCatalogOption> rooms;

  ClinicalActionReferenceData copyWith({
    List<ClinicalActionCatalogOption>? labTests,
    List<ClinicalActionCatalogOption>? labPanels,
    List<ClinicalActionCatalogOption>? radiologyTests,
    List<ClinicalActionCatalogOption>? drugs,
    List<ClinicalActionCatalogOption>? availableBeds,
    List<ClinicalActionCatalogOption>? wards,
    List<ClinicalActionCatalogOption>? rooms,
  }) {
    return ClinicalActionReferenceData(
      labTests: labTests ?? this.labTests,
      labPanels: labPanels ?? this.labPanels,
      radiologyTests: radiologyTests ?? this.radiologyTests,
      drugs: drugs ?? this.drugs,
      availableBeds: availableBeds ?? this.availableBeds,
      wards: wards ?? this.wards,
      rooms: rooms ?? this.rooms,
    );
  }
}

@immutable
final class ClinicalActionRadiologyRequest {
  const ClinicalActionRadiologyRequest({
    required this.radiologyTestId,
    this.clinicalNote,
    this.bodyRegion,
    this.laterality,
    this.priority,
  });

  final String radiologyTestId;
  final String? clinicalNote;
  final String? bodyRegion;
  final String? laterality;
  final String? priority;
}

@immutable
final class ClinicalActionLabOrderRecord {
  const ClinicalActionLabOrderRecord({
    required this.id,
    this.labOrderItems = const <ClinicalActionLabOrderItem>[],
  });

  final String id;
  final List<ClinicalActionLabOrderItem> labOrderItems;
}

@immutable
final class ClinicalActionLabOrderItem {
  const ClinicalActionLabOrderItem({
    required this.id,
    this.status,
    this.resultStatus,
    this.labTestId,
    this.testDisplayName,
    this.testCode,
    this.category,
    this.specimenType,
    this.unit,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? status;
  final String? resultStatus;
  final String? labTestId;
  final String? testDisplayName;
  final String? testCode;
  final String? category;
  final String? specimenType;
  final String? unit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

String? _joinDisplay(Iterable<String?> values) {
  final String value = values
      .map((String? item) => item?.trim() ?? '')
      .where((String item) => item.isNotEmpty)
      .join(' | ');
  return value.isEmpty ? null : value;
}
