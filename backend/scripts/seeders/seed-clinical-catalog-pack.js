const { DEMO_TENANTS } = require('./seed-catalog');
const {
  LAB_TEST_CATALOG,
  LAB_PANEL_CATALOG,
  seedLabCatalogForTenant,
} = require('./seed-lab-catalog-pack');

const DEFAULT_DRUG_INITIAL_STOCK = 180;
const DEFAULT_DRUG_REORDER_LEVEL = 40;

const radiologyTest = (key, name, code, modality) => ({
  key,
  name,
  code,
  modality,
});

const drugSpec = ({
  key,
  name,
  code,
  form,
  strength,
  inventoryUnit = null,
  initialStock = DEFAULT_DRUG_INITIAL_STOCK,
  reorderLevel = DEFAULT_DRUG_REORDER_LEVEL,
  deductionFactor = 1,
}) => ({
  key,
  name,
  code,
  form,
  strength,
  inventory_unit: inventoryUnit,
  initial_stock: initialStock,
  reorder_level: reorderLevel,
  deduction_factor: deductionFactor,
});

const XRAY_TESTS = [
  radiologyTest('xray_chest_pa', 'Chest X-Ray PA View', 'XR-CHEST-PA', 'XRAY'),
  radiologyTest('xray_chest_ap', 'Chest X-Ray AP Portable', 'XR-CHEST-AP', 'XRAY'),
  radiologyTest('xray_abdomen_erect', 'Abdominal X-Ray Erect', 'XR-ABD-ERECT', 'XRAY'),
  radiologyTest('xray_abdomen_kub', 'Abdominal X-Ray KUB', 'XR-KUB', 'XRAY'),
  radiologyTest('xray_cervical_spine', 'Cervical Spine X-Ray', 'XR-CSPINE', 'XRAY'),
  radiologyTest('xray_thoracic_spine', 'Thoracic Spine X-Ray', 'XR-TSPINE', 'XRAY'),
  radiologyTest('xray_lumbar_spine', 'Lumbar Spine X-Ray', 'XR-LSPINE', 'XRAY'),
  radiologyTest('xray_pelvis', 'Pelvis X-Ray AP', 'XR-PELVIS', 'XRAY'),
  radiologyTest('xray_hip', 'Hip X-Ray', 'XR-HIP', 'XRAY'),
  radiologyTest('xray_knee', 'Knee X-Ray', 'XR-KNEE', 'XRAY'),
  radiologyTest('xray_shoulder', 'Shoulder X-Ray', 'XR-SHOULDER', 'XRAY'),
  radiologyTest('xray_hand_wrist', 'Hand and Wrist X-Ray', 'XR-HAND', 'XRAY'),
  radiologyTest('xray_ankle_foot', 'Ankle and Foot X-Ray', 'XR-FOOT', 'XRAY'),
];

const CT_TESTS = [
  radiologyTest('ct_head_non_contrast', 'CT Head Non-Contrast', 'CT-HEAD-NC', 'CT'),
  radiologyTest('ct_brain_contrast', 'CT Brain with Contrast', 'CT-BRAIN-C', 'CT'),
  radiologyTest('ct_cervical_spine', 'CT Cervical Spine', 'CT-CSPINE', 'CT'),
  radiologyTest('ct_chest', 'CT Chest', 'CT-CHEST', 'CT'),
  radiologyTest('ct_abdomen_pelvis', 'CT Abdomen and Pelvis', 'CT-ABDPELV', 'CT'),
  radiologyTest('ct_kub', 'CT KUB', 'CT-KUB', 'CT'),
  radiologyTest('ct_pulmonary_angiogram', 'CT Pulmonary Angiogram', 'CT-CTPA', 'CT'),
  radiologyTest('ct_sinuses', 'CT Paranasal Sinuses', 'CT-SINUS', 'CT'),
];

const MRI_TESTS = [
  radiologyTest('mri_brain', 'MRI Brain', 'MRI-BRAIN', 'MRI'),
  radiologyTest('mri_cervical_spine', 'MRI Cervical Spine', 'MRI-CSPINE', 'MRI'),
  radiologyTest('mri_lumbar_spine', 'MRI Lumbar Spine', 'MRI-LSPINE', 'MRI'),
  radiologyTest('mri_knee', 'MRI Knee', 'MRI-KNEE', 'MRI'),
  radiologyTest('mri_shoulder', 'MRI Shoulder', 'MRI-SHOULDER', 'MRI'),
  radiologyTest('mri_abdomen_pelvis', 'MRI Abdomen and Pelvis', 'MRI-ABDPELV', 'MRI'),
];

const ULTRASOUND_TESTS = [
  radiologyTest('uss_abdomen', 'Abdominal Ultrasound', 'USS-ABD', 'ULTRASOUND'),
  radiologyTest('uss_pelvis', 'Pelvic Ultrasound', 'USS-PELVIS', 'ULTRASOUND'),
  radiologyTest('uss_obstetric', 'Obstetric Ultrasound', 'USS-OBS', 'ULTRASOUND'),
  radiologyTest('uss_renal', 'Renal Ultrasound', 'USS-RENAL', 'ULTRASOUND'),
  radiologyTest('uss_thyroid', 'Thyroid Ultrasound', 'USS-THYROID', 'ULTRASOUND'),
  radiologyTest('uss_breast', 'Breast Ultrasound', 'USS-BREAST', 'ULTRASOUND'),
  radiologyTest('uss_dvt_doppler', 'Lower Limb Venous Doppler', 'USS-DOPPLER-DVT', 'ULTRASOUND'),
];

const CARDIAC_TESTS = [
  radiologyTest('ecg_resting', 'ECG Resting 12 Lead', 'ECG-12', 'ECG'),
  radiologyTest('ecg_holter', 'ECG Holter 24 Hour', 'ECG-HOLTER', 'ECG'),
  radiologyTest('echo_transthoracic', 'Transthoracic Echocardiogram', 'ECHO-TTE', 'ECHO'),
  radiologyTest('echo_focused', 'Focused Cardiac Ultrasound', 'ECHO-FOCUS', 'ECHO'),
];

const ENDO_GASTRO_TESTS = [
  radiologyTest('endo_upper_gi', 'Upper GI Endoscopy', 'ENDO-UGI', 'ENDO'),
  radiologyTest('endo_bronchoscopy', 'Bronchoscopy', 'ENDO-BRONCH', 'ENDO'),
  radiologyTest('gastro_colonoscopy', 'Colonoscopy', 'GASTRO-COLON', 'GASTRO'),
  radiologyTest('gastro_sigmoidoscopy', 'Flexible Sigmoidoscopy', 'GASTRO-SIG', 'GASTRO'),
];

const OTHER_RADIOLOGY_TESTS = [
  radiologyTest('other_mammography', 'Mammography Bilateral', 'IMG-MAMMO', 'OTHER'),
  radiologyTest('other_dexa', 'DEXA Bone Densitometry', 'IMG-DEXA', 'OTHER'),
];

const RADIOLOGY_TEST_CATALOG = Object.freeze([
  ...XRAY_TESTS,
  ...CT_TESTS,
  ...MRI_TESTS,
  ...ULTRASOUND_TESTS,
  ...CARDIAC_TESTS,
  ...ENDO_GASTRO_TESTS,
  ...OTHER_RADIOLOGY_TESTS,
]);

const ANALGESIC_DRUGS = [
  drugSpec({ key: 'paracetamol_500_tablet', name: 'Paracetamol', code: 'PCM500', form: 'Tablet', strength: '500 mg', inventoryUnit: 'tablet', initialStock: 1200, reorderLevel: 250 }),
  drugSpec({ key: 'paracetamol_suspension', name: 'Paracetamol', code: 'PCM120S', form: 'Suspension', strength: '120 mg/5 mL', inventoryUnit: 'bottle', initialStock: 80, reorderLevel: 20 }),
  drugSpec({ key: 'ibuprofen_400_tablet', name: 'Ibuprofen', code: 'IBU400', form: 'Tablet', strength: '400 mg', inventoryUnit: 'tablet', initialStock: 900, reorderLevel: 180 }),
  drugSpec({ key: 'ibuprofen_suspension', name: 'Ibuprofen', code: 'IBU100S', form: 'Suspension', strength: '100 mg/5 mL', inventoryUnit: 'bottle', initialStock: 60, reorderLevel: 15 }),
  drugSpec({ key: 'diclofenac_50_tablet', name: 'Diclofenac', code: 'DCF50', form: 'Tablet', strength: '50 mg', inventoryUnit: 'tablet', initialStock: 700, reorderLevel: 140 }),
  drugSpec({ key: 'diclofenac_injection', name: 'Diclofenac', code: 'DCF75I', form: 'Injection', strength: '75 mg/3 mL', inventoryUnit: 'ampoule', initialStock: 120, reorderLevel: 30 }),
  drugSpec({ key: 'tramadol_50_capsule', name: 'Tramadol', code: 'TRM50', form: 'Capsule', strength: '50 mg', inventoryUnit: 'capsule', initialStock: 500, reorderLevel: 100 }),
  drugSpec({ key: 'morphine_injection', name: 'Morphine', code: 'MRF10I', form: 'Injection', strength: '10 mg/mL', inventoryUnit: 'ampoule', initialStock: 90, reorderLevel: 20 }),
  drugSpec({ key: 'aspirin_81_tablet', name: 'Aspirin', code: 'ASP81', form: 'Tablet', strength: '81 mg', inventoryUnit: 'tablet', initialStock: 700, reorderLevel: 120 }),
  drugSpec({ key: 'aspirin_300_tablet', name: 'Aspirin', code: 'ASP300', form: 'Tablet', strength: '300 mg', inventoryUnit: 'tablet', initialStock: 420, reorderLevel: 90 }),
];

const ANTI_INFECTIVE_DRUGS = [
  drugSpec({ key: 'amoxicillin_500_capsule', name: 'Amoxicillin', code: 'AMX500', form: 'Capsule', strength: '500 mg', inventoryUnit: 'capsule', initialStock: 1200, reorderLevel: 240 }),
  drugSpec({ key: 'amoxiclav_625_tablet', name: 'Amoxicillin + Clavulanate', code: 'AMC625', form: 'Tablet', strength: '625 mg', inventoryUnit: 'tablet', initialStock: 900, reorderLevel: 180 }),
  drugSpec({ key: 'azithromycin_500_tablet', name: 'Azithromycin', code: 'AZM500', form: 'Tablet', strength: '500 mg', inventoryUnit: 'tablet', initialStock: 450, reorderLevel: 100 }),
  drugSpec({ key: 'cefixime_400_capsule', name: 'Cefixime', code: 'CFX400', form: 'Capsule', strength: '400 mg', inventoryUnit: 'capsule', initialStock: 260, reorderLevel: 60 }),
  drugSpec({ key: 'cefuroxime_500_tablet', name: 'Cefuroxime', code: 'CFU500', form: 'Tablet', strength: '500 mg', inventoryUnit: 'tablet', initialStock: 300, reorderLevel: 70 }),
  drugSpec({ key: 'ceftriaxone_1g_injection', name: 'Ceftriaxone', code: 'CRO1G', form: 'Injection', strength: '1 g', inventoryUnit: 'vial', initialStock: 220, reorderLevel: 50 }),
  drugSpec({ key: 'ciprofloxacin_500_tablet', name: 'Ciprofloxacin', code: 'CIP500', form: 'Tablet', strength: '500 mg', inventoryUnit: 'tablet', initialStock: 600, reorderLevel: 120 }),
  drugSpec({ key: 'cloxacillin_500_capsule', name: 'Cloxacillin', code: 'CLX500', form: 'Capsule', strength: '500 mg', inventoryUnit: 'capsule', initialStock: 480, reorderLevel: 100 }),
  drugSpec({ key: 'doxycycline_100_capsule', name: 'Doxycycline', code: 'DOX100', form: 'Capsule', strength: '100 mg', inventoryUnit: 'capsule', initialStock: 360, reorderLevel: 80 }),
  drugSpec({ key: 'flucloxacillin_500_capsule', name: 'Flucloxacillin', code: 'FLX500', form: 'Capsule', strength: '500 mg', inventoryUnit: 'capsule', initialStock: 300, reorderLevel: 70 }),
  drugSpec({ key: 'gentamicin_80_injection', name: 'Gentamicin', code: 'GEN80I', form: 'Injection', strength: '80 mg/2 mL', inventoryUnit: 'ampoule', initialStock: 160, reorderLevel: 40 }),
  drugSpec({ key: 'metronidazole_400_tablet', name: 'Metronidazole', code: 'MTZ400', form: 'Tablet', strength: '400 mg', inventoryUnit: 'tablet', initialStock: 720, reorderLevel: 150 }),
  drugSpec({ key: 'metronidazole_infusion', name: 'Metronidazole', code: 'MTZIV', form: 'Infusion', strength: '500 mg/100 mL', inventoryUnit: 'bag', initialStock: 120, reorderLevel: 30 }),
  drugSpec({ key: 'nitrofurantoin_100_capsule', name: 'Nitrofurantoin', code: 'NFT100', form: 'Capsule', strength: '100 mg', inventoryUnit: 'capsule', initialStock: 240, reorderLevel: 50 }),
  drugSpec({ key: 'cotrimoxazole_960_tablet', name: 'Co-trimoxazole', code: 'CTX960', form: 'Tablet', strength: '960 mg', inventoryUnit: 'tablet', initialStock: 600, reorderLevel: 120 }),
  drugSpec({ key: 'penicillin_v_250_tablet', name: 'Penicillin V', code: 'PNV250', form: 'Tablet', strength: '250 mg', inventoryUnit: 'tablet', initialStock: 420, reorderLevel: 90 }),
  drugSpec({ key: 'fluconazole_150_capsule', name: 'Fluconazole', code: 'FLU150', form: 'Capsule', strength: '150 mg', inventoryUnit: 'capsule', initialStock: 180, reorderLevel: 40 }),
  drugSpec({ key: 'acyclovir_400_tablet', name: 'Acyclovir', code: 'ACV400', form: 'Tablet', strength: '400 mg', inventoryUnit: 'tablet', initialStock: 150, reorderLevel: 35 }),
  drugSpec({ key: 'nystatin_suspension', name: 'Nystatin', code: 'NYS100', form: 'Suspension', strength: '100,000 IU/mL', inventoryUnit: 'bottle', initialStock: 45, reorderLevel: 12 }),
  drugSpec({ key: 'clotrimazole_cream', name: 'Clotrimazole', code: 'CLTCRM', form: 'Cream', strength: '1%', inventoryUnit: 'tube', initialStock: 90, reorderLevel: 20 }),
];

const ANTIML_ENDO_DRUGS = [
  drugSpec({ key: 'artemether_lumefantrine', name: 'Artemether + Lumefantrine', code: 'AL20/120', form: 'Tablet', strength: '20/120 mg', inventoryUnit: 'tablet', initialStock: 840, reorderLevel: 160 }),
  drugSpec({ key: 'dihydroartemisinin_piperaquine', name: 'Dihydroartemisinin + Piperaquine', code: 'DHA40/320', form: 'Tablet', strength: '40/320 mg', inventoryUnit: 'tablet', initialStock: 300, reorderLevel: 60 }),
  drugSpec({ key: 'artesunate_60_injection', name: 'Artesunate', code: 'ART60I', form: 'Injection', strength: '60 mg', inventoryUnit: 'vial', initialStock: 120, reorderLevel: 25 }),
  drugSpec({ key: 'quinine_300_tablet', name: 'Quinine', code: 'QNN300', form: 'Tablet', strength: '300 mg', inventoryUnit: 'tablet', initialStock: 240, reorderLevel: 50 }),
  drugSpec({ key: 'quinine_injection', name: 'Quinine', code: 'QNN600I', form: 'Injection', strength: '600 mg/2 mL', inventoryUnit: 'ampoule', initialStock: 80, reorderLevel: 20 }),
  drugSpec({ key: 'sulfadoxine_pyrimethamine', name: 'Sulfadoxine + Pyrimethamine', code: 'SP500/25', form: 'Tablet', strength: '500/25 mg', inventoryUnit: 'tablet', initialStock: 180, reorderLevel: 40 }),
  drugSpec({ key: 'albendazole_400_chewable', name: 'Albendazole', code: 'ALB400', form: 'Chewable Tablet', strength: '400 mg', inventoryUnit: 'tablet', initialStock: 220, reorderLevel: 50 }),
  drugSpec({ key: 'mebendazole_100_tablet', name: 'Mebendazole', code: 'MBD100', form: 'Tablet', strength: '100 mg', inventoryUnit: 'tablet', initialStock: 200, reorderLevel: 40 }),
  drugSpec({ key: 'metformin_500_tablet', name: 'Metformin', code: 'MET500', form: 'Tablet', strength: '500 mg', inventoryUnit: 'tablet', initialStock: 720, reorderLevel: 140 }),
  drugSpec({ key: 'glibenclamide_5_tablet', name: 'Glibenclamide', code: 'GLB5', form: 'Tablet', strength: '5 mg', inventoryUnit: 'tablet', initialStock: 420, reorderLevel: 80 }),
  drugSpec({ key: 'insulin_regular_vial', name: 'Insulin Regular', code: 'INS-R', form: 'Injection', strength: '100 IU/mL', inventoryUnit: 'vial', initialStock: 70, reorderLevel: 18 }),
  drugSpec({ key: 'insulin_nph_vial', name: 'Insulin NPH', code: 'INS-NPH', form: 'Injection', strength: '100 IU/mL', inventoryUnit: 'vial', initialStock: 70, reorderLevel: 18 }),
  drugSpec({ key: 'insulin_premix_vial', name: 'Insulin 30/70 Premix', code: 'INS-30/70', form: 'Injection', strength: '100 IU/mL', inventoryUnit: 'vial', initialStock: 50, reorderLevel: 12 }),
  drugSpec({ key: 'levothyroxine_50_tablet', name: 'Levothyroxine', code: 'LEV50', form: 'Tablet', strength: '50 mcg', inventoryUnit: 'tablet', initialStock: 240, reorderLevel: 50 }),
];

const GI_RESP_DRUGS = [
  drugSpec({ key: 'omeprazole_20_capsule', name: 'Omeprazole', code: 'OMP20', form: 'Capsule', strength: '20 mg', inventoryUnit: 'capsule', initialStock: 720, reorderLevel: 140 }),
  drugSpec({ key: 'pantoprazole_injection', name: 'Pantoprazole', code: 'PAN40I', form: 'Injection', strength: '40 mg', inventoryUnit: 'vial', initialStock: 90, reorderLevel: 20 }),
  drugSpec({ key: 'antacid_suspension', name: 'Antacid Suspension', code: 'ANTACID', form: 'Suspension', strength: 'Al/Mg hydroxide', inventoryUnit: 'bottle', initialStock: 70, reorderLevel: 18 }),
  drugSpec({ key: 'ondansetron_4_tablet', name: 'Ondansetron', code: 'OND4', form: 'Tablet', strength: '4 mg', inventoryUnit: 'tablet', initialStock: 300, reorderLevel: 60 }),
  drugSpec({ key: 'ondansetron_injection', name: 'Ondansetron', code: 'OND8I', form: 'Injection', strength: '8 mg/4 mL', inventoryUnit: 'ampoule', initialStock: 80, reorderLevel: 20 }),
  drugSpec({ key: 'metoclopramide_10_tablet', name: 'Metoclopramide', code: 'MCP10', form: 'Tablet', strength: '10 mg', inventoryUnit: 'tablet', initialStock: 260, reorderLevel: 50 }),
  drugSpec({ key: 'ors_sachet', name: 'Oral Rehydration Salts', code: 'ORS', form: 'Sachet', strength: 'WHO formula', inventoryUnit: 'sachet', initialStock: 300, reorderLevel: 70 }),
  drugSpec({ key: 'loperamide_2_capsule', name: 'Loperamide', code: 'LOP2', form: 'Capsule', strength: '2 mg', inventoryUnit: 'capsule', initialStock: 180, reorderLevel: 40 }),
  drugSpec({ key: 'lactulose_syrup', name: 'Lactulose', code: 'LACSYR', form: 'Syrup', strength: '3.35 g/5 mL', inventoryUnit: 'bottle', initialStock: 35, reorderLevel: 10 }),
  drugSpec({ key: 'salbutamol_inhaler', name: 'Salbutamol', code: 'SALINH', form: 'Inhaler', strength: '100 mcg/dose', inventoryUnit: 'inhaler', initialStock: 80, reorderLevel: 18 }),
  drugSpec({ key: 'salbutamol_nebule', name: 'Salbutamol', code: 'SALNEB', form: 'Nebule', strength: '2.5 mg/2.5 mL', inventoryUnit: 'nebule', initialStock: 150, reorderLevel: 35 }),
  drugSpec({ key: 'beclomethasone_inhaler', name: 'Beclomethasone', code: 'BECINH', form: 'Inhaler', strength: '100 mcg/dose', inventoryUnit: 'inhaler', initialStock: 45, reorderLevel: 12 }),
  drugSpec({ key: 'prednisolone_5_tablet', name: 'Prednisolone', code: 'PRD5', form: 'Tablet', strength: '5 mg', inventoryUnit: 'tablet', initialStock: 320, reorderLevel: 60 }),
  drugSpec({ key: 'hydrocortisone_100_injection', name: 'Hydrocortisone', code: 'HCT100I', form: 'Injection', strength: '100 mg', inventoryUnit: 'vial', initialStock: 90, reorderLevel: 22 }),
  drugSpec({ key: 'cetirizine_10_tablet', name: 'Cetirizine', code: 'CTZ10', form: 'Tablet', strength: '10 mg', inventoryUnit: 'tablet', initialStock: 320, reorderLevel: 60 }),
  drugSpec({ key: 'loratadine_10_tablet', name: 'Loratadine', code: 'LOR10', form: 'Tablet', strength: '10 mg', inventoryUnit: 'tablet', initialStock: 220, reorderLevel: 50 }),
  drugSpec({ key: 'chlorpheniramine_syrup', name: 'Chlorpheniramine', code: 'CPMSYR', form: 'Syrup', strength: '2 mg/5 mL', inventoryUnit: 'bottle', initialStock: 35, reorderLevel: 10 }),
];

const CV_OBGYN_DRUGS = [
  drugSpec({ key: 'amlodipine_5_tablet', name: 'Amlodipine', code: 'AML5', form: 'Tablet', strength: '5 mg', inventoryUnit: 'tablet', initialStock: 800, reorderLevel: 150 }),
  drugSpec({ key: 'nifedipine_20_tablet', name: 'Nifedipine Retard', code: 'NIF20', form: 'Tablet', strength: '20 mg', inventoryUnit: 'tablet', initialStock: 260, reorderLevel: 50 }),
  drugSpec({ key: 'losartan_50_tablet', name: 'Losartan', code: 'LOS50', form: 'Tablet', strength: '50 mg', inventoryUnit: 'tablet', initialStock: 400, reorderLevel: 80 }),
  drugSpec({ key: 'enalapril_10_tablet', name: 'Enalapril', code: 'ENA10', form: 'Tablet', strength: '10 mg', inventoryUnit: 'tablet', initialStock: 420, reorderLevel: 80 }),
  drugSpec({ key: 'lisinopril_10_tablet', name: 'Lisinopril', code: 'LIS10', form: 'Tablet', strength: '10 mg', inventoryUnit: 'tablet', initialStock: 260, reorderLevel: 50 }),
  drugSpec({ key: 'hydrochlorothiazide_25_tablet', name: 'Hydrochlorothiazide', code: 'HCT25', form: 'Tablet', strength: '25 mg', inventoryUnit: 'tablet', initialStock: 360, reorderLevel: 70 }),
  drugSpec({ key: 'furosemide_40_tablet', name: 'Furosemide', code: 'FUR40', form: 'Tablet', strength: '40 mg', inventoryUnit: 'tablet', initialStock: 320, reorderLevel: 60 }),
  drugSpec({ key: 'furosemide_injection', name: 'Furosemide', code: 'FUR20I', form: 'Injection', strength: '20 mg/2 mL', inventoryUnit: 'ampoule', initialStock: 90, reorderLevel: 20 }),
  drugSpec({ key: 'spironolactone_25_tablet', name: 'Spironolactone', code: 'SPI25', form: 'Tablet', strength: '25 mg', inventoryUnit: 'tablet', initialStock: 260, reorderLevel: 50 }),
  drugSpec({ key: 'atenolol_50_tablet', name: 'Atenolol', code: 'ATN50', form: 'Tablet', strength: '50 mg', inventoryUnit: 'tablet', initialStock: 240, reorderLevel: 50 }),
  drugSpec({ key: 'carvedilol_12_5_tablet', name: 'Carvedilol', code: 'CRV12.5', form: 'Tablet', strength: '12.5 mg', inventoryUnit: 'tablet', initialStock: 180, reorderLevel: 40 }),
  drugSpec({ key: 'atorvastatin_20_tablet', name: 'Atorvastatin', code: 'ATO20', form: 'Tablet', strength: '20 mg', inventoryUnit: 'tablet', initialStock: 220, reorderLevel: 45 }),
  drugSpec({ key: 'simvastatin_20_tablet', name: 'Simvastatin', code: 'SIM20', form: 'Tablet', strength: '20 mg', inventoryUnit: 'tablet', initialStock: 160, reorderLevel: 35 }),
  drugSpec({ key: 'clopidogrel_75_tablet', name: 'Clopidogrel', code: 'CLP75', form: 'Tablet', strength: '75 mg', inventoryUnit: 'tablet', initialStock: 150, reorderLevel: 30 }),
  drugSpec({ key: 'warfarin_5_tablet', name: 'Warfarin', code: 'WAR5', form: 'Tablet', strength: '5 mg', inventoryUnit: 'tablet', initialStock: 120, reorderLevel: 25 }),
  drugSpec({ key: 'heparin_injection', name: 'Heparin', code: 'HEP5K', form: 'Injection', strength: '5,000 IU/mL', inventoryUnit: 'vial', initialStock: 75, reorderLevel: 18 }),
  drugSpec({ key: 'ferrous_folate_tablet', name: 'Ferrous Sulfate + Folic Acid', code: 'FERFOL', form: 'Tablet', strength: '200 mg + 0.25 mg', inventoryUnit: 'tablet', initialStock: 900, reorderLevel: 180 }),
  drugSpec({ key: 'folic_acid_5_tablet', name: 'Folic Acid', code: 'FOL5', form: 'Tablet', strength: '5 mg', inventoryUnit: 'tablet', initialStock: 300, reorderLevel: 60 }),
  drugSpec({ key: 'oxytocin_injection', name: 'Oxytocin', code: 'OXY10I', form: 'Injection', strength: '10 IU/mL', inventoryUnit: 'ampoule', initialStock: 120, reorderLevel: 28 }),
  drugSpec({ key: 'magnesium_sulfate_injection', name: 'Magnesium Sulfate', code: 'MGS50I', form: 'Injection', strength: '50%', inventoryUnit: 'ampoule', initialStock: 90, reorderLevel: 22 }),
  drugSpec({ key: 'misoprostol_200_tablet', name: 'Misoprostol', code: 'MISO200', form: 'Tablet', strength: '200 mcg', inventoryUnit: 'tablet', initialStock: 140, reorderLevel: 30 }),
  drugSpec({ key: 'medroxyprogesterone_injection', name: 'Medroxyprogesterone', code: 'DMPA150', form: 'Injection', strength: '150 mg/mL', inventoryUnit: 'vial', initialStock: 50, reorderLevel: 12 }),
];

const NEURO_SUPPORT_DRUGS = [
  drugSpec({ key: 'diazepam_5_tablet', name: 'Diazepam', code: 'DZP5', form: 'Tablet', strength: '5 mg', inventoryUnit: 'tablet', initialStock: 180, reorderLevel: 40 }),
  drugSpec({ key: 'diazepam_injection', name: 'Diazepam', code: 'DZP10I', form: 'Injection', strength: '10 mg/2 mL', inventoryUnit: 'ampoule', initialStock: 75, reorderLevel: 18 }),
  drugSpec({ key: 'phenobarbital_30_tablet', name: 'Phenobarbital', code: 'PHB30', form: 'Tablet', strength: '30 mg', inventoryUnit: 'tablet', initialStock: 160, reorderLevel: 35 }),
  drugSpec({ key: 'phenytoin_100_capsule', name: 'Phenytoin', code: 'PHY100', form: 'Capsule', strength: '100 mg', inventoryUnit: 'capsule', initialStock: 140, reorderLevel: 30 }),
  drugSpec({ key: 'carbamazepine_200_tablet', name: 'Carbamazepine', code: 'CBZ200', form: 'Tablet', strength: '200 mg', inventoryUnit: 'tablet', initialStock: 180, reorderLevel: 40 }),
  drugSpec({ key: 'amitriptyline_25_tablet', name: 'Amitriptyline', code: 'AMI25', form: 'Tablet', strength: '25 mg', inventoryUnit: 'tablet', initialStock: 150, reorderLevel: 30 }),
  drugSpec({ key: 'haloperidol_5_tablet', name: 'Haloperidol', code: 'HAL5', form: 'Tablet', strength: '5 mg', inventoryUnit: 'tablet', initialStock: 100, reorderLevel: 25 }),
  drugSpec({ key: 'zinc_sulfate_20_tablet', name: 'Zinc Sulfate', code: 'ZINC20', form: 'Dispersible Tablet', strength: '20 mg', inventoryUnit: 'tablet', initialStock: 240, reorderLevel: 50 }),
  drugSpec({ key: 'vitamin_c_500_tablet', name: 'Vitamin C', code: 'VITC500', form: 'Tablet', strength: '500 mg', inventoryUnit: 'tablet', initialStock: 300, reorderLevel: 60 }),
  drugSpec({ key: 'multivitamin_syrup', name: 'Multivitamin', code: 'MVSYR', form: 'Syrup', strength: 'Adult/Paediatric mix', inventoryUnit: 'bottle', initialStock: 40, reorderLevel: 10 }),
  drugSpec({ key: 'normal_saline_500_infusion', name: 'Sodium Chloride 0.9%', code: 'NS500', form: 'Infusion', strength: '500 mL', inventoryUnit: 'bag', initialStock: 180, reorderLevel: 40 }),
  drugSpec({ key: 'ringers_lactate_500_infusion', name: "Ringer's Lactate", code: 'RL500', form: 'Infusion', strength: '500 mL', inventoryUnit: 'bag', initialStock: 150, reorderLevel: 35 }),
  drugSpec({ key: 'dextrose_5_500_infusion', name: 'Dextrose 5%', code: 'D5W500', form: 'Infusion', strength: '500 mL', inventoryUnit: 'bag', initialStock: 120, reorderLevel: 30 }),
  drugSpec({ key: 'dextrose_50_injection', name: 'Dextrose 50%', code: 'D50', form: 'Injection', strength: '50 mL', inventoryUnit: 'ampoule', initialStock: 60, reorderLevel: 15 }),
  drugSpec({ key: 'calcium_gluconate_injection', name: 'Calcium Gluconate', code: 'CALG10', form: 'Injection', strength: '10%', inventoryUnit: 'ampoule', initialStock: 60, reorderLevel: 15 }),
  drugSpec({ key: 'adrenaline_injection', name: 'Adrenaline', code: 'ADR1', form: 'Injection', strength: '1 mg/mL', inventoryUnit: 'ampoule', initialStock: 100, reorderLevel: 24 }),
  drugSpec({ key: 'atropine_injection', name: 'Atropine', code: 'ATR1', form: 'Injection', strength: '1 mg/mL', inventoryUnit: 'ampoule', initialStock: 70, reorderLevel: 18 }),
];

const DRUG_CATALOG = Object.freeze([
  ...ANALGESIC_DRUGS,
  ...ANTI_INFECTIVE_DRUGS,
  ...ANTIML_ENDO_DRUGS,
  ...GI_RESP_DRUGS,
  ...CV_OBGYN_DRUGS,
  ...NEURO_SUPPORT_DRUGS,
]);

const buildInventoryItemName = (spec) =>
  [spec.name, spec.strength, spec.form].filter(Boolean).join(' ');

const buildInventorySku = (spec, tenantCode = null) => {
  const baseCode = String(spec.code || spec.key || 'DRUG')
    .toUpperCase()
    .replace(/[^A-Z0-9.-]/g, '-')
    .slice(0, 48);
  const scopePrefix = String(tenantCode || 'TEN')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .slice(0, 12);
  return `${scopePrefix}-${baseCode}`.slice(0, 80);
};

const mergeCatalogRecords = (target, scopedKey, records = {}) => {
  Object.entries(records || {}).forEach(([recordKey, record]) => {
    target[`${scopedKey}:${recordKey}`] = record;
  });
};

const seedRadiologyCatalogForTenant = async (
  ctx,
  {
    seedKey,
    tenantId,
    tenantCode = null,
    scenarioKey = null,
  } = {}
) => {
  if (!tenantId || !seedKey) {
    return { tests: {} };
  }

  const result = { tests: {} };

  for (const testSpec of RADIOLOGY_TEST_CATALOG) {
    const record = await ctx.upsert(
      'radiology_test',
      `${seedKey}:radiology-test:${testSpec.key}`,
      {
        tenant_id: tenantId,
        name: testSpec.name,
        code: testSpec.code,
        modality: testSpec.modality,
      },
      {
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'RDT',
      }
    );
    result.tests[testSpec.key] = record;
  }

  return result;
};

const seedPharmacyCatalogForTenant = async (
  ctx,
  {
    seedKey,
    tenantId,
    tenantCode = null,
    scenarioKey = null,
    facilityIds = [],
  } = {}
) => {
  if (!tenantId || !seedKey) {
    return {
      drugs: {},
      formularyItems: {},
      inventoryItems: {},
      inventoryMaps: {},
      drugBatches: {},
      inventoryStocks: {},
      stockMovements: {},
    };
  }

  const normalizedFacilityIds = Array.from(
    new Set((facilityIds || []).map((entry) => String(entry || '').trim()).filter(Boolean))
  );

  const result = {
    drugs: {},
    formularyItems: {},
    inventoryItems: {},
    inventoryMaps: {},
    drugBatches: {},
    inventoryStocks: {},
    stockMovements: {},
  };

  for (const spec of DRUG_CATALOG) {
    const drug = await ctx.upsert(
      'drug',
      `${seedKey}:drug:${spec.key}`,
      {
        tenant_id: tenantId,
        name: spec.name,
        code: spec.code,
        form: spec.form,
        strength: spec.strength,
      },
      {
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'DRG',
      }
    );
    result.drugs[spec.key] = drug;

    const formularyItem = await ctx.upsert(
      'formulary_item',
      `${seedKey}:formulary-item:${spec.key}`,
      {
        tenant_id: tenantId,
        drug_id: drug.id,
        is_active: true,
      },
      {
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'FRM',
      }
    );
    result.formularyItems[spec.key] = formularyItem;

    const inventoryItem = await ctx.upsert(
      'inventory_item',
      `${seedKey}:inventory-item:${spec.key}`,
      {
        tenant_id: tenantId,
        name: buildInventoryItemName(spec),
        category: 'MEDICATION',
        sku: buildInventorySku(spec, tenantCode),
        unit: spec.inventory_unit || 'unit',
      },
      {
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'IIT',
      }
    );
    result.inventoryItems[spec.key] = inventoryItem;

    const inventoryMap = await ctx.upsert(
      'drug_inventory_map',
      `${seedKey}:drug-inventory-map:${spec.key}`,
      {
        tenant_id: tenantId,
        drug_id: drug.id,
        inventory_item_id: inventoryItem.id,
        is_default: true,
        deduction_factor: spec.deduction_factor,
      },
      {
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'DIM',
      }
    );
    result.inventoryMaps[spec.key] = inventoryMap;

    const batchQuantity =
      Math.max(1, normalizedFacilityIds.length) *
      Math.max(spec.initial_stock || DEFAULT_DRUG_INITIAL_STOCK, spec.reorder_level || 1);

    const batch = await ctx.upsert(
      'drug_batch',
      `${seedKey}:drug-batch:${spec.key}`,
      {
        drug_id: drug.id,
        batch_number: `${String(spec.code || spec.key).replace(/[^A-Za-z0-9]/g, '').slice(0, 12).toUpperCase()}A`,
        expiry_date: ctx.date(540),
        quantity: batchQuantity,
      },
      {
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'DBT',
      }
    );
    result.drugBatches[spec.key] = batch;

    for (const facilityId of normalizedFacilityIds) {
      const stockKey = `${spec.key}:${facilityId}`;
      const stockQuantity = spec.initial_stock || DEFAULT_DRUG_INITIAL_STOCK;
      const reorderLevel = spec.reorder_level || DEFAULT_DRUG_REORDER_LEVEL;

      const stockRecord = await ctx.upsert(
        'inventory_stock',
        `${seedKey}:inventory-stock:${stockKey}`,
        {
          inventory_item_id: inventoryItem.id,
          facility_id: facilityId,
          quantity: stockQuantity,
          reorder_level: reorderLevel,
        },
        {
          tenantCode,
          scenarioKey,
          publicIdPrefix: 'STK',
        }
      );
      result.inventoryStocks[stockKey] = stockRecord;

      const stockMovement = await ctx.upsert(
        'stock_movement',
        `${seedKey}:stock-movement:${stockKey}`,
        {
          inventory_item_id: inventoryItem.id,
          facility_id: facilityId,
          movement_type: 'INBOUND',
          reason: 'PURCHASE',
          quantity: stockQuantity,
          occurred_at: ctx.date(-14),
        },
        {
          tenantCode,
          scenarioKey,
          publicIdPrefix: 'SMV',
        }
      );
      result.stockMovements[stockKey] = stockMovement;
    }
  }

  return result;
};

const seedClinicalCatalogForTenant = async (
  ctx,
  {
    seedKey,
    tenantId,
    tenantCode = null,
    scenarioKey = null,
    facilityIds = [],
  } = {}
) => {
  if (!tenantId || !seedKey) {
    return {
      lab: { tests: {}, panels: {} },
      radiology: { tests: {} },
      pharmacy: {
        drugs: {},
        formularyItems: {},
        inventoryItems: {},
        inventoryMaps: {},
        drugBatches: {},
        inventoryStocks: {},
        stockMovements: {},
      },
    };
  }

  const lab = await seedLabCatalogForTenant(ctx, {
    seedKey,
    tenantId,
    tenantCode,
    scenarioKey,
  });

  const radiology = await seedRadiologyCatalogForTenant(ctx, {
    seedKey,
    tenantId,
    tenantCode,
    scenarioKey,
  });

  const pharmacy = await seedPharmacyCatalogForTenant(ctx, {
    seedKey,
    tenantId,
    tenantCode,
    scenarioKey,
    facilityIds,
  });

  return {
    lab,
    radiology,
    pharmacy,
  };
};

const seedClinicalCatalogPack = async (ctx, orgPack) => {
  const result = {
    lab: {
      tests: {},
      panels: {},
    },
    radiology: {
      tests: {},
    },
    pharmacy: {
      drugs: {},
      formularyItems: {},
      inventoryItems: {},
      inventoryMaps: {},
      drugBatches: {},
      inventoryStocks: {},
      stockMovements: {},
    },
    summary: {
      tenants: 0,
      facilities_seeded: 0,
      lab_tests_per_tenant: LAB_TEST_CATALOG.length,
      lab_panels_per_tenant: LAB_PANEL_CATALOG.length,
      radiology_tests_per_tenant: RADIOLOGY_TEST_CATALOG.length,
      drugs_per_tenant: DRUG_CATALOG.length,
      formulary_items_per_tenant: DRUG_CATALOG.length,
      inventory_items_per_tenant: DRUG_CATALOG.length,
      inventory_maps_per_tenant: DRUG_CATALOG.length,
      drug_batches_per_tenant: DRUG_CATALOG.length,
      stock_records_seeded: 0,
      stock_movements_seeded: 0,
    },
  };

  for (const scenario of DEMO_TENANTS) {
    const tenant = orgPack.tenants[scenario.key];
    if (!tenant?.id) continue;

    const facilityIds = Object.entries(orgPack.facilities || {})
      .filter(([scopeKey]) => scopeKey.startsWith(`${scenario.key}:`))
      .map(([, facility]) => facility?.id)
      .filter(Boolean);

    const tenantCatalog = await seedClinicalCatalogForTenant(ctx, {
      seedKey: scenario.key,
      tenantId: tenant.id,
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      facilityIds,
    });

    result.summary.tenants += 1;
    result.summary.facilities_seeded += facilityIds.length;
    result.summary.stock_records_seeded += Object.keys(tenantCatalog.pharmacy.inventoryStocks).length;
    result.summary.stock_movements_seeded += Object.keys(tenantCatalog.pharmacy.stockMovements).length;

    mergeCatalogRecords(result.lab.tests, scenario.key, tenantCatalog.lab.tests);
    mergeCatalogRecords(result.lab.panels, scenario.key, tenantCatalog.lab.panels);
    mergeCatalogRecords(result.radiology.tests, scenario.key, tenantCatalog.radiology.tests);
    mergeCatalogRecords(result.pharmacy.drugs, scenario.key, tenantCatalog.pharmacy.drugs);
    mergeCatalogRecords(result.pharmacy.formularyItems, scenario.key, tenantCatalog.pharmacy.formularyItems);
    mergeCatalogRecords(result.pharmacy.inventoryItems, scenario.key, tenantCatalog.pharmacy.inventoryItems);
    mergeCatalogRecords(result.pharmacy.inventoryMaps, scenario.key, tenantCatalog.pharmacy.inventoryMaps);
    mergeCatalogRecords(result.pharmacy.drugBatches, scenario.key, tenantCatalog.pharmacy.drugBatches);
    mergeCatalogRecords(result.pharmacy.inventoryStocks, scenario.key, tenantCatalog.pharmacy.inventoryStocks);
    mergeCatalogRecords(result.pharmacy.stockMovements, scenario.key, tenantCatalog.pharmacy.stockMovements);
  }

  return result;
};

module.exports = {
  DRUG_CATALOG,
  RADIOLOGY_TEST_CATALOG,
  seedClinicalCatalogForTenant,
  seedClinicalCatalogPack,
};
