enum ClinicalCatalogSource { all, favorites, facility, global }

extension ClinicalCatalogSourceApiX on ClinicalCatalogSource {
  String get apiValue {
    return switch (this) {
      ClinicalCatalogSource.all => 'ALL',
      ClinicalCatalogSource.favorites => 'FAVORITES',
      ClinicalCatalogSource.facility => 'FACILITY',
      ClinicalCatalogSource.global => 'GLOBAL',
    };
  }

  static ClinicalCatalogSource fromApiValue(String? value) {
    return switch ((value ?? '').trim().toUpperCase()) {
      'FAVORITES' => ClinicalCatalogSource.favorites,
      'FACILITY' => ClinicalCatalogSource.facility,
      'GLOBAL' => ClinicalCatalogSource.global,
      _ => ClinicalCatalogSource.all,
    };
  }
}

enum ClinicalCatalogTermType {
  diagnosis,
  procedure,
  labTest,
  radiologyTest,
  prescription,
}

extension ClinicalCatalogTermTypeApiX on ClinicalCatalogTermType {
  String get apiValue {
    return switch (this) {
      ClinicalCatalogTermType.diagnosis => 'DIAGNOSIS',
      ClinicalCatalogTermType.procedure => 'PROCEDURE',
      ClinicalCatalogTermType.labTest => 'LAB_TEST',
      ClinicalCatalogTermType.radiologyTest => 'RADIOLOGY_TEST',
      ClinicalCatalogTermType.prescription => 'PRESCRIPTION',
    };
  }

  static ClinicalCatalogTermType fromApiValue(String? value) {
    return switch ((value ?? '').trim().toUpperCase()) {
      'PROCEDURE' => ClinicalCatalogTermType.procedure,
      'LAB_TEST' => ClinicalCatalogTermType.labTest,
      'RADIOLOGY_TEST' => ClinicalCatalogTermType.radiologyTest,
      'PRESCRIPTION' => ClinicalCatalogTermType.prescription,
      _ => ClinicalCatalogTermType.diagnosis,
    };
  }
}
