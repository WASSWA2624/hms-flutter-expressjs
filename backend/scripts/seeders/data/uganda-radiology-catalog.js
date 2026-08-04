/**
 * Uganda-focused radiology / diagnostic imaging catalog seed data.
 *
 * Tuned for district and regional hospital workflows common in Uganda:
 * plain film, obstetric/general ultrasound, fluoroscopy, and referral-level
 * CT/MRI. Cardiac and endoscopy modalities are included because the HMS
 * ImagingModality enum supports them on radiology_procedure records.
 */

const { assertUniqueFields } = require('./catalog-validation');
const { UGANDA_CLINICAL_SOURCES } = require('./uganda-clinical-sources');

const IMAGING_SOURCE = `${UGANDA_CLINICAL_SOURCES.UG_MOH_UCG_2023.id}+${UGANDA_CLINICAL_SOURCES.WHO_DIAGNOSTIC_IMAGING.id}`;

const radiologyTest = (key, name, code, modality) => ({
  key,
  name,
  code,
  modality,
  source: IMAGING_SOURCE,
});

const XRAY_TESTS = [
  radiologyTest('xray_chest_pa', 'Chest X-Ray PA View', 'XR-CHEST-PA', 'XRAY'),
  radiologyTest('xray_chest_ap', 'Chest X-Ray AP Portable', 'XR-CHEST-AP', 'XRAY'),
  radiologyTest('xray_chest_lateral', 'Chest X-Ray Lateral View', 'XR-CHEST-LAT', 'XRAY'),
  radiologyTest('xray_abdomen_erect', 'Abdominal X-Ray Erect', 'XR-ABD-ERECT', 'XRAY'),
  radiologyTest('xray_abdomen_kub', 'Abdominal X-Ray KUB', 'XR-KUB', 'XRAY'),
  radiologyTest('xray_cervical_spine', 'Cervical Spine X-Ray', 'XR-CSPINE', 'XRAY'),
  radiologyTest('xray_thoracic_spine', 'Thoracic Spine X-Ray', 'XR-TSPINE', 'XRAY'),
  radiologyTest('xray_lumbar_spine', 'Lumbar Spine X-Ray', 'XR-LSPINE', 'XRAY'),
  radiologyTest('xray_pelvis', 'Pelvis X-Ray AP', 'XR-PELVIS', 'XRAY'),
  radiologyTest('xray_hip', 'Hip X-Ray', 'XR-HIP', 'XRAY'),
  radiologyTest('xray_femur', 'Femur X-Ray', 'XR-FEMUR', 'XRAY'),
  radiologyTest('xray_knee', 'Knee X-Ray', 'XR-KNEE', 'XRAY'),
  radiologyTest('xray_tibia_fibula', 'Tibia/Fibula X-Ray', 'XR-TIBFIB', 'XRAY'),
  radiologyTest('xray_ankle', 'Ankle X-Ray', 'XR-ANKLE', 'XRAY'),
  radiologyTest('xray_foot', 'Foot X-Ray', 'XR-FOOT', 'XRAY'),
  radiologyTest('xray_shoulder', 'Shoulder X-Ray', 'XR-SHOULDER', 'XRAY'),
  radiologyTest('xray_clavicle', 'Clavicle X-Ray', 'XR-CLAV', 'XRAY'),
  radiologyTest('xray_humerus', 'Humerus X-Ray', 'XR-HUM', 'XRAY'),
  radiologyTest('xray_elbow', 'Elbow X-Ray', 'XR-ELBOW', 'XRAY'),
  radiologyTest('xray_forearm', 'Forearm X-Ray', 'XR-FOREARM', 'XRAY'),
  radiologyTest('xray_wrist', 'Wrist X-Ray', 'XR-WRIST', 'XRAY'),
  radiologyTest('xray_hand', 'Hand X-Ray', 'XR-HAND', 'XRAY'),
  radiologyTest('xray_skull', 'Skull X-Ray', 'XR-SKULL', 'XRAY'),
  radiologyTest('xray_sinuses', 'Paranasal Sinus X-Ray', 'XR-SINUS', 'XRAY'),
  radiologyTest('xray_nasal_bones', 'Nasal Bones X-Ray', 'XR-NASAL', 'XRAY'),
  radiologyTest('xray_soft_tissue_neck', 'Soft Tissue Neck X-Ray', 'XR-STN', 'XRAY'),
  radiologyTest('xray_ribs', 'Rib X-Ray', 'XR-RIBS', 'XRAY'),
  radiologyTest('xray_sacroiliac_joints', 'Sacroiliac Joint X-Ray', 'XR-SIJ', 'XRAY'),
  radiologyTest('xray_mandible', 'Mandible X-Ray', 'XR-MANDIBLE', 'XRAY'),
  radiologyTest('xray_opg', 'Orthopantomogram (OPG)', 'XR-OPG', 'XRAY'),
  radiologyTest('xray_babygram', 'Babygram X-Ray', 'XR-BABYGRAM', 'XRAY'),
  radiologyTest('xray_bone_age', 'Bone Age X-Ray of Left Hand and Wrist', 'XR-BONE-AGE', 'XRAY'),
  radiologyTest('xray_skeletal_survey', 'Skeletal Survey X-Ray', 'XR-SKEL-SURV', 'XRAY'),
  radiologyTest('xray_shunt_series', 'Ventriculoperitoneal Shunt Series X-Ray', 'XR-VP-SHUNT', 'XRAY'),
];

const FLUOROSCOPY_TESTS = [
  radiologyTest('fluoro_barium_swallow', 'Barium Swallow', 'FL-BSWALLOW', 'FLUOROSCOPY'),
  radiologyTest('fluoro_barium_meal_follow_through', 'Barium Meal and Follow Through', 'FL-BMFT', 'FLUOROSCOPY'),
  radiologyTest('fluoro_barium_enema', 'Barium Enema', 'FL-BENEMA', 'FLUOROSCOPY'),
  radiologyTest('fluoro_hysterosalpingogram', 'Hysterosalpingogram', 'FL-HSG', 'FLUOROSCOPY'),
  radiologyTest('fluoro_micturating_cystourethrogram', 'Micturating Cystourethrogram', 'FL-MCU', 'FLUOROSCOPY'),
  radiologyTest('fluoro_intravenous_urogram', 'Intravenous Urogram', 'FL-IVU', 'FLUOROSCOPY'),
  radiologyTest('fluoro_retrograde_urethrogram', 'Retrograde Urethrogram', 'FL-RUG', 'FLUOROSCOPY'),
  radiologyTest('fluoro_small_bowel_follow_through', 'Small Bowel Follow Through', 'FL-SBFT', 'FLUOROSCOPY'),
  radiologyTest('fluoro_fistulogram', 'Fistulogram / Sinogram', 'FL-FIST', 'FLUOROSCOPY'),
];

const ULTRASOUND_TESTS = [
  radiologyTest('uss_abdomen', 'Abdominal Ultrasound', 'USS-ABD', 'ULTRASOUND'),
  radiologyTest('uss_abdominal_pelvic', 'Abdominal and Pelvic Ultrasound', 'USS-ABDOPELV', 'ULTRASOUND'),
  radiologyTest('uss_pelvis', 'Pelvic Ultrasound', 'USS-PELVIS', 'ULTRASOUND'),
  radiologyTest('uss_pelvis_transvaginal', 'Transvaginal Pelvic Ultrasound', 'USS-TV', 'ULTRASOUND'),
  radiologyTest('uss_obstetric_dating', 'Obstetric Dating Ultrasound', 'USS-DATING', 'ULTRASOUND'),
  radiologyTest('uss_obstetric', 'Obstetric Ultrasound', 'USS-OBS', 'ULTRASOUND'),
  radiologyTest('uss_obstetric_anomaly', 'Obstetric Anomaly Scan', 'USS-ANOMALY', 'ULTRASOUND'),
  radiologyTest('uss_obstetric_growth_doppler', 'Obstetric Growth and Doppler Scan', 'USS-GROWTH-DOP', 'ULTRASOUND'),
  radiologyTest('uss_biophysical_profile', 'Biophysical Profile Ultrasound', 'USS-BPP', 'ULTRASOUND'),
  radiologyTest('uss_follicular_tracking', 'Follicular Tracking Ultrasound', 'USS-FOLLICLE', 'ULTRASOUND'),
  radiologyTest('uss_renal', 'Renal Ultrasound', 'USS-RENAL', 'ULTRASOUND'),
  radiologyTest('uss_liver', 'Liver Ultrasound', 'USS-LIVER', 'ULTRASOUND'),
  radiologyTest('uss_gallbladder', 'Gallbladder Ultrasound', 'USS-GB', 'ULTRASOUND'),
  radiologyTest('uss_thyroid', 'Thyroid Ultrasound', 'USS-THYROID', 'ULTRASOUND'),
  radiologyTest('uss_neck', 'Neck Ultrasound', 'USS-NECK', 'ULTRASOUND'),
  radiologyTest('uss_breast', 'Breast Ultrasound', 'USS-BREAST', 'ULTRASOUND'),
  radiologyTest('uss_scrotal', 'Scrotal Ultrasound', 'USS-SCROTAL', 'ULTRASOUND'),
  radiologyTest('uss_prostate', 'Prostate Ultrasound', 'USS-PROSTATE', 'ULTRASOUND'),
  radiologyTest('uss_chest', 'Chest Ultrasound', 'USS-CHEST', 'ULTRASOUND'),
  radiologyTest('uss_fast', 'FAST Trauma Ultrasound', 'USS-FAST', 'ULTRASOUND'),
  radiologyTest('uss_soft_tissue', 'Soft Tissue Ultrasound', 'USS-SOFT', 'ULTRASOUND'),
  radiologyTest('uss_musculoskeletal', 'Musculoskeletal Ultrasound', 'USS-MSK', 'ULTRASOUND'),
  radiologyTest('uss_dvt_doppler', 'Lower Limb Venous Doppler', 'USS-DOPPLER-DVT', 'ULTRASOUND'),
  radiologyTest('uss_arterial_doppler_lower_limb', 'Lower Limb Arterial Doppler', 'USS-ART-DOP', 'ULTRASOUND'),
  radiologyTest('uss_carotid_doppler', 'Carotid Doppler Ultrasound', 'USS-CAROTID', 'ULTRASOUND'),
  radiologyTest('uss_neonatal_cranial', 'Neonatal Cranial Ultrasound', 'USS-CRANIAL-NEO', 'ULTRASOUND'),
  radiologyTest('uss_pediatric_hip', 'Pediatric Hip Ultrasound', 'USS-HIP-PED', 'ULTRASOUND'),
  radiologyTest('uss_appendix', 'Appendix Ultrasound', 'USS-APPENDIX', 'ULTRASOUND'),
  radiologyTest('uss_pylorus', 'Pyloric Stenosis Ultrasound', 'USS-PYLORUS', 'ULTRASOUND'),
  radiologyTest('uss_intussusception', 'Intussusception Ultrasound', 'USS-INTUSS', 'ULTRASOUND'),
  radiologyTest('uss_pleural', 'Pleural Ultrasound', 'USS-PLEURAL', 'ULTRASOUND'),
  radiologyTest('uss_upper_limb_venous_doppler', 'Upper Limb Venous Doppler', 'USS-DOPPLER-ULV', 'ULTRASOUND'),
  radiologyTest('uss_renal_artery_doppler', 'Renal Artery Doppler Ultrasound', 'USS-RENAL-ART', 'ULTRASOUND'),
];

const CT_TESTS = [
  radiologyTest('ct_head_non_contrast', 'CT Head Non-Contrast', 'CT-HEAD-NC', 'CT'),
  radiologyTest('ct_brain_contrast', 'CT Brain with Contrast', 'CT-BRAIN-C', 'CT'),
  radiologyTest('ct_cervical_spine', 'CT Cervical Spine', 'CT-CSPINE', 'CT'),
  radiologyTest('ct_thoracic_spine', 'CT Thoracic Spine', 'CT-TSPINE', 'CT'),
  radiologyTest('ct_lumbar_spine', 'CT Lumbar Spine', 'CT-LSPINE', 'CT'),
  radiologyTest('ct_chest', 'CT Chest', 'CT-CHEST', 'CT'),
  radiologyTest('ct_abdomen', 'CT Abdomen', 'CT-ABD', 'CT'),
  radiologyTest('ct_pelvis', 'CT Pelvis', 'CT-PELVIS', 'CT'),
  radiologyTest('ct_abdomen_pelvis', 'CT Abdomen and Pelvis', 'CT-ABDPELV', 'CT'),
  radiologyTest('ct_kub', 'CT KUB', 'CT-KUB', 'CT'),
  radiologyTest('ct_urogram', 'CT Urogram', 'CT-UROGRAM', 'CT'),
  radiologyTest('ct_pulmonary_angiogram', 'CT Pulmonary Angiogram', 'CT-CTPA', 'CT'),
  radiologyTest('ct_sinuses', 'CT Paranasal Sinuses', 'CT-SINUS', 'CT'),
  radiologyTest('ct_orbits', 'CT Orbits', 'CT-ORBITS', 'CT'),
  radiologyTest('ct_temporal_bones', 'CT Temporal Bones', 'CT-TBONE', 'CT'),
  radiologyTest('ct_angiography_head_neck', 'CT Angiography Head and Neck', 'CT-CTA-HN', 'CT'),
  radiologyTest('ct_angiography_lower_limb', 'CT Angiography Lower Limb', 'CT-CTA-LL', 'CT'),
  radiologyTest('ct_maxillofacial', 'CT Maxillofacial', 'CT-MAXFACE', 'CT'),
  radiologyTest('ct_neck_contrast', 'CT Neck with Contrast', 'CT-NECK-C', 'CT'),
  radiologyTest('ct_aortic_angiogram', 'CT Aortic Angiogram', 'CT-CTA-AORTA', 'CT'),
  radiologyTest('ct_triphasic_liver', 'CT Liver Triphasic Protocol', 'CT-LIVER-3PH', 'CT'),
  radiologyTest('ct_extremity', 'CT Extremity', 'CT-EXTREMITY', 'CT'),
];

const MRI_TESTS = [
  radiologyTest('mri_brain', 'MRI Brain', 'MRI-BRAIN', 'MRI'),
  radiologyTest('mri_brain_contrast', 'MRI Brain with Contrast', 'MRI-BRAIN-C', 'MRI'),
  radiologyTest('mri_stroke_protocol', 'MRI Brain Stroke Protocol', 'MRI-STROKE', 'MRI'),
  radiologyTest('mri_cervical_spine', 'MRI Cervical Spine', 'MRI-CSPINE', 'MRI'),
  radiologyTest('mri_thoracic_spine', 'MRI Thoracic Spine', 'MRI-TSPINE', 'MRI'),
  radiologyTest('mri_lumbar_spine', 'MRI Lumbar Spine', 'MRI-LSPINE', 'MRI'),
  radiologyTest('mri_abdomen_pelvis', 'MRI Abdomen and Pelvis', 'MRI-ABDPELV', 'MRI'),
  radiologyTest('mri_pelvis', 'MRI Pelvis', 'MRI-PELVIS', 'MRI'),
  radiologyTest('mri_knee', 'MRI Knee', 'MRI-KNEE', 'MRI'),
  radiologyTest('mri_shoulder', 'MRI Shoulder', 'MRI-SHOULDER', 'MRI'),
  radiologyTest('mri_ankle', 'MRI Ankle', 'MRI-ANKLE', 'MRI'),
  radiologyTest('mri_wrist', 'MRI Wrist', 'MRI-WRIST', 'MRI'),
  radiologyTest('mri_pituitary', 'MRI Pituitary with Contrast', 'MRI-PITUITARY', 'MRI'),
  radiologyTest('mri_orbits', 'MRI Orbits with Contrast', 'MRI-ORBITS', 'MRI'),
  radiologyTest('mri_internal_auditory_canals', 'MRI Internal Auditory Canals', 'MRI-IAC', 'MRI'),
  radiologyTest('mri_mrcp', 'Magnetic Resonance Cholangiopancreatography', 'MRI-MRCP', 'MRI'),
  radiologyTest('mri_liver', 'MRI Liver', 'MRI-LIVER', 'MRI'),
  radiologyTest('mri_prostate', 'MRI Prostate Multiparametric', 'MRI-PROSTATE', 'MRI'),
  radiologyTest('mri_rectal_staging', 'MRI Rectal Cancer Staging', 'MRI-RECTAL', 'MRI'),
  radiologyTest('mri_female_pelvis', 'MRI Female Pelvis', 'MRI-FPELVIS', 'MRI'),
  radiologyTest('mri_whole_spine', 'MRI Whole Spine', 'MRI-WSPINE', 'MRI'),
  radiologyTest('mri_hip', 'MRI Hip', 'MRI-HIP', 'MRI'),
  radiologyTest('mri_angiography_brain', 'MR Angiography Brain', 'MRI-MRA-BRAIN', 'MRI'),
  radiologyTest('mri_venography_brain', 'MR Venography Brain', 'MRI-MRV-BRAIN', 'MRI'),
];

const MAMMOGRAPHY_TESTS = [
  radiologyTest('mammography_screening', 'Mammography Screening Bilateral', 'MAMMO-SCREEN', 'MAMMOGRAPHY'),
  radiologyTest('mammography_diagnostic', 'Mammography Diagnostic Bilateral', 'MAMMO-DX', 'MAMMOGRAPHY'),
  radiologyTest('mammography_unilateral', 'Mammography Unilateral', 'MAMMO-UNI', 'MAMMOGRAPHY'),
];

const CARDIAC_TESTS = [
  radiologyTest('ecg_resting', 'ECG Resting 12 Lead', 'ECG-12', 'ECG'),
  radiologyTest('ecg_holter', 'ECG Holter 24 Hour', 'ECG-HOLTER', 'ECG'),
  radiologyTest('ecg_exercise_stress', 'Exercise Stress ECG', 'ECG-STRESS', 'ECG'),
  radiologyTest('echo_transthoracic', 'Transthoracic Echocardiogram', 'ECHO-TTE', 'ECHO'),
  radiologyTest('echo_focused', 'Focused Cardiac Ultrasound', 'ECHO-FOCUS', 'ECHO'),
  radiologyTest('echo_pediatric_congenital', 'Pediatric Congenital Echocardiogram', 'ECHO-PED', 'ECHO'),
  radiologyTest('echo_transesophageal', 'Transesophageal Echocardiogram', 'ECHO-TEE', 'ECHO'),
  radiologyTest('echo_stress', 'Stress Echocardiogram', 'ECHO-STRESS', 'ECHO'),
];

const ENDO_GASTRO_TESTS = [
  radiologyTest('endo_upper_gi', 'Upper GI Endoscopy', 'ENDO-UGI', 'ENDO'),
  radiologyTest('endo_bronchoscopy', 'Bronchoscopy', 'ENDO-BRONCH', 'ENDO'),
  radiologyTest('gastro_colonoscopy', 'Colonoscopy', 'GASTRO-COLON', 'GASTRO'),
  radiologyTest('gastro_sigmoidoscopy', 'Flexible Sigmoidoscopy', 'GASTRO-SIG', 'GASTRO'),
  radiologyTest('gastro_ercp', 'Endoscopic Retrograde Cholangiopancreatography', 'GASTRO-ERCP', 'GASTRO'),
];

const OTHER_IMAGING_TESTS = [
  radiologyTest('ir_image_guided_biopsy', 'Image-Guided Biopsy', 'IR-BIOPSY', 'INTERVENTIONAL_RADIOLOGY'),
  radiologyTest('ir_abscess_drainage', 'Image-Guided Abscess Drainage', 'IR-DRAIN', 'INTERVENTIONAL_RADIOLOGY'),
  radiologyTest('ir_percutaneous_nephrostomy', 'Percutaneous Nephrostomy', 'IR-PCN', 'INTERVENTIONAL_RADIOLOGY'),
  radiologyTest('ir_biliary_drainage', 'Percutaneous Biliary Drainage', 'IR-PTBD', 'INTERVENTIONAL_RADIOLOGY'),
  radiologyTest('ir_central_venous_access', 'Image-Guided Central Venous Access', 'IR-CVA', 'INTERVENTIONAL_RADIOLOGY'),
  radiologyTest('ir_joint_injection', 'Image-Guided Joint Injection or Aspiration', 'IR-JOINT', 'INTERVENTIONAL_RADIOLOGY'),
  radiologyTest('ir_breast_biopsy', 'Image-Guided Breast Biopsy', 'IR-BREAST-BX', 'INTERVENTIONAL_RADIOLOGY'),
  radiologyTest('ir_thyroid_fna', 'Ultrasound-Guided Thyroid FNA', 'IR-THY-FNA', 'INTERVENTIONAL_RADIOLOGY'),
];

const radiologyCatalog = [
  ...XRAY_TESTS,
  ...FLUOROSCOPY_TESTS,
  ...ULTRASOUND_TESTS,
  ...CT_TESTS,
  ...MRI_TESTS,
  ...MAMMOGRAPHY_TESTS,
  ...CARDIAC_TESTS,
  ...ENDO_GASTRO_TESTS,
  ...OTHER_IMAGING_TESTS,
];

assertUniqueFields(radiologyCatalog, {
  label: 'RADIOLOGY_TEST_CATALOG',
  fields: ['key', 'name', 'code'],
});

const RADIOLOGY_TEST_CATALOG = Object.freeze(radiologyCatalog);

module.exports = {
  RADIOLOGY_TEST_CATALOG,
};
