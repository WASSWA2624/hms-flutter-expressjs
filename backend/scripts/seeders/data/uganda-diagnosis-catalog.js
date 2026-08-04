/**
 * Uganda-focused diagnosis catalog seed data.
 *
 * Terms align with common presentations in Uganda Clinical Guidelines /
 * MoH priority conditions and use WHO ICD-10 codes where practical.
 * Keys and codes are unique so diagnosis suggestions load cleanly from
 * clinical_term_catalog.
 */

const diagnosisTerm = ([key, description, code, category], index) => ({
  key,
  description,
  code,
  category,
  source: 'UGANDA_CLINICAL_GUIDELINES',
  rank: index + 1,
});

const UGANDA_DIAGNOSIS_CATALOG = Object.freeze([
  // Infectious disease & fever
  ['uncomplicated_malaria', 'Uncomplicated malaria', 'B54', 'Infectious Disease'],
  ['severe_malaria', 'Severe malaria', 'B50.8', 'Infectious Disease'],
  ['malaria_in_pregnancy', 'Malaria in pregnancy', 'O98.6', 'Maternity'],
  ['typhoid_fever', 'Typhoid fever', 'A01.0', 'Infectious Disease'],
  ['brucellosis', 'Brucellosis', 'A23.9', 'Infectious Disease'],
  ['cholera', 'Cholera', 'A00.9', 'Gastrointestinal'],
  ['shigellosis', 'Shigellosis (bacillary dysentery)', 'A03.9', 'Gastrointestinal'],
  ['acute_gastroenteritis', 'Acute gastroenteritis', 'A09', 'Gastrointestinal'],
  ['acute_diarrhea_with_dehydration', 'Acute diarrhea with dehydration', 'E86', 'Pediatrics'],
  ['sepsis_unspecified', 'Sepsis, unspecified', 'A41.9', 'Infectious Disease'],
  ['bacterial_meningitis', 'Bacterial meningitis', 'G00.9', 'Infectious Disease'],
  ['viral_meningitis', 'Viral meningitis', 'A87.9', 'Infectious Disease'],
  ['dengue_fever', 'Dengue fever', 'A90', 'Infectious Disease'],
  ['rabies_exposure', 'Rabies exposure', 'Z20.3', 'Infectious Disease'],
  ['tetanus', 'Tetanus', 'A35', 'Infectious Disease'],
  ['neonatal_tetanus', 'Neonatal tetanus', 'A33', 'Neonatal'],
  ['pertussis', 'Pertussis', 'A37.9', 'Vaccine Preventable'],
  ['measles', 'Measles', 'B05.9', 'Vaccine Preventable'],
  ['varicella', 'Varicella', 'B01.9', 'Vaccine Preventable'],
  ['covid_19', 'COVID-19', 'U07.1', 'Infectious Disease'],
  ['trypanosomiasis', 'African trypanosomiasis', 'B56.9', 'Parasitic Disease'],

  // Tuberculosis
  ['pulmonary_tuberculosis_confirmed', 'Pulmonary tuberculosis, bacteriologically confirmed', 'A15.0', 'Tuberculosis'],
  ['pulmonary_tuberculosis_clinical', 'Pulmonary tuberculosis, clinically diagnosed', 'A16.2', 'Tuberculosis'],
  ['extrapulmonary_tuberculosis', 'Extrapulmonary tuberculosis', 'A18.8', 'Tuberculosis'],
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
  ['viral_hepatitis_b', 'Viral hepatitis B', 'B16.9', 'Hepatitis'],
  ['viral_hepatitis_c', 'Viral hepatitis C', 'B19.2', 'Hepatitis'],
  ['intestinal_helminthiasis', 'Intestinal helminthiasis', 'B82.9', 'Parasitic Disease'],
  ['schistosomiasis', 'Schistosomiasis', 'B65.9', 'Parasitic Disease'],
  ['amoebiasis', 'Amoebiasis', 'A06.9', 'Parasitic Disease'],
  ['giardiasis', 'Giardiasis', 'A07.1', 'Parasitic Disease'],

  // Respiratory
  ['pneumonia', 'Pneumonia', 'J18.9', 'Respiratory'],
  ['upper_respiratory_tract_infection', 'Upper respiratory tract infection', 'J06.9', 'Respiratory'],
  ['acute_bronchitis', 'Acute bronchitis', 'J20.9', 'Respiratory'],
  ['bronchiolitis', 'Acute bronchiolitis', 'J21.9', 'Pediatrics'],
  ['asthma', 'Asthma', 'J45.9', 'Respiratory'],
  ['chronic_obstructive_pulmonary_disease', 'Chronic obstructive pulmonary disease', 'J44.9', 'Respiratory'],
  ['status_asthmaticus', 'Status asthmaticus / acute severe asthma', 'J46', 'Respiratory'],

  // STI & genitourinary
  ['urinary_tract_infection', 'Urinary tract infection', 'N39.0', 'Genitourinary'],
  ['pelvic_inflammatory_disease', 'Pelvic inflammatory disease', 'N73.9', 'Genitourinary'],
  ['vulvovaginal_candidiasis', 'Vulvovaginal candidiasis', 'B37.3', 'Genitourinary'],
  ['bacterial_vaginosis', 'Bacterial vaginosis', 'N76.0', 'Genitourinary'],
  ['trichomoniasis', 'Trichomoniasis', 'A59.9', 'STI'],
  ['syphilis_unspecified', 'Syphilis, unspecified', 'A53.9', 'STI'],
  ['gonorrhea_unspecified', 'Gonorrhea, unspecified', 'A54.9', 'STI'],
  ['chlamydial_infection', 'Chlamydial infection of lower genitourinary tract', 'A56.0', 'STI'],
  ['benign_prostatic_hyperplasia', 'Benign prostatic hyperplasia', 'N40', 'Genitourinary'],
  ['uterine_fibroids', 'Uterine fibroids', 'D25.9', 'Genitourinary'],
  ['obstetric_fistula', 'Female genital tract fistula', 'N82.9', 'Genitourinary'],

  // Cardiovascular & NCD
  ['essential_hypertension', 'Essential hypertension', 'I10', 'Cardiovascular'],
  ['hypertensive_heart_disease', 'Hypertensive heart disease', 'I11.9', 'Cardiovascular'],
  ['congestive_heart_failure', 'Congestive heart failure', 'I50.9', 'Cardiovascular'],
  ['ischemic_heart_disease', 'Ischemic heart disease', 'I25.9', 'Cardiovascular'],
  ['acute_myocardial_infarction', 'Acute myocardial infarction', 'I21.9', 'Cardiovascular'],
  ['rheumatic_heart_disease', 'Rheumatic heart disease', 'I09.9', 'Cardiovascular'],
  ['stroke_unspecified', 'Stroke, unspecified', 'I64', 'Neurology'],
  ['type_1_diabetes', 'Type 1 diabetes mellitus', 'E10.9', 'Endocrine'],
  ['type_2_diabetes', 'Type 2 diabetes mellitus', 'E11.9', 'Endocrine'],
  ['diabetic_ketoacidosis', 'Diabetic ketoacidosis', 'E11.1', 'Endocrine'],
  ['hypoglycemia', 'Hypoglycemia', 'E16.2', 'Endocrine'],
  ['chronic_kidney_disease', 'Chronic kidney disease', 'N18.9', 'Renal'],
  ['acute_kidney_injury', 'Acute kidney injury', 'N17.9', 'Renal'],
  ['nephrotic_syndrome', 'Nephrotic syndrome', 'N04.9', 'Renal'],

  // Hematology & nutrition
  ['sickle_cell_disease', 'Sickle cell disease', 'D57.1', 'Hematology'],
  ['sickle_cell_crisis', 'Sickle cell crisis', 'D57.0', 'Hematology'],
  ['anemia_unspecified', 'Anemia, unspecified', 'D64.9', 'Hematology'],
  ['iron_deficiency_anemia', 'Iron deficiency anemia', 'D50.9', 'Hematology'],
  ['malnutrition', 'Malnutrition', 'E46', 'Nutrition'],
  ['severe_acute_malnutrition', 'Severe acute malnutrition', 'E43', 'Nutrition'],
  ['kwashiorkor', 'Kwashiorkor', 'E40', 'Nutrition'],
  ['marasmus', 'Nutritional marasmus', 'E41', 'Nutrition'],
  ['obesity', 'Obesity', 'E66.9', 'Nutrition'],

  // Neurology & mental health
  ['epilepsy', 'Epilepsy', 'G40.9', 'Neurology'],
  ['migraine', 'Migraine', 'G43.9', 'Neurology'],
  ['febrile_convulsion', 'Febrile convulsion', 'R56.0', 'Pediatrics'],
  ['depression', 'Depression', 'F32.9', 'Mental Health'],
  ['anxiety_disorder', 'Anxiety disorder', 'F41.9', 'Mental Health'],
  ['psychosis_unspecified', 'Psychosis, unspecified', 'F29', 'Mental Health'],
  ['alcohol_use_disorder', 'Alcohol use disorder', 'F10.2', 'Mental Health'],

  // GI / surgery
  ['gastritis', 'Gastritis', 'K29.7', 'Gastrointestinal'],
  ['peptic_ulcer_disease', 'Peptic ulcer disease', 'K27.9', 'Gastrointestinal'],
  ['liver_cirrhosis', 'Liver cirrhosis', 'K74.6', 'Gastrointestinal'],
  ['appendicitis', 'Appendicitis', 'K35.9', 'Surgery'],
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
  ['hyperemesis_gravidarum', 'Hyperemesis gravidarum', 'O21.0', 'Maternity'],
  ['anemia_in_pregnancy', 'Anemia in pregnancy', 'O99.0', 'Maternity'],
  ['urinary_tract_infection_in_pregnancy', 'Urinary tract infection in pregnancy', 'O23.4', 'Maternity'],
  ['gestational_hypertension', 'Gestational hypertension', 'O13', 'Maternity'],
  ['pre_eclampsia', 'Pre-eclampsia', 'O14.9', 'Maternity'],
  ['eclampsia', 'Eclampsia', 'O15.9', 'Maternity'],
  ['placenta_previa', 'Placenta previa', 'O44.1', 'Maternity'],
  ['abruptio_placentae', 'Abruptio placentae', 'O45.9', 'Maternity'],
  ['postpartum_hemorrhage', 'Postpartum hemorrhage', 'O72.1', 'Maternity'],
  ['miscarriage', 'Miscarriage', 'O03.9', 'Maternity'],
  ['ectopic_pregnancy', 'Ectopic pregnancy', 'O00.9', 'Maternity'],
  ['obstructed_labor', 'Obstructed labor', 'O66.9', 'Maternity'],
  ['puerperal_sepsis', 'Puerperal sepsis', 'O85', 'Maternity'],
  ['premature_rupture_of_membranes', 'Premature rupture of membranes', 'O42.9', 'Maternity'],
  ['prolonged_labor', 'Prolonged labor', 'O63.9', 'Maternity'],
  ['neonatal_sepsis', 'Neonatal sepsis', 'P36.9', 'Neonatal'],
  ['neonatal_jaundice', 'Neonatal jaundice', 'P59.9', 'Neonatal'],
  ['prematurity', 'Prematurity', 'P07.3', 'Neonatal'],
  ['birth_asphyxia', 'Birth asphyxia', 'P21.9', 'Neonatal'],
  ['low_birth_weight', 'Low birth weight', 'P07.1', 'Neonatal'],

  // Oncology (high burden in Uganda)
  ['cervical_cancer', 'Malignant neoplasm of cervix uteri', 'C53.9', 'Oncology'],
  ['breast_cancer', 'Malignant neoplasm of breast', 'C50.9', 'Oncology'],
  ['esophageal_cancer', 'Malignant neoplasm of esophagus', 'C15.9', 'Oncology'],
  ['prostate_cancer', 'Malignant neoplasm of prostate', 'C61', 'Oncology'],
  ['liver_cancer', 'Malignant neoplasm of liver', 'C22.9', 'Oncology'],

  // ENT, eye, dental, skin
  ['otitis_media', 'Otitis media', 'H66.9', 'ENT'],
  ['allergic_rhinitis', 'Allergic rhinitis', 'J30.9', 'ENT'],
  ['tonsillitis', 'Tonsillitis', 'J03.9', 'ENT'],
  ['sinusitis', 'Sinusitis', 'J01.9', 'ENT'],
  ['conjunctivitis', 'Conjunctivitis', 'H10.9', 'Eye'],
  ['refractive_error', 'Refractive error', 'H52.7', 'Eye'],
  ['cataract', 'Cataract', 'H26.9', 'Eye'],
  ['glaucoma', 'Glaucoma', 'H40.9', 'Eye'],
  ['dental_caries', 'Dental caries', 'K02.9', 'Dental'],
  ['dental_abscess', 'Dental abscess', 'K04.7', 'Dental'],
  ['dermatitis', 'Dermatitis', 'L30.9', 'Skin'],
  ['tinea_infection', 'Tinea infection', 'B35.9', 'Skin'],
  ['scabies', 'Scabies', 'B86', 'Skin'],
  ['cellulitis', 'Cellulitis', 'L03.9', 'Skin'],
  ['skin_abscess', 'Skin abscess', 'L02.9', 'Skin'],
  ['wound_infection', 'Wound infection', 'L08.9', 'Skin'],

  // Musculoskeletal, trauma, emergency
  ['low_back_pain', 'Low back pain', 'M54.5', 'Musculoskeletal'],
  ['osteoarthritis', 'Osteoarthritis', 'M19.9', 'Musculoskeletal'],
  ['rheumatoid_arthritis', 'Rheumatoid arthritis', 'M06.9', 'Musculoskeletal'],
  ['burn_injury', 'Burn injury', 'T30.0', 'Emergency'],
  ['fracture_unspecified', 'Fracture, unspecified', 'T14.2', 'Trauma'],
  ['head_injury', 'Head injury', 'S09.9', 'Trauma'],
  ['road_traffic_injury', 'Road traffic injury', 'V89.2', 'Trauma'],
  ['snakebite_toxic_effect', 'Snakebite toxic effect', 'T63.0', 'Emergency'],
  ['poisoning_unspecified', 'Poisoning, unspecified', 'T65.9', 'Emergency'],
  ['anaphylaxis', 'Anaphylaxis', 'T78.2', 'Emergency'],
].map(diagnosisTerm));

module.exports = {
  UGANDA_DIAGNOSIS_CATALOG,
};
