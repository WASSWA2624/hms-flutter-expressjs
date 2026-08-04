/**
 * Uganda-focused diagnosis catalog seed data.
 *
 * Terms align with common presentations in Uganda Clinical Guidelines /
 * MoH priority conditions and use WHO ICD-10 codes where practical.
 * Keys and codes are unique so diagnosis suggestions load cleanly from
 * clinical_term_catalog.
 */

const { assertUniqueFields } = require('./catalog-validation');
const { UGANDA_CLINICAL_SOURCES } = require('./uganda-clinical-sources');

const DIAGNOSIS_SOURCE = `${UGANDA_CLINICAL_SOURCES.UG_MOH_UCG_2023.id}+${UGANDA_CLINICAL_SOURCES.WHO_ICD10_2019.id}`;

const diagnosisTerm = ([key, description, code, category], index) => ({
  key,
  description,
  code,
  category,
  source: DIAGNOSIS_SOURCE,
  rank: index + 1,
});

const diagnosisCatalog = [
  // Infectious disease & fever
  ['uncomplicated_malaria', 'Malaria, species unspecified (uncomplicated)', 'B54', 'Infectious Disease'],
  ['severe_malaria', 'Other severe and complicated Plasmodium falciparum malaria', 'B50.8', 'Infectious Disease'],
  ['malaria_in_pregnancy', 'Malaria complicating pregnancy (add B50-B54 species code)', 'O98.6', 'Maternity'],
  ['typhoid_fever', 'Typhoid fever', 'A01.0', 'Infectious Disease'],
  ['brucellosis', 'Brucellosis', 'A23.9', 'Infectious Disease'],
  ['cholera', 'Cholera', 'A00.9', 'Gastrointestinal'],
  ['shigellosis', 'Shigellosis (bacillary dysentery)', 'A03.9', 'Gastrointestinal'],
  ['acute_gastroenteritis', 'Acute gastroenteritis', 'A09', 'Gastrointestinal'],
  ['acute_diarrhea_with_dehydration', 'Volume depletion due to acute diarrhoea (code cause separately)', 'E86', 'Pediatrics'],
  ['sepsis_unspecified', 'Sepsis, unspecified', 'A41.9', 'Infectious Disease'],
  ['bacterial_meningitis', 'Bacterial meningitis', 'G00.9', 'Infectious Disease'],
  ['viral_meningitis', 'Viral meningitis', 'A87.9', 'Infectious Disease'],
  ['dengue_fever', 'Dengue, unspecified', 'A97.9', 'Infectious Disease'],
  ['rabies_exposure', 'Rabies exposure', 'Z20.3', 'Infectious Disease'],
  ['tetanus', 'Tetanus', 'A35', 'Infectious Disease'],
  ['neonatal_tetanus', 'Neonatal tetanus', 'A33', 'Neonatal'],
  ['pertussis', 'Pertussis', 'A37.9', 'Vaccine Preventable'],
  ['measles', 'Measles', 'B05.9', 'Vaccine Preventable'],
  ['varicella', 'Varicella', 'B01.9', 'Vaccine Preventable'],
  ['covid_19', 'COVID-19', 'U07.1', 'Infectious Disease'],
  ['trypanosomiasis', 'African trypanosomiasis', 'B56.9', 'Parasitic Disease'],
  ['yellow_fever', 'Yellow fever, unspecified', 'A95.9', 'Infectious Disease'],
  ['mpox', 'Mpox (monkeypox)', 'B04', 'Infectious Disease'],
  ['congenital_syphilis', 'Congenital syphilis, unspecified', 'A50.9', 'Infectious Disease'],

  // Tuberculosis
  ['pulmonary_tuberculosis_confirmed', 'Pulmonary tuberculosis, bacteriologically confirmed', 'A15.0', 'Tuberculosis'],
  ['pulmonary_tuberculosis_clinical', 'Pulmonary tuberculosis, clinically diagnosed', 'A16.2', 'Tuberculosis'],
  ['extrapulmonary_tuberculosis', 'Tuberculosis of other specified organs', 'A18.8', 'Tuberculosis'],
  ['tuberculous_meningitis', 'Tuberculous meningitis', 'A17.0', 'Tuberculosis'],

  // HIV & opportunistic infections
  ['hiv_disease_unspecified', 'HIV disease', 'B24', 'HIV'],
  ['hiv_with_tuberculosis', 'HIV disease with tuberculosis', 'B20.0', 'HIV'],
  ['oral_candidiasis', 'Oral candidiasis', 'B37.0', 'HIV'],
  ['cryptococcal_meningitis', 'Cryptococcal meningitis', 'B45.1', 'HIV'],
  ['pneumocystis_pneumonia', 'Pneumocystis jirovecii pneumonia', 'B59', 'HIV'],
  ['kaposi_sarcoma', 'Kaposi sarcoma', 'C46.9', 'HIV'],

  // Hepatitis & parasites
  ['viral_hepatitis_a', 'Viral hepatitis A', 'B15.9', 'Hepatitis'],
  ['viral_hepatitis_b', 'Acute hepatitis B without delta-agent or hepatic coma', 'B16.9', 'Hepatitis'],
  ['viral_hepatitis_c', 'Unspecified viral hepatitis C without hepatic coma', 'B19.2', 'Hepatitis'],
  ['acute_hepatitis_e', 'Acute hepatitis E', 'B17.2', 'Hepatitis'],
  ['intestinal_helminthiasis', 'Intestinal helminthiasis', 'B82.9', 'Parasitic Disease'],
  ['schistosomiasis', 'Schistosomiasis', 'B65.9', 'Parasitic Disease'],
  ['amoebiasis', 'Amoebiasis', 'A06.9', 'Parasitic Disease'],
  ['giardiasis', 'Giardiasis', 'A07.1', 'Parasitic Disease'],
  ['lymphatic_filariasis', 'Filariasis, unspecified', 'B74.9', 'Parasitic Disease'],
  ['onchocerciasis', 'Onchocerciasis', 'B73', 'Parasitic Disease'],
  ['visceral_leishmaniasis', 'Visceral leishmaniasis', 'B55.0', 'Parasitic Disease'],

  // Respiratory
  ['pneumonia', 'Pneumonia', 'J18.9', 'Respiratory'],
  ['upper_respiratory_tract_infection', 'Upper respiratory tract infection', 'J06.9', 'Respiratory'],
  ['acute_bronchitis', 'Acute bronchitis', 'J20.9', 'Respiratory'],
  ['bronchiolitis', 'Acute bronchiolitis', 'J21.9', 'Pediatrics'],
  ['asthma', 'Asthma', 'J45.9', 'Respiratory'],
  ['chronic_obstructive_pulmonary_disease', 'Chronic obstructive pulmonary disease', 'J44.9', 'Respiratory'],
  ['status_asthmaticus', 'Status asthmaticus / acute severe asthma', 'J46', 'Respiratory'],
  ['bronchiectasis', 'Bronchiectasis', 'J47', 'Respiratory'],
  ['pulmonary_embolism', 'Pulmonary embolism without acute cor pulmonale', 'I26.9', 'Respiratory'],

  // STI & genitourinary
  ['urinary_tract_infection', 'Urinary tract infection', 'N39.0', 'Genitourinary'],
  ['pelvic_inflammatory_disease', 'Pelvic inflammatory disease', 'N73.9', 'Genitourinary'],
  ['vulvovaginal_candidiasis', 'Vulvovaginal candidiasis', 'B37.3', 'Genitourinary'],
  ['bacterial_vaginosis', 'Acute vaginitis (including bacterial vaginosis syndrome)', 'N76.0', 'Genitourinary'],
  ['trichomoniasis', 'Trichomoniasis', 'A59.9', 'STI'],
  ['syphilis_unspecified', 'Syphilis, unspecified', 'A53.9', 'STI'],
  ['gonorrhea_unspecified', 'Gonorrhea, unspecified', 'A54.9', 'STI'],
  ['chlamydial_infection', 'Chlamydial infection of lower genitourinary tract', 'A56.0', 'STI'],
  ['benign_prostatic_hyperplasia', 'Benign prostatic hyperplasia', 'N40', 'Genitourinary'],
  ['uterine_fibroids', 'Uterine fibroids', 'D25.9', 'Genitourinary'],
  ['obstetric_fistula', 'Female genital tract fistula', 'N82.9', 'Genitourinary'],
  ['acute_pyelonephritis', 'Acute tubulo-interstitial nephritis (pyelonephritis)', 'N10', 'Genitourinary'],
  ['acute_glomerulonephritis', 'Acute nephritic syndrome, unspecified', 'N00.9', 'Renal'],

  // Cardiovascular & NCD
  ['essential_hypertension', 'Essential hypertension', 'I10', 'Cardiovascular'],
  ['hypertensive_heart_disease', 'Hypertensive heart disease', 'I11.9', 'Cardiovascular'],
  ['congestive_heart_failure', 'Congestive heart failure', 'I50.0', 'Cardiovascular'],
  ['ischemic_heart_disease', 'Ischemic heart disease', 'I25.9', 'Cardiovascular'],
  ['acute_myocardial_infarction', 'Acute myocardial infarction', 'I21.9', 'Cardiovascular'],
  ['rheumatic_heart_disease', 'Rheumatic heart disease', 'I09.9', 'Cardiovascular'],
  ['acute_rheumatic_fever', 'Rheumatic fever without mention of heart involvement', 'I00', 'Cardiovascular'],
  ['atrial_fibrillation', 'Atrial fibrillation and flutter', 'I48', 'Cardiovascular'],
  ['deep_vein_thrombosis', 'Phlebitis and thrombophlebitis of other deep vessels of lower extremities', 'I80.2', 'Cardiovascular'],
  ['endomyocardial_fibrosis', 'Endomyocardial (eosinophilic) disease', 'I42.3', 'Cardiovascular'],
  ['stroke_unspecified', 'Stroke, unspecified', 'I64', 'Neurology'],
  ['type_1_diabetes', 'Type 1 diabetes mellitus', 'E10.9', 'Endocrine'],
  ['type_2_diabetes', 'Type 2 diabetes mellitus', 'E11.9', 'Endocrine'],
  ['diabetic_ketoacidosis', 'Type 1 diabetes mellitus with ketoacidosis', 'E10.1', 'Endocrine'],
  ['type_2_diabetic_ketoacidosis', 'Type 2 diabetes mellitus with ketoacidosis', 'E11.1', 'Endocrine'],
  ['hypoglycemia', 'Hypoglycemia', 'E16.2', 'Endocrine'],
  ['chronic_kidney_disease', 'Chronic kidney disease', 'N18.9', 'Renal'],
  ['acute_kidney_injury', 'Acute kidney injury', 'N17.9', 'Renal'],
  ['nephrotic_syndrome', 'Nephrotic syndrome', 'N04.9', 'Renal'],

  // Hematology & nutrition
  ['sickle_cell_disease', 'Sickle-cell anaemia without crisis', 'D57.1', 'Hematology'],
  ['sickle_cell_crisis', 'Sickle-cell anaemia with crisis', 'D57.0', 'Hematology'],
  ['anemia_unspecified', 'Anemia, unspecified', 'D64.9', 'Hematology'],
  ['iron_deficiency_anemia', 'Iron deficiency anemia', 'D50.9', 'Hematology'],
  ['g6pd_deficiency_anemia', 'Glucose-6-phosphate dehydrogenase deficiency anaemia', 'D55.0', 'Hematology'],
  ['thalassemia_unspecified', 'Thalassaemia, unspecified', 'D56.9', 'Hematology'],
  ['malnutrition', 'Malnutrition', 'E46', 'Nutrition'],
  ['severe_acute_malnutrition', 'Severe acute malnutrition', 'E43', 'Nutrition'],
  ['kwashiorkor', 'Kwashiorkor', 'E40', 'Nutrition'],
  ['marasmus', 'Nutritional marasmus', 'E41', 'Nutrition'],
  ['obesity', 'Obesity', 'E66.9', 'Nutrition'],

  // Neurology & mental health
  ['epilepsy', 'Epilepsy', 'G40.9', 'Neurology'],
  ['cerebral_palsy', 'Cerebral palsy, unspecified', 'G80.9', 'Neurology'],
  ['migraine', 'Migraine', 'G43.9', 'Neurology'],
  ['febrile_convulsion', 'Febrile convulsion', 'R56.0', 'Pediatrics'],
  ['depression', 'Depressive episode, unspecified', 'F32.9', 'Mental Health'],
  ['anxiety_disorder', 'Anxiety disorder', 'F41.9', 'Mental Health'],
  ['psychosis_unspecified', 'Psychosis, unspecified', 'F29', 'Mental Health'],
  ['alcohol_use_disorder', 'Alcohol dependence syndrome', 'F10.2', 'Mental Health'],
  ['bipolar_disorder', 'Bipolar affective disorder, unspecified', 'F31.9', 'Mental Health'],
  ['schizophrenia', 'Schizophrenia, unspecified', 'F20.9', 'Mental Health'],
  ['post_traumatic_stress_disorder', 'Post-traumatic stress disorder', 'F43.1', 'Mental Health'],

  // GI / surgery
  ['gastritis', 'Gastritis', 'K29.7', 'Gastrointestinal'],
  ['peptic_ulcer_disease', 'Peptic ulcer disease', 'K27.9', 'Gastrointestinal'],
  ['liver_cirrhosis', 'Liver cirrhosis', 'K74.6', 'Gastrointestinal'],
  ['appendicitis', 'Other and unspecified acute appendicitis', 'K35.8', 'Surgery'],
  ['inguinal_hernia', 'Inguinal hernia', 'K40.9', 'Surgery'],
  ['intestinal_obstruction', 'Intestinal obstruction', 'K56.6', 'Surgery'],
  ['cholecystitis', 'Cholecystitis', 'K81.9', 'Surgery'],
  ['pancreatitis', 'Acute pancreatitis', 'K85.9', 'Surgery'],
  ['hemorrhoids', 'Hemorrhoids', 'K64.9', 'Surgery'],
  ['peritonitis', 'Peritonitis', 'K65.9', 'Surgery'],

  // Maternity & neonatal
  ['antenatal_care', 'Supervision of normal pregnancy', 'Z34.9', 'Maternity'],
  ['pregnant_state', 'Pregnant state, incidental', 'Z33', 'Maternity'],
  ['family_planning_encounter', 'Contraceptive management', 'Z30.9', 'Maternity'],
  ['hyperemesis_gravidarum', 'Mild hyperemesis gravidarum', 'O21.0', 'Maternity'],
  ['anemia_in_pregnancy', 'Anemia in pregnancy', 'O99.0', 'Maternity'],
  ['urinary_tract_infection_in_pregnancy', 'Urinary tract infection in pregnancy', 'O23.4', 'Maternity'],
  ['gestational_hypertension', 'Gestational hypertension', 'O13', 'Maternity'],
  ['pre_eclampsia', 'Pre-eclampsia', 'O14.9', 'Maternity'],
  ['eclampsia', 'Eclampsia', 'O15.9', 'Maternity'],
  ['placenta_previa', 'Placenta praevia with haemorrhage', 'O44.1', 'Maternity'],
  ['abruptio_placentae', 'Abruptio placentae', 'O45.9', 'Maternity'],
  ['postpartum_hemorrhage', 'Other immediate postpartum haemorrhage', 'O72.1', 'Maternity'],
  ['miscarriage', 'Miscarriage', 'O03.9', 'Maternity'],
  ['ectopic_pregnancy', 'Ectopic pregnancy', 'O00.9', 'Maternity'],
  ['obstructed_labor', 'Obstructed labor', 'O66.9', 'Maternity'],
  ['puerperal_sepsis', 'Puerperal sepsis', 'O85', 'Maternity'],
  ['premature_rupture_of_membranes', 'Premature rupture of membranes', 'O42.9', 'Maternity'],
  ['prolonged_labor', 'Prolonged labor', 'O63.9', 'Maternity'],
  ['gestational_diabetes', 'Diabetes mellitus arising in pregnancy', 'O24.4', 'Maternity'],
  ['maternal_care_fetal_growth_restriction', 'Maternal care for poor fetal growth', 'O36.5', 'Maternity'],
  ['neonatal_sepsis', 'Neonatal sepsis', 'P36.9', 'Neonatal'],
  ['neonatal_jaundice', 'Neonatal jaundice', 'P59.9', 'Neonatal'],
  ['neonatal_pneumonia', 'Congenital pneumonia, unspecified', 'P23.9', 'Neonatal'],
  ['neonatal_respiratory_distress', 'Respiratory distress of newborn, unspecified', 'P22.9', 'Neonatal'],
  ['neonatal_hypoglycemia', 'Other neonatal hypoglycaemia', 'P70.4', 'Neonatal'],
  ['prematurity', 'Other preterm infants', 'P07.3', 'Neonatal'],
  ['birth_asphyxia', 'Birth asphyxia', 'P21.9', 'Neonatal'],
  ['low_birth_weight', 'Other low birth weight', 'P07.1', 'Neonatal'],

  // Oncology (high burden in Uganda)
  ['cervical_cancer', 'Malignant neoplasm of cervix uteri', 'C53.9', 'Oncology'],
  ['breast_cancer', 'Malignant neoplasm of breast', 'C50.9', 'Oncology'],
  ['esophageal_cancer', 'Malignant neoplasm of esophagus', 'C15.9', 'Oncology'],
  ['prostate_cancer', 'Malignant neoplasm of prostate', 'C61', 'Oncology'],
  ['liver_cancer', 'Malignant neoplasm of liver', 'C22.9', 'Oncology'],
  ['burkitt_lymphoma', 'Burkitt lymphoma', 'C83.7', 'Oncology'],
  ['non_hodgkin_lymphoma', 'Non-Hodgkin lymphoma, unspecified', 'C85.9', 'Oncology'],
  ['ovarian_cancer', 'Malignant neoplasm of ovary', 'C56', 'Oncology'],
  ['colorectal_cancer', 'Malignant neoplasm of colon, unspecified', 'C18.9', 'Oncology'],

  // ENT, eye, dental, skin
  ['otitis_media', 'Otitis media', 'H66.9', 'ENT'],
  ['allergic_rhinitis', 'Allergic rhinitis, unspecified', 'J30.4', 'ENT'],
  ['tonsillitis', 'Tonsillitis', 'J03.9', 'ENT'],
  ['sinusitis', 'Sinusitis', 'J01.9', 'ENT'],
  ['conjunctivitis', 'Conjunctivitis', 'H10.9', 'Eye'],
  ['refractive_error', 'Refractive error', 'H52.7', 'Eye'],
  ['cataract', 'Cataract', 'H26.9', 'Eye'],
  ['glaucoma', 'Glaucoma', 'H40.9', 'Eye'],
  ['trachoma', 'Trachoma, unspecified', 'A71.9', 'Eye'],
  ['keratitis', 'Keratitis, unspecified', 'H16.9', 'Eye'],
  ['hearing_loss', 'Hearing loss, unspecified', 'H91.9', 'ENT'],
  ['dental_caries', 'Dental caries', 'K02.9', 'Dental'],
  ['dental_abscess', 'Dental abscess', 'K04.7', 'Dental'],
  ['dermatitis', 'Dermatitis', 'L30.9', 'Skin'],
  ['tinea_infection', 'Tinea infection', 'B35.9', 'Skin'],
  ['scabies', 'Scabies', 'B86', 'Skin'],
  ['cellulitis', 'Cellulitis', 'L03.9', 'Skin'],
  ['skin_abscess', 'Skin abscess', 'L02.9', 'Skin'],
  ['wound_infection', 'Wound infection', 'L08.9', 'Skin'],
  ['pressure_ulcer', 'Pressure ulcer', 'L89', 'Skin'],

  // Musculoskeletal, trauma, emergency
  ['low_back_pain', 'Low back pain', 'M54.5', 'Musculoskeletal'],
  ['osteoarthritis', 'Osteoarthritis', 'M19.9', 'Musculoskeletal'],
  ['rheumatoid_arthritis', 'Rheumatoid arthritis', 'M06.9', 'Musculoskeletal'],
  ['osteomyelitis', 'Osteomyelitis, unspecified', 'M86.9', 'Musculoskeletal'],
  ['septic_arthritis', 'Pyogenic arthritis, unspecified', 'M00.9', 'Musculoskeletal'],
  ['burn_injury', 'Burn of unspecified degree and body region', 'T30.0', 'Emergency'],
  ['fracture_unspecified', 'Fracture of unspecified body region', 'T14.2', 'Trauma'],
  ['head_injury', 'Head injury', 'S09.9', 'Trauma'],
  ['road_traffic_injury', 'Person injured in unspecified motor-vehicle traffic accident', 'V89.2', 'Trauma'],
  ['snakebite_toxic_effect', 'Toxic effect of snake venom', 'T63.0', 'Emergency'],
  ['poisoning_unspecified', 'Toxic effect of unspecified substance', 'T65.9', 'Emergency'],
  ['drug_poisoning_unspecified', 'Poisoning by other and unspecified drugs and biological substances', 'T50.9', 'Emergency'],
  ['drowning_nonfatal', 'Nonfatal drowning and submersion', 'T75.1', 'Emergency'],
  ['anaphylaxis', 'Anaphylactic shock, unspecified', 'T78.2', 'Emergency'],
].map(diagnosisTerm);

assertUniqueFields(diagnosisCatalog, {
  label: 'UGANDA_DIAGNOSIS_CATALOG',
  fields: ['key', 'description', 'code'],
});

const UGANDA_DIAGNOSIS_CATALOG = Object.freeze(diagnosisCatalog);

module.exports = {
  UGANDA_DIAGNOSIS_CATALOG,
};
