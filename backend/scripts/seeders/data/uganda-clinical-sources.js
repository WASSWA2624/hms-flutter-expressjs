/**
 * Versioned source registry for Uganda clinical seed catalogs.
 *
 * Keep source identifiers stable: persisted records and reference-range notes
 * use them as compact provenance pointers. URLs are public primary sources
 * where possible. A source supports catalog seeding; each facility still has
 * to verify analyser/method-specific intervals before clinical activation.
 */

const freezeSources = (sources) =>
  Object.freeze(
    Object.fromEntries(
      Object.entries(sources).map(([key, source]) => [
        key,
        Object.freeze({ id: key, ...source }),
      ])
    )
  );

const UGANDA_CLINICAL_SOURCES = freezeSources({
  UG_MOH_UCG_2023: {
    title: 'Uganda Clinical Guidelines 2023',
    publisher: 'Uganda Ministry of Health',
    year: 2023,
    url: 'https://library.health.go.ug/sites/default/files/resources/Uganda%20Clinical%20Guidelines%202023.pdf',
    scope: 'Priority conditions, terminology, and national clinical practice',
  },
  CDC_ICD10_CM: {
    title: 'International Classification of Diseases, Tenth Revision, Clinical Modification',
    publisher: 'US Centers for Disease Control and Prevention, National Center for Health Statistics',
    url: 'https://www.cdc.gov/nchs/icd/icd-10-cm/',
    scope:
      'Rubric titles for the ICD-10 category representatives in the diagnosis catalog. Clinical Modification, so codes are more granular than WHO ICD-10 and are not interchangeable with it',
  },
  UG_MOH_LAB_MENU_2017: {
    title: 'National Standard Test Menu, Techniques and Supplies List for Laboratories in Uganda',
    publisher: 'Uganda Ministry of Health, National Health Laboratory Services',
    year: 2017,
    url: 'https://www.cphl.go.ug/sites/default/files/2019-06/NSTMT%20TEST%20MENU.pdf',
    scope: 'Laboratory test-menu coverage by level of care',
  },
  WHO_ICD10_2019: {
    title: 'ICD-10, Sixth Edition',
    publisher: 'World Health Organization',
    year: 2019,
    url: 'https://icd.who.int/browse10/2019/en',
    scope: 'Diagnosis code semantics; not ICD-10-CM',
  },
  WHO_HAEMOGLOBIN_2024: {
    title: 'Guideline on haemoglobin cutoffs to define anaemia in individuals and populations',
    publisher: 'World Health Organization',
    year: 2024,
    url: 'https://www.who.int/publications/i/item/9789240088542',
    scope: 'Age-, sex-, and pregnancy-specific anaemia decision limits',
  },
  LUGADA_UGANDA_2004: {
    title: 'Population-Based Hematologic and Immunologic Reference Values for a Healthy Ugandan Population',
    publisher: 'Clinical and Diagnostic Laboratory Immunology',
    year: 2004,
    doi: '10.1128/CDLI.11.1.29-34.2004',
    url: 'https://doi.org/10.1128/CDLI.11.1.29-34.2004',
    scope: 'Ugandan 90% haematology and lymphocyte-subset intervals, infancy to adulthood',
  },
  KIRONDE_UGANDA_2013: {
    title: 'Hematology and Blood Serum Chemistry Reference Intervals for Children in Iganga District of Uganda',
    publisher: 'Health',
    year: 2013,
    doi: '10.4236/health.2013.58171',
    url: 'https://doi.org/10.4236/health.2013.58171',
    scope: 'Ugandan 90% haematology and chemistry intervals, ages 1-5 years',
  },
  PALACPAC_UGANDA_2014: {
    title: 'Hematological and Biochemical Data Obtained in Rural Northern Uganda',
    publisher: 'International Journal of Environmental Research and Public Health',
    year: 2014,
    doi: '10.3390/ijerph110504870',
    url: 'https://doi.org/10.3390/ijerph110504870',
    scope: 'Northern Uganda 95% haematology and chemistry intervals, ages 6-15 years and adults',
  },
  KARITA_EAST_AFRICA_2009: {
    title: 'CLSI-Derived Hematology and Biochemistry Reference Intervals for Healthy Adults in Eastern and Southern Africa',
    publisher: 'PLOS ONE',
    year: 2009,
    doi: '10.1371/journal.pone.0004401',
    url: 'https://doi.org/10.1371/journal.pone.0004401',
    scope: 'Adult African intervals including cohorts in Masaka and Entebbe, Uganda',
  },
  MAYO_PEDIATRIC_CATALOG_2026: {
    title: 'Pediatric Test Reference Values',
    publisher: 'Mayo Clinic Laboratories',
    year: 2026,
    retrieved: '2026-08-04',
    url: 'https://www.mayocliniclabs.com/test-info/pediatric/refvalues/reference.php',
    scope: 'Transfer templates for named Mayo assays where a suitable Ugandan study was unavailable',
  },
  MAYO_IRON_PROFILE_2026: {
    title: 'Iron Profile',
    publisher: 'Network Reference Lab powered by Mayo Clinic Laboratories',
    year: 2026,
    retrieved: '2026-08-04',
    url: 'https://nrl.testcatalog.org/show/Iron-Profile',
    scope: 'Assay-specific age- and sex-partitioned serum iron transfer template',
  },
  CLSI_EP28_A3C: {
    title: 'Defining, Establishing, and Verifying Reference Intervals in the Clinical Laboratory',
    publisher: 'Clinical and Laboratory Standards Institute',
    year: 2010,
    url: 'https://clsi.org/standards/products/method-evaluation/documents/ep28/',
    scope: 'Local reference-interval transfer and verification requirements',
  },
  WHO_DIAGNOSTIC_IMAGING: {
    title: 'Diagnostic Imaging',
    publisher: 'World Health Organization',
    url: 'https://www.who.int/health-topics/medical-devices/diagnostic-imaging',
    scope: 'Essential diagnostic-imaging services and radiation safety',
  },
});

const compactSourceNote = (sourceId, detail = null) => {
  const source = UGANDA_CLINICAL_SOURCES[sourceId];
  if (!source) {
    throw new Error(`Unknown Uganda clinical source: ${sourceId}`);
  }

  const citation = `${sourceId}: ${source.publisher} ${source.year || 'current'}`;
  return [citation, detail].filter(Boolean).join('. ').slice(0, 255);
};

module.exports = {
  UGANDA_CLINICAL_SOURCES,
  compactSourceNote,
};
