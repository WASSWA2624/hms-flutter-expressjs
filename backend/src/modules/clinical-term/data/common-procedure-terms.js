/**
 * Common procedure and minor surgery catalog.
 *
 * The catalog intentionally uses local HMS catalog codes instead of claiming
 * CPT, ICD-10-PCS, OPCS, or any other national coding authority. Hospitals can
 * still map these options to their own billing/procedure master later.
 */

const explicitProcedureTerms = [
  ['Wound cleaning and dressing', 'HMS-PROC-000001', 'Wound care', 'minor surgery wound dressing'],
  ['Simple wound suturing', 'HMS-PROC-000002', 'Minor surgery', 'laceration repair stitches'],
  ['Complex wound suturing', 'HMS-PROC-000003', 'Minor surgery', 'laceration repair layered closure'],
  ['Incision and drainage of skin abscess', 'HMS-PROC-000004', 'Minor surgery', 'abscess drainage I and D'],
  ['Incision and drainage of breast abscess', 'HMS-PROC-000005', 'Minor surgery', 'breast abscess drainage'],
  ['Wound debridement', 'HMS-PROC-000006', 'Wound care', 'dead tissue removal'],
  ['Burn wound dressing', 'HMS-PROC-000007', 'Wound care', 'burn care dressing'],
  ['Foreign body removal from skin', 'HMS-PROC-000008', 'Minor surgery', 'splinter glass metal removal'],
  ['Foreign body removal from ear', 'HMS-PROC-000009', 'ENT', 'ear foreign body removal'],
  ['Foreign body removal from nose', 'HMS-PROC-000010', 'ENT', 'nasal foreign body removal'],
  ['Skin lesion excision', 'HMS-PROC-000011', 'Dermatology', 'minor surgery skin lesion removal'],
  ['Lipoma excision', 'HMS-PROC-000012', 'Dermatology', 'minor surgery lipoma removal'],
  ['Sebaceous cyst excision', 'HMS-PROC-000013', 'Dermatology', 'minor surgery cyst removal'],
  ['Keloid excision', 'HMS-PROC-000014', 'Dermatology', 'scar keloid removal'],
  ['Skin biopsy', 'HMS-PROC-000015', 'Dermatology', 'punch shave biopsy'],
  ['Punch biopsy', 'HMS-PROC-000016', 'Dermatology', 'skin punch biopsy'],
  ['Shave biopsy', 'HMS-PROC-000017', 'Dermatology', 'skin shave biopsy'],
  ['Nail avulsion', 'HMS-PROC-000018', 'Minor surgery', 'ingrown toenail nail removal'],
  ['Partial nail avulsion', 'HMS-PROC-000019', 'Minor surgery', 'ingrown toenail partial nail removal'],
  ['Toe nail wedge resection', 'HMS-PROC-000020', 'Minor surgery', 'ingrown toenail wedge resection'],
  ['Circumcision', 'HMS-PROC-000021', 'Minor surgery', 'male circumcision'],
  ['Manual vacuum aspiration', 'HMS-PROC-000022', 'Obstetrics and gynecology', 'MVA uterine evacuation'],
  ['Intrauterine device insertion', 'HMS-PROC-000023', 'Obstetrics and gynecology', 'IUD IUCD insertion'],
  ['Intrauterine device removal', 'HMS-PROC-000024', 'Obstetrics and gynecology', 'IUD IUCD removal'],
  ['Implant insertion', 'HMS-PROC-000025', 'Family planning', 'contraceptive implant insertion'],
  ['Implant removal', 'HMS-PROC-000026', 'Family planning', 'contraceptive implant removal'],
  ['Pap smear collection', 'HMS-PROC-000027', 'Obstetrics and gynecology', 'cervical smear screening'],
  ['Visual inspection with acetic acid', 'HMS-PROC-000028', 'Obstetrics and gynecology', 'VIA cervical screening'],
  ['Cervical cryotherapy', 'HMS-PROC-000029', 'Obstetrics and gynecology', 'cervical lesion treatment'],
  ['Endometrial biopsy', 'HMS-PROC-000030', 'Obstetrics and gynecology', 'uterine biopsy'],
  ['Urethral catheterization', 'HMS-PROC-000031', 'Urology', 'urinary catheter insertion'],
  ['Suprapubic catheter change', 'HMS-PROC-000032', 'Urology', 'catheter replacement'],
  ['Bladder washout', 'HMS-PROC-000033', 'Urology', 'urinary bladder irrigation'],
  ['Joint aspiration', 'HMS-PROC-000034', 'Musculoskeletal', 'arthrocentesis'],
  ['Joint injection', 'HMS-PROC-000035', 'Musculoskeletal', 'intra-articular injection'],
  ['Closed fracture reduction', 'HMS-PROC-000036', 'Musculoskeletal', 'fracture manipulation'],
  ['Plaster cast application', 'HMS-PROC-000037', 'Musculoskeletal', 'cast immobilization'],
  ['Plaster cast removal', 'HMS-PROC-000038', 'Musculoskeletal', 'cast removal'],
  ['Splint application', 'HMS-PROC-000039', 'Musculoskeletal', 'immobilization splint'],
  ['Lumbar puncture', 'HMS-PROC-000040', 'Neurology', 'spinal tap CSF'],
  ['Peripheral intravenous cannulation', 'HMS-PROC-000041', 'Vascular access', 'IV cannula insertion'],
  ['Central venous catheter insertion', 'HMS-PROC-000042', 'Vascular access', 'central line insertion'],
  ['Nasogastric tube insertion', 'HMS-PROC-000043', 'Gastrointestinal', 'NG tube insertion'],
  ['Nasogastric tube removal', 'HMS-PROC-000044', 'Gastrointestinal', 'NG tube removal'],
  ['Gastric lavage', 'HMS-PROC-000045', 'Gastrointestinal', 'stomach washout'],
  ['Nebulization', 'HMS-PROC-000046', 'Respiratory', 'nebulizer treatment'],
  ['Oxygen therapy initiation', 'HMS-PROC-000047', 'Respiratory', 'oxygen administration'],
  ['Endotracheal intubation', 'HMS-PROC-000048', 'Airway', 'airway intubation'],
  ['Tracheostomy tube change', 'HMS-PROC-000049', 'Airway', 'tracheostomy care'],
  ['Chest tube insertion', 'HMS-PROC-000050', 'Respiratory', 'tube thoracostomy'],
  ['Pleural aspiration', 'HMS-PROC-000051', 'Respiratory', 'thoracentesis'],
  ['Ascitic tap', 'HMS-PROC-000052', 'Gastrointestinal', 'paracentesis'],
  ['Dental extraction', 'HMS-PROC-000053', 'Dental', 'tooth extraction'],
  ['Dental dressing', 'HMS-PROC-000054', 'Dental', 'temporary dental filling dressing'],
  ['Eye foreign body removal', 'HMS-PROC-000055', 'Ophthalmology', 'corneal foreign body removal'],
  ['Ear syringing', 'HMS-PROC-000056', 'ENT', 'ear wax removal'],
  ['Anterior nasal packing', 'HMS-PROC-000057', 'ENT', 'epistaxis nose bleed packing'],
  ['Posterior nasal packing', 'HMS-PROC-000058', 'ENT', 'epistaxis nose bleed packing'],
  ['Episiotomy repair', 'HMS-PROC-000059', 'Obstetrics and gynecology', 'perineal repair'],
  ['Normal vaginal delivery assistance', 'HMS-PROC-000060', 'Obstetrics and gynecology', 'delivery procedure'],
  ['Manual removal of placenta', 'HMS-PROC-000061', 'Obstetrics and gynecology', 'retained placenta procedure'],
  ['Dilatation and curettage', 'HMS-PROC-000062', 'Obstetrics and gynecology', 'D and C uterine curettage'],
  ['Electrocardiogram recording', 'HMS-PROC-000063', 'Cardiology', 'ECG EKG'],
  ['Cardioversion', 'HMS-PROC-000064', 'Cardiology', 'electrical cardioversion'],
  ['Defibrillation', 'HMS-PROC-000065', 'Emergency', 'cardiac defibrillation'],
];

const procedureGroups = [
  {
    code: 'MIN',
    category: 'Minor surgery',
    actions: [
      'Incision and drainage',
      'Excision',
      'Biopsy',
      'Debridement',
      'Foreign body removal',
      'Simple repair',
      'Complex repair',
      'Cautery',
      'Marsupialization',
      'Drain insertion',
      'Drain removal',
      'Wedge resection',
    ],
    sites: [
      'skin abscess', 'scalp lesion', 'forehead wound', 'eyebrow wound', 'eyelid lesion',
      'cheek wound', 'lip wound', 'chin wound', 'neck wound', 'axillary abscess',
      'breast abscess', 'chest wall wound', 'abdominal wall wound', 'umbilical granuloma',
      'back abscess', 'sacral pressure sore', 'gluteal abscess', 'perineal abscess',
      'groin abscess', 'inguinal swelling', 'vulval abscess', 'Bartholin cyst',
      'penile lesion', 'scrotal abscess', 'upper arm wound', 'forearm wound', 'hand wound',
      'finger wound', 'thumb wound', 'nail bed injury', 'infected nail fold', 'thigh wound',
      'knee wound', 'leg wound', 'ankle wound', 'foot wound', 'toe wound', 'ingrown toenail',
      'plantar wart', 'corn', 'callus', 'lipoma', 'sebaceous cyst', 'epidermoid cyst',
      'skin tag', 'wart', 'mole', 'keloid scar', 'hypertrophic scar', 'pyogenic granuloma',
      'ganglion cyst', 'small hematoma', 'burn blister', 'chronic ulcer', 'diabetic foot ulcer',
      'traumatic laceration', 'dog bite wound', 'human bite wound', 'puncture wound',
      'infected wound', 'surgical wound', 'suture line', 'pressure ulcer', 'venous ulcer',
    ],
    qualifiers: ['left', 'right', 'infected', 'recurrent', 'pediatric', 'adult', 'emergency'],
  },
  {
    code: 'WDC',
    category: 'Wound care',
    actions: [
      'Cleaning and dressing',
      'Dressing change',
      'Negative pressure dressing',
      'Compression dressing',
      'Burn dressing',
      'Ulcer dressing',
      'Suture removal',
      'Staple removal',
      'Wound packing',
      'Wound irrigation',
    ],
    sites: [
      'forehead wound', 'face wound', 'neck wound', 'shoulder wound', 'chest wound',
      'abdominal wound', 'back wound', 'buttock wound', 'perineal wound', 'upper arm wound',
      'forearm wound', 'wrist wound', 'hand wound', 'finger wound', 'thigh wound',
      'knee wound', 'leg wound', 'ankle wound', 'heel wound', 'foot wound', 'toe wound',
      'burn wound', 'diabetic foot wound', 'venous leg ulcer', 'pressure ulcer', 'postoperative wound',
      'traumatic wound', 'bite wound', 'abscess cavity', 'skin graft site', 'donor site',
    ],
    qualifiers: ['clean', 'infected', 'chronic', 'acute', 'deep', 'superficial'],
  },
  {
    code: 'MSK',
    category: 'Musculoskeletal',
    actions: [
      'Aspiration',
      'Injection',
      'Closed reduction',
      'Immobilization',
      'Splint application',
      'Cast application',
      'Cast removal',
      'Traction setup',
      'Tendon sheath injection',
      'Bursa injection',
    ],
    sites: [
      'shoulder joint', 'elbow joint', 'wrist joint', 'hand joint', 'finger joint',
      'hip joint', 'knee joint', 'ankle joint', 'foot joint', 'toe joint', 'temporomandibular joint',
      'acromioclavicular joint', 'sternoclavicular joint', 'sacroiliac joint', 'olecranon bursa',
      'prepatellar bursa', 'Achilles tendon sheath', 'trigger finger', 'carpal tunnel',
      'distal radius fracture', 'ulna fracture', 'humerus fracture', 'clavicle fracture',
      'metacarpal fracture', 'phalangeal fracture', 'femur fracture', 'tibia fracture',
      'fibula fracture', 'metatarsal fracture', 'rib fracture', 'ankle sprain', 'knee sprain',
    ],
    qualifiers: ['left', 'right', 'pediatric', 'adult', 'acute', 'follow-up'],
  },
  {
    code: 'GYN',
    category: 'Obstetrics and gynecology',
    actions: [
      'Speculum examination',
      'Pap smear collection',
      'Visual inspection with acetic acid',
      'Cervical biopsy',
      'Endometrial biopsy',
      'Intrauterine device insertion',
      'Intrauterine device removal',
      'Implant insertion',
      'Implant removal',
      'Manual vacuum aspiration',
      'Dilatation and curettage',
      'Episiotomy repair',
      'Manual removal of placenta',
    ],
    sites: [
      'cervix', 'vagina', 'vulva', 'uterus', 'endometrium', 'ovary', 'fallopian tube',
      'perineum', 'Bartholin gland', 'contraceptive implant site', 'postpartum perineal tear',
      'retained products of conception', 'retained placenta', 'early pregnancy loss',
      'cervical polyp', 'vaginal cyst', 'vulval cyst', 'pelvic mass', 'antenatal patient',
      'postnatal patient',
    ],
    qualifiers: ['screening', 'diagnostic', 'therapeutic', 'emergency', 'follow-up'],
  },
  {
    code: 'URO',
    category: 'Urology',
    actions: [
      'Urethral catheterization',
      'Catheter change',
      'Suprapubic catheter change',
      'Bladder washout',
      'Urethral dilatation',
      'Circumcision',
      'Dorsal slit',
      'Scrotal exploration',
      'Hydrocele aspiration',
      'Testicular aspiration',
    ],
    sites: [
      'male patient', 'female patient', 'pediatric patient', 'adult patient', 'urinary retention',
      'blocked catheter', 'long-term catheter', 'suprapubic catheter site', 'bladder', 'urethra',
      'foreskin', 'phimosis', 'paraphimosis', 'scrotum', 'hydrocele', 'epididymal cyst',
      'testis', 'penile lesion', 'urinary tract', 'periurethral abscess',
    ],
    qualifiers: ['routine', 'emergency', 'first-time', 'repeat', 'left', 'right'],
  },
  {
    code: 'ENT',
    category: 'ENT',
    actions: [
      'Ear syringing',
      'Ear wick insertion',
      'Foreign body removal',
      'Anterior nasal packing',
      'Posterior nasal packing',
      'Nasal cautery',
      'Nasal toilet',
      'Throat swab collection',
      'Tonsillar abscess drainage',
      'Myringotomy',
    ],
    sites: [
      'right ear', 'left ear', 'both ears', 'external ear canal', 'ear wax impaction',
      'ear foreign body', 'nose foreign body', 'right nostril', 'left nostril', 'both nostrils',
      'anterior nose bleed', 'posterior nose bleed', 'nasal septum', 'nasal cavity',
      'tonsil', 'peritonsillar abscess', 'throat', 'oropharynx', 'larynx', 'sinus cavity',
    ],
    qualifiers: ['pediatric', 'adult', 'emergency', 'follow-up', 'infected'],
  },
  {
    code: 'EYE',
    category: 'Ophthalmology',
    actions: [
      'Eye irrigation',
      'Foreign body removal',
      'Fluorescein staining',
      'Eyelid repair',
      'Eyelash epilation',
      'Conjunctival swab collection',
      'Subconjunctival injection',
      'Eye dressing',
      'Tarsorrhaphy',
      'Lacrimal duct probing',
    ],
    sites: [
      'right eye', 'left eye', 'both eyes', 'cornea', 'conjunctiva', 'eyelid', 'upper eyelid',
      'lower eyelid', 'eyelash', 'lacrimal duct', 'chemical eye injury', 'eye foreign body',
      'corneal abrasion', 'conjunctival lesion', 'subconjunctival space', 'eye wound',
    ],
    qualifiers: ['pediatric', 'adult', 'emergency', 'minor', 'follow-up'],
  },
  {
    code: 'GI',
    category: 'Gastrointestinal',
    actions: [
      'Nasogastric tube insertion',
      'Nasogastric tube removal',
      'Gastric lavage',
      'Ascitic tap',
      'Diagnostic paracentesis',
      'Therapeutic paracentesis',
      'Rectal examination',
      'Proctoscopy',
      'Hemorrhoid banding',
      'Perianal abscess drainage',
      'Feeding tube change',
    ],
    sites: [
      'stomach', 'nasogastric tube', 'abdomen', 'ascites', 'peritoneal cavity', 'rectum',
      'anal canal', 'hemorrhoid', 'perianal area', 'feeding tube site', 'gastrostomy tube',
      'ileostomy site', 'colostomy site', 'abdominal wall', 'epigastric region', 'right iliac fossa',
      'left iliac fossa',
    ],
    qualifiers: ['diagnostic', 'therapeutic', 'emergency', 'routine', 'pediatric', 'adult'],
  },
  {
    code: 'RESP',
    category: 'Respiratory and airway',
    actions: [
      'Nebulization',
      'Oxygen therapy initiation',
      'Peak flow measurement',
      'Sputum induction',
      'Endotracheal intubation',
      'Extubation',
      'Tracheostomy tube change',
      'Chest tube insertion',
      'Chest tube removal',
      'Pleural aspiration',
      'Thoracentesis',
    ],
    sites: [
      'airway', 'upper airway', 'lower airway', 'right pleural space', 'left pleural space',
      'chest wall', 'tracheostomy site', 'endotracheal tube', 'oxygen delivery system',
      'nebulizer treatment', 'asthma exacerbation', 'COPD exacerbation', 'pneumothorax',
      'pleural effusion', 'respiratory distress', 'sputum specimen',
    ],
    qualifiers: ['emergency', 'routine', 'pediatric', 'adult', 'left', 'right'],
  },
  {
    code: 'VAC',
    category: 'Vascular access',
    actions: [
      'Peripheral intravenous cannulation',
      'Peripheral intravenous line removal',
      'Central venous catheter insertion',
      'Central venous catheter removal',
      'Intraosseous access insertion',
      'Arterial line insertion',
      'Venepuncture',
      'Therapeutic phlebotomy',
      'Blood transfusion setup',
      'Line flushing',
    ],
    sites: [
      'right hand vein', 'left hand vein', 'forearm vein', 'antecubital vein', 'external jugular vein',
      'internal jugular vein', 'subclavian vein', 'femoral vein', 'radial artery', 'femoral artery',
      'tibial intraosseous site', 'humeral intraosseous site', 'peripheral line', 'central line',
      'arterial line', 'blood transfusion line',
    ],
    qualifiers: ['routine', 'emergency', 'ultrasound-guided', 'pediatric', 'adult', 'difficult access'],
  },
  {
    code: 'DEN',
    category: 'Dental and oral',
    actions: [
      'Dental extraction',
      'Dental dressing',
      'Temporary filling',
      'Dental abscess drainage',
      'Oral biopsy',
      'Suture of oral wound',
      'Tooth splinting',
      'Scaling and polishing',
      'Root canal procedure',
      'Operculectomy',
    ],
    sites: [
      'upper incisor', 'lower incisor', 'upper canine', 'lower canine', 'upper premolar',
      'lower premolar', 'upper molar', 'lower molar', 'wisdom tooth', 'gum abscess',
      'oral mucosa', 'tongue lesion', 'lip lesion', 'palate lesion', 'dental cavity', 'fractured tooth',
      'dental socket', 'periodontal pocket',
    ],
    qualifiers: ['right', 'left', 'pediatric', 'adult', 'infected', 'emergency'],
  },
  {
    code: 'CAR',
    category: 'Cardiology and emergency',
    actions: [
      'Electrocardiogram recording',
      'Cardioversion',
      'Defibrillation',
      'Cardiac monitoring setup',
      'Basic life support procedure',
      'Advanced life support procedure',
      'Pericardiocentesis',
      'Blood pressure monitoring setup',
      'Orthostatic blood pressure assessment',
      'Pulse oximetry monitoring setup',
    ],
    sites: [
      'adult patient', 'pediatric patient', 'chest pain patient', 'arrhythmia patient',
      'cardiac arrest patient', 'unstable patient', 'hypertensive emergency', 'syncope patient',
      'pericardial effusion', 'critical care bed', 'emergency bay', 'procedure room',
    ],
    qualifiers: ['urgent', 'emergency', 'routine', 'repeat', 'monitored'],
  },
  {
    code: 'NEU',
    category: 'Neurology',
    actions: [
      'Lumbar puncture',
      'Cerebrospinal fluid collection',
      'Nerve block',
      'Trigger point injection',
      'Conscious sedation monitoring',
      'Seizure emergency procedure',
      'Neurological observation setup',
      'Botulinum injection',
    ],
    sites: [
      'lumbar spine', 'cerebrospinal fluid space', 'occipital nerve', 'facial nerve region',
      'trigeminal nerve region', 'neck trigger point', 'back trigger point', 'shoulder trigger point',
      'pediatric patient', 'adult patient', 'emergency patient', 'procedure room',
    ],
    qualifiers: ['diagnostic', 'therapeutic', 'emergency', 'repeat', 'ultrasound-guided'],
  },
];

const toSentenceCase = (value) => {
  const text = String(value || '').trim().replace(/\s+/g, ' ');
  return text ? text.charAt(0).toUpperCase() + text.slice(1) : '';
};

const normalizeUpper = (value) => String(value || '').trim().toUpperCase();

const qualifierDescription = (qualifier, description) => {
  if (!qualifier) return description;
  if (qualifier === 'left' || qualifier === 'right') return `${description} - ${qualifier} side`;
  if (qualifier === 'pediatric' || qualifier === 'adult') return `${description} - ${qualifier}`;
  return `${qualifier} ${description}`;
};

const addTerm = (items, seen, { description, code, category, keywords = '', rank = 0 }) => {
  const normalizedDescription = toSentenceCase(description);
  const normalizedCode = normalizeUpper(code);
  const key = `${normalizedCode}::${normalizeUpper(normalizedDescription)}`;
  if (!normalizedDescription || seen.has(key)) return;

  seen.add(key);
  items.push({
    code: normalizedCode || `HMS-PROC-${String(items.length + 1).padStart(6, '0')}`,
    description: normalizedDescription,
    category,
    origin: 'PROCEDURE_CATALOG',
    rank: items.length + rank,
    search_text: normalizeUpper([
      normalizedDescription,
      normalizedCode,
      category,
      keywords,
    ].filter(Boolean).join(' ')),
  });
};

const buildCommonProcedureTerms = () => {
  const items = [];
  const seen = new Set();

  explicitProcedureTerms.forEach(([description, code, category, keywords], index) => {
    addTerm(items, seen, {
      description,
      code,
      category,
      keywords,
      rank: index,
    });
  });

  procedureGroups.forEach((group, groupIndex) => {
    group.actions.forEach((action) => {
      group.sites.forEach((site) => {
        const baseDescription = `${action} of ${site}`;
        const baseCode = `HMS-${group.code}-${String(items.length + 1).padStart(5, '0')}`;
        addTerm(items, seen, {
          description: baseDescription,
          code: baseCode,
          category: group.category,
          keywords: `${action} ${site} ${group.category}`,
          rank: 500 + groupIndex * 100,
        });

        group.qualifiers.forEach((qualifier) => {
          const description = qualifierDescription(qualifier, baseDescription);
          addTerm(items, seen, {
            description,
            code: `HMS-${group.code}-${String(items.length + 1).padStart(5, '0')}`,
            category: group.category,
            keywords: `${action} ${site} ${qualifier} ${group.category}`,
            rank: 1000 + groupIndex * 100,
          });
        });
      });
    });
  });

  return items.slice(0, 9000);
};

const COMMON_PROCEDURE_TERMS = Object.freeze(buildCommonProcedureTerms());

module.exports = {
  COMMON_PROCEDURE_TERMS,
};
