const { DEMO_TENANTS } = require('./seed-catalog');
const {
  LAB_TEST_CATALOG,
  LAB_PANEL_CATALOG,
  seedLabCatalogForTenant,
} = require('./seed-lab-catalog-pack');

const DEFAULT_DRUG_INITIAL_STOCK = 180;
const DEFAULT_DRUG_REORDER_LEVEL = 40;

const { RADIOLOGY_TEST_CATALOG } = require('./data/uganda-radiology-catalog');
const { UGANDA_DIAGNOSIS_CATALOG } = require('./data/uganda-diagnosis-catalog');

const drugSpec = ({
  key,
  name,
  code,
  form,
  strength,
  brand = null,
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
  brand,
  inventory_unit: inventoryUnit,
  initial_stock: initialStock,
  reorder_level: reorderLevel,
  deduction_factor: deductionFactor,
});

const ANALGESIC_DRUGS = [
  drugSpec({ key: 'paracetamol_500_tablet', name: 'Paracetamol', brand: 'Panadol', code: 'PCM500', form: 'Tablet', strength: '500 mg', inventoryUnit: 'tablet', initialStock: 1200, reorderLevel: 250 }),
  drugSpec({ key: 'paracetamol_suspension', name: 'Paracetamol', brand: 'Panadol Suspension', code: 'PCM120S', form: 'Suspension', strength: '120 mg/5 mL', inventoryUnit: 'bottle', initialStock: 80, reorderLevel: 20 }),
  drugSpec({ key: 'ibuprofen_400_tablet', name: 'Ibuprofen', brand: 'Brufen', code: 'IBU400', form: 'Tablet', strength: '400 mg', inventoryUnit: 'tablet', initialStock: 900, reorderLevel: 180 }),
  drugSpec({ key: 'ibuprofen_suspension', name: 'Ibuprofen', brand: 'Brufen Suspension', code: 'IBU100S', form: 'Suspension', strength: '100 mg/5 mL', inventoryUnit: 'bottle', initialStock: 60, reorderLevel: 15 }),
  drugSpec({ key: 'diclofenac_50_tablet', name: 'Diclofenac', brand: 'Voltaren', code: 'DCF50', form: 'Tablet', strength: '50 mg', inventoryUnit: 'tablet', initialStock: 700, reorderLevel: 140 }),
  drugSpec({ key: 'diclofenac_injection', name: 'Diclofenac', brand: 'Voltaren Injection', code: 'DCF75I', form: 'Injection', strength: '75 mg/3 mL', inventoryUnit: 'ampoule', initialStock: 120, reorderLevel: 30 }),
  drugSpec({ key: 'tramadol_50_capsule', name: 'Tramadol', brand: 'Tramal', code: 'TRM50', form: 'Capsule', strength: '50 mg', inventoryUnit: 'capsule', initialStock: 500, reorderLevel: 100 }),
  drugSpec({ key: 'morphine_injection', name: 'Morphine', brand: 'Morphine Sulfate', code: 'MRF10I', form: 'Injection', strength: '10 mg/mL', inventoryUnit: 'ampoule', initialStock: 90, reorderLevel: 20 }),
  drugSpec({ key: 'aspirin_81_tablet', name: 'Aspirin', brand: 'Aspirin Cardio', code: 'ASP81', form: 'Tablet', strength: '81 mg', inventoryUnit: 'tablet', initialStock: 700, reorderLevel: 120 }),
  drugSpec({ key: 'aspirin_300_tablet', name: 'Aspirin', brand: 'Aspirin', code: 'ASP300', form: 'Tablet', strength: '300 mg', inventoryUnit: 'tablet', initialStock: 420, reorderLevel: 90 }),
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
      'radiology_procedure',
      `${seedKey}:radiology-procedure:${testSpec.key}`,
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


const seedClinicalTermCatalogForTenant = async (
  ctx,
  {
    seedKey,
    tenantId,
    tenantCode = null,
    scenarioKey = null,
  } = {}
) => {
  if (!tenantId || !seedKey) {
    return { diagnoses: {} };
  }

  const result = { diagnoses: {} };

  for (const [index, termSpec] of UGANDA_DIAGNOSIS_CATALOG.entries()) {
    const basePayload = {
      tenant_id: tenantId,
      facility_id: null,
      catalog_key: termSpec.key,
      term_type: 'DIAGNOSIS',
      code: termSpec.code || null,
      description: termSpec.description,
      category: termSpec.category || null,
      source: termSpec.source || 'UGANDA_CLINICAL_GUIDELINES',
      sort_order: index,
      usage_rank: termSpec.rank || index + 1,
      is_active: true,
      deleted_at: null,
    };

    const record = await ctx.upsert(
      'clinical_term_catalog',
      `${seedKey}:clinical-term-catalog:diagnosis:${termSpec.key}`,
      basePayload,
      {
        createData: basePayload,
        updateData: basePayload,
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'CTC',
      }
    );
    result.diagnoses[termSpec.key] = record;
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
    storageRooms: {},
    storageShelves: {},
  };

  const storageByFacility = {};
  for (const facilityId of normalizedFacilityIds) {
    const room = await ctx.upsert(
      'pharmacy_storage_room',
      `${seedKey}:pharmacy-storage-room:main:${facilityId}`,
      {
        tenant_id: tenantId,
        facility_id: facilityId,
        name: 'Main store',
        code: 'MAIN',
        is_active: true,
      },
      {
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'PSR',
      }
    );
    storageByFacility[facilityId] = { room };

    const shelf = await ctx.upsert(
      'pharmacy_storage_shelf',
      `${seedKey}:pharmacy-storage-shelf:a01:${facilityId}`,
      {
        tenant_id: tenantId,
        facility_id: facilityId,
        storage_room_id: room.id,
        shelf_code: 'A-01',
        label: 'Aisle A, shelf 1',
        is_active: true,
      },
      {
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'PSS',
      }
    );
    storageByFacility[facilityId].shelf = shelf;
    result.storageRooms[facilityId] = room;
    result.storageShelves[facilityId] = shelf;
  }

  const defaultStorage = normalizedFacilityIds.length
    ? storageByFacility[normalizedFacilityIds[0]]
    : null;

  for (let drugCatalogIndex = 0; drugCatalogIndex < DRUG_CATALOG.length; drugCatalogIndex += 1) {
    const spec = DRUG_CATALOG[drugCatalogIndex];
    const drug = await ctx.upsert(
      'drug',
      `${seedKey}:drug:${spec.key}`,
      {
        tenant_id: tenantId,
        name: spec.name,
        generic_name: spec.name,
        brand_name: spec.brand || null,
        code: spec.code,
        form: spec.form,
        strength: spec.strength,
        // Distinct prices so pharmacy most-sold amount/profit charts have visible ranks.
        // Ladder: buy (COGS) < transfer (pharmacy→facility) < pharmacy sell < facility patient sell.
        buy_unit_price: 400 + (drugCatalogIndex + 1) * 250,
        unit_price: 1200 + (drugCatalogIndex + 1) * 850,
        transfer_unit_price: 800 + (drugCatalogIndex + 1) * 450,
        currency: 'UGX',
      },
      {
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'DRG',
      }
    );
    result.drugs[spec.key] = drug;

    const transferPrice = 800 + (drugCatalogIndex + 1) * 450;
    // Facility patient tariff sits above transfer so facility margin is positive.
    const facilityPatientPrice = transferPrice + 350 + (drugCatalogIndex + 1) * 200;

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
        ...(defaultStorage
          ? {
              storage_room_id: defaultStorage.room.id,
              storage_shelf_id: defaultStorage.shelf.id,
            }
          : {}),
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
      const reorderLevel = spec.reorder_level || DEFAULT_DRUG_REORDER_LEVEL;
      // Seed a predictable low-stock slice so pharmacy dashboard Low stock KPI is non-zero.
      const forceLowStock =
        typeof spec.force_low_stock === 'boolean'
          ? spec.force_low_stock
          : [...String(spec.key || '')].reduce((sum, ch) => sum + ch.charCodeAt(0), 0) % 5 === 0;
      const stockQuantity = forceLowStock
        ? Math.max(0, Math.floor(reorderLevel * 0.4))
        : spec.initial_stock || DEFAULT_DRUG_INITIAL_STOCK;

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

      const facilityStorage = storageByFacility[facilityId];
      await ctx.upsert(
        'facility_pharmacy_offering',
        `${seedKey}:facility-pharmacy-offering:${stockKey}`,
        {
          tenant_id: tenantId,
          facility_id: facilityId,
          drug_id: drug.id,
          is_active: true,
          sort_order: drugCatalogIndex,
          unit_price: facilityPatientPrice,
          currency: 'UGX',
          default_storage_shelf_id: facilityStorage?.shelf?.id || null,
        },
        {
          tenantCode,
          scenarioKey,
          publicIdPrefix: 'FPO',
        }
      );
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
      clinicalTerms: { diagnoses: {} },
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

  const clinicalTerms = await seedClinicalTermCatalogForTenant(ctx, {
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
    clinicalTerms,
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
    clinicalTerms: {
      diagnoses: {},
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
      diagnosis_terms_per_tenant: UGANDA_DIAGNOSIS_CATALOG.length,
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
    mergeCatalogRecords(result.clinicalTerms.diagnoses, scenario.key, tenantCatalog.clinicalTerms?.diagnoses);
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
  UGANDA_DIAGNOSIS_CATALOG,
  seedClinicalCatalogForTenant,
  seedClinicalTermCatalogForTenant,
  seedClinicalCatalogPack,
};
