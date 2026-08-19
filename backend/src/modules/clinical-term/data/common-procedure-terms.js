/**
 * Curated procedure catalog for the clinical term picker.
 *
 * Every entry is a procedure somebody can actually order and perform at a
 * Ugandan health centre, district hospital, or regional referral hospital.
 *
 * This list is authored, not generated. An earlier version built entries from
 * an action x site x qualifier cross-product, which produced thousands of rows
 * that were either impossible ("Marsupialization of dog bite wound"), anatomically
 * wrong ("Pap smear collection of ovary"), or the same procedure repeated with a
 * laterality or acuity qualifier bolted on. Site and laterality belong on the
 * encounter record, not in the catalog: keep one row per distinct procedure.
 *
 * Codes are internal (HMS-PROC-nnnnnn) and are persisted on procedure records,
 * so they must stay stable. When adding a procedure, take the next free number
 * rather than renumbering the list.
 */

const procedureCatalog = [
  // --- Wound care -----------------------------------------------------------
  ['Wound cleaning and dressing', 'HMS-PROC-000001', 'Wound care', 'minor surgery wound dressing'],
  ['Wound debridement', 'HMS-PROC-000006', 'Wound care', 'dead tissue removal sloughectomy'],
  ['Burn wound dressing', 'HMS-PROC-000007', 'Wound care', 'burn care dressing'],
  ['Dressing change', 'HMS-PROC-000066', 'Wound care', 'redressing wound review'],
  ['Wound irrigation', 'HMS-PROC-000067', 'Wound care', 'wound washout lavage'],
  ['Wound packing', 'HMS-PROC-000068', 'Wound care', 'cavity packing gauze'],
  ['Suture removal', 'HMS-PROC-000069', 'Wound care', 'stitch removal'],
  ['Staple removal', 'HMS-PROC-000070', 'Wound care', 'clip removal'],
  ['Compression bandaging', 'HMS-PROC-000071', 'Wound care', 'venous ulcer compression bandage'],
  ['Negative pressure wound therapy', 'HMS-PROC-000072', 'Wound care', 'vacuum assisted closure VAC'],
  ['Diabetic foot ulcer care', 'HMS-PROC-000073', 'Wound care', 'diabetic foot dressing offloading'],
  ['Pressure ulcer care', 'HMS-PROC-000074', 'Wound care', 'bed sore decubitus dressing'],
  ['Skin graft donor site dressing', 'HMS-PROC-000075', 'Wound care', 'graft donor site care'],
  ['Escharotomy', 'HMS-PROC-000076', 'Wound care', 'burn eschar release'],

  // --- Minor surgery --------------------------------------------------------
  ['Simple wound suturing', 'HMS-PROC-000002', 'Minor surgery', 'laceration repair stitches'],
  ['Complex wound suturing', 'HMS-PROC-000003', 'Minor surgery', 'laceration repair layered closure'],
  ['Incision and drainage of skin abscess', 'HMS-PROC-000004', 'Minor surgery', 'abscess drainage I and D'],
  ['Incision and drainage of breast abscess', 'HMS-PROC-000005', 'Minor surgery', 'breast abscess drainage'],
  ['Foreign body removal from skin', 'HMS-PROC-000008', 'Minor surgery', 'splinter glass metal removal'],
  ['Nail avulsion', 'HMS-PROC-000018', 'Minor surgery', 'ingrown toenail nail removal'],
  ['Partial nail avulsion', 'HMS-PROC-000019', 'Minor surgery', 'ingrown toenail partial nail removal'],
  ['Toe nail wedge resection', 'HMS-PROC-000020', 'Minor surgery', 'ingrown toenail wedge resection'],
  ['Circumcision', 'HMS-PROC-000021', 'Minor surgery', 'male circumcision SMC'],
  ['Incision and drainage of dental abscess', 'HMS-PROC-000077', 'Minor surgery', 'dental abscess drainage'],
  ['Incision and drainage of perianal abscess', 'HMS-PROC-000078', 'Minor surgery', 'perianal abscess drainage'],
  ['Incision and drainage of Bartholin abscess', 'HMS-PROC-000079', 'Minor surgery', 'bartholin gland abscess drainage'],
  ['Marsupialization of Bartholin cyst', 'HMS-PROC-000080', 'Minor surgery', 'bartholin cyst marsupialization'],
  ['Haematoma evacuation', 'HMS-PROC-000081', 'Minor surgery', 'hematoma drainage'],
  ['Ganglion cyst aspiration', 'HMS-PROC-000082', 'Minor surgery', 'ganglion aspiration wrist'],
  ['Hydrocele aspiration', 'HMS-PROC-000083', 'Minor surgery', 'scrotal hydrocele tap'],
  ['Excision of lymph node for biopsy', 'HMS-PROC-000084', 'Minor surgery', 'lymph node biopsy excision'],
  ['Fine needle aspiration cytology', 'HMS-PROC-000085', 'Minor surgery', 'FNAC needle aspiration lump'],
  ['Surgical toilet', 'HMS-PROC-000086', 'Minor surgery', 'wound toilet cleaning theatre'],

  // --- Dermatology ----------------------------------------------------------
  ['Skin lesion excision', 'HMS-PROC-000011', 'Dermatology', 'minor surgery skin lesion removal'],
  ['Lipoma excision', 'HMS-PROC-000012', 'Dermatology', 'minor surgery lipoma removal'],
  ['Sebaceous cyst excision', 'HMS-PROC-000013', 'Dermatology', 'minor surgery cyst removal'],
  ['Keloid excision', 'HMS-PROC-000014', 'Dermatology', 'scar keloid removal'],
  ['Skin biopsy', 'HMS-PROC-000015', 'Dermatology', 'punch shave biopsy'],
  ['Punch biopsy', 'HMS-PROC-000016', 'Dermatology', 'skin punch biopsy'],
  ['Shave biopsy', 'HMS-PROC-000017', 'Dermatology', 'skin shave biopsy'],
  ['Cryotherapy of skin lesion', 'HMS-PROC-000087', 'Dermatology', 'wart cryotherapy liquid nitrogen'],
  ['Electrocautery of skin lesion', 'HMS-PROC-000088', 'Dermatology', 'cautery skin tag wart'],
  ['Intralesional steroid injection', 'HMS-PROC-000089', 'Dermatology', 'keloid triamcinolone injection'],
  ['Skin scraping for fungal microscopy', 'HMS-PROC-000090', 'Dermatology', 'KOH skin scraping tinea'],
  ['Slit skin smear', 'HMS-PROC-000091', 'Dermatology', 'leprosy slit skin smear'],

  // --- ENT ------------------------------------------------------------------
  ['Foreign body removal from ear', 'HMS-PROC-000009', 'ENT', 'ear foreign body removal'],
  ['Foreign body removal from nose', 'HMS-PROC-000010', 'ENT', 'nasal foreign body removal'],
  ['Ear syringing', 'HMS-PROC-000056', 'ENT', 'ear wax removal aural toilet'],
  ['Anterior nasal packing', 'HMS-PROC-000057', 'ENT', 'epistaxis nose bleed packing'],
  ['Posterior nasal packing', 'HMS-PROC-000058', 'ENT', 'epistaxis nose bleed packing'],
  ['Aural toilet and wick insertion', 'HMS-PROC-000092', 'ENT', 'otitis externa ear wick'],
  ['Myringotomy', 'HMS-PROC-000093', 'ENT', 'eardrum incision grommet'],
  ['Tonsillectomy', 'HMS-PROC-000094', 'ENT', 'tonsil removal'],
  ['Adenoidectomy', 'HMS-PROC-000095', 'ENT', 'adenoid removal'],
  ['Peritonsillar abscess drainage', 'HMS-PROC-000096', 'ENT', 'quinsy drainage aspiration'],
  ['Nasal cautery', 'HMS-PROC-000097', 'ENT', 'epistaxis silver nitrate cautery'],
  ['Direct laryngoscopy', 'HMS-PROC-000098', 'ENT', 'laryngeal examination'],
  ['Audiometry', 'HMS-PROC-000099', 'ENT', 'hearing test audiogram'],

  // --- Ophthalmology --------------------------------------------------------
  ['Eye foreign body removal', 'HMS-PROC-000055', 'Ophthalmology', 'corneal foreign body removal'],
  ['Visual acuity assessment', 'HMS-PROC-000100', 'Ophthalmology', 'snellen chart vision test'],
  ['Fundoscopy', 'HMS-PROC-000101', 'Ophthalmology', 'ophthalmoscopy retinal examination'],
  ['Tonometry', 'HMS-PROC-000102', 'Ophthalmology', 'intraocular pressure glaucoma'],
  ['Fluorescein staining of cornea', 'HMS-PROC-000103', 'Ophthalmology', 'corneal abrasion ulcer stain'],
  ['Eye irrigation', 'HMS-PROC-000104', 'Ophthalmology', 'chemical eye injury washout'],
  ['Subconjunctival injection', 'HMS-PROC-000105', 'Ophthalmology', 'eye injection'],
  ['Cataract extraction with intraocular lens', 'HMS-PROC-000106', 'Ophthalmology', 'cataract surgery IOL'],
  ['Pterygium excision', 'HMS-PROC-000107', 'Ophthalmology', 'pterygium removal'],
  ['Chalazion incision and curettage', 'HMS-PROC-000108', 'Ophthalmology', 'eyelid chalazion stye'],
  ['Trichiasis lid surgery', 'HMS-PROC-000109', 'Ophthalmology', 'trachoma trichiasis eyelid surgery'],

  // --- Dental ---------------------------------------------------------------
  ['Dental extraction', 'HMS-PROC-000053', 'Dental', 'tooth extraction'],
  ['Dental dressing', 'HMS-PROC-000054', 'Dental', 'temporary dental filling dressing'],
  ['Surgical tooth extraction', 'HMS-PROC-000110', 'Dental', 'impacted tooth surgical removal'],
  ['Dental scaling and polishing', 'HMS-PROC-000111', 'Dental', 'scaling plaque cleaning'],
  ['Dental restoration', 'HMS-PROC-000112', 'Dental', 'filling amalgam composite'],
  ['Root canal treatment', 'HMS-PROC-000113', 'Dental', 'endodontic pulp treatment'],
  ['Pulpotomy', 'HMS-PROC-000114', 'Dental', 'paediatric pulp treatment'],
  ['Dental splinting', 'HMS-PROC-000115', 'Dental', 'loose tooth splint trauma'],

  // --- Obstetrics and gynaecology -------------------------------------------
  ['Manual vacuum aspiration', 'HMS-PROC-000022', 'Obstetrics and gynecology', 'MVA uterine evacuation'],
  ['Intrauterine device insertion', 'HMS-PROC-000023', 'Obstetrics and gynecology', 'IUD IUCD insertion'],
  ['Intrauterine device removal', 'HMS-PROC-000024', 'Obstetrics and gynecology', 'IUD IUCD removal'],
  ['Pap smear collection', 'HMS-PROC-000027', 'Obstetrics and gynecology', 'cervical smear screening'],
  ['Visual inspection with acetic acid', 'HMS-PROC-000028', 'Obstetrics and gynecology', 'VIA cervical screening'],
  ['Cervical cryotherapy', 'HMS-PROC-000029', 'Obstetrics and gynecology', 'cervical lesion treatment'],
  ['Endometrial biopsy', 'HMS-PROC-000030', 'Obstetrics and gynecology', 'uterine biopsy'],
  ['Episiotomy repair', 'HMS-PROC-000059', 'Obstetrics and gynecology', 'perineal repair'],
  ['Normal vaginal delivery assistance', 'HMS-PROC-000060', 'Obstetrics and gynecology', 'delivery procedure SVD'],
  ['Manual removal of placenta', 'HMS-PROC-000061', 'Obstetrics and gynecology', 'retained placenta procedure'],
  ['Dilatation and curettage', 'HMS-PROC-000062', 'Obstetrics and gynecology', 'D and C uterine curettage'],
  ['Caesarean section', 'HMS-PROC-000116', 'Obstetrics and gynecology', 'c-section caesarian delivery'],
  ['Assisted vacuum delivery', 'HMS-PROC-000117', 'Obstetrics and gynecology', 'ventouse vacuum extraction'],
  ['Assisted forceps delivery', 'HMS-PROC-000118', 'Obstetrics and gynecology', 'forceps delivery'],
  ['Breech delivery', 'HMS-PROC-000119', 'Obstetrics and gynecology', 'assisted breech birth'],
  ['Perineal tear repair', 'HMS-PROC-000120', 'Obstetrics and gynecology', 'obstetric tear suturing'],
  ['Cervical tear repair', 'HMS-PROC-000121', 'Obstetrics and gynecology', 'cervical laceration suturing'],
  ['Artificial rupture of membranes', 'HMS-PROC-000122', 'Obstetrics and gynecology', 'ARM amniotomy'],
  ['Labour induction', 'HMS-PROC-000123', 'Obstetrics and gynecology', 'induction of labour misoprostol oxytocin'],
  ['Labour augmentation', 'HMS-PROC-000124', 'Obstetrics and gynecology', 'oxytocin augmentation'],
  ['External cephalic version', 'HMS-PROC-000125', 'Obstetrics and gynecology', 'ECV breech turning'],
  ['Cervical cerclage', 'HMS-PROC-000126', 'Obstetrics and gynecology', 'cervical suture incompetent cervix'],
  ['Uterine balloon tamponade', 'HMS-PROC-000127', 'Obstetrics and gynecology', 'postpartum haemorrhage tamponade'],
  ['Bimanual uterine compression', 'HMS-PROC-000128', 'Obstetrics and gynecology', 'PPH uterine massage compression'],
  ['Evacuation of retained products of conception', 'HMS-PROC-000129', 'Obstetrics and gynecology', 'ERPC incomplete abortion'],
  ['Salpingectomy for ectopic pregnancy', 'HMS-PROC-000130', 'Obstetrics and gynecology', 'ectopic pregnancy surgery'],
  ['Abdominal hysterectomy', 'HMS-PROC-000131', 'Obstetrics and gynecology', 'uterus removal'],
  ['Myomectomy', 'HMS-PROC-000132', 'Obstetrics and gynecology', 'fibroid removal'],
  ['Ovarian cystectomy', 'HMS-PROC-000133', 'Obstetrics and gynecology', 'ovarian cyst removal'],
  ['Cervical biopsy', 'HMS-PROC-000134', 'Obstetrics and gynecology', 'cervix punch biopsy'],
  ['Colposcopy', 'HMS-PROC-000135', 'Obstetrics and gynecology', 'cervical colposcopic examination'],
  ['Speculum examination', 'HMS-PROC-000136', 'Obstetrics and gynecology', 'vaginal speculum exam'],
  ['Obstetric ultrasound scan', 'HMS-PROC-000137', 'Obstetrics and gynecology', 'antenatal ultrasound dating scan'],
  ['Repair of vesicovaginal fistula', 'HMS-PROC-000138', 'Obstetrics and gynecology', 'VVF fistula repair'],
  ['Symphysiotomy', 'HMS-PROC-000139', 'Obstetrics and gynecology', 'obstructed labour symphysiotomy'],

  // --- Family planning ------------------------------------------------------
  ['Implant insertion', 'HMS-PROC-000025', 'Family planning', 'contraceptive implant insertion jadelle'],
  ['Implant removal', 'HMS-PROC-000026', 'Family planning', 'contraceptive implant removal'],
  ['Injectable contraceptive administration', 'HMS-PROC-000140', 'Family planning', 'depo provera injection'],
  ['Bilateral tubal ligation', 'HMS-PROC-000141', 'Family planning', 'female sterilization BTL'],
  ['Vasectomy', 'HMS-PROC-000142', 'Family planning', 'male sterilization'],
  ['Family planning counselling', 'HMS-PROC-000143', 'Family planning', 'contraception counselling'],

  // --- Urology --------------------------------------------------------------
  ['Urethral catheterization', 'HMS-PROC-000031', 'Urology', 'urinary catheter insertion foley'],
  ['Suprapubic catheter change', 'HMS-PROC-000032', 'Urology', 'catheter replacement'],
  ['Bladder washout', 'HMS-PROC-000033', 'Urology', 'urinary bladder irrigation'],
  ['Suprapubic catheter insertion', 'HMS-PROC-000144', 'Urology', 'suprapubic cystostomy retention'],
  ['Urethral dilatation', 'HMS-PROC-000145', 'Urology', 'urethral stricture dilatation'],
  ['Dorsal slit', 'HMS-PROC-000146', 'Urology', 'paraphimosis dorsal slit'],
  ['Hydrocelectomy', 'HMS-PROC-000147', 'Urology', 'hydrocele repair surgery'],
  ['Orchidectomy', 'HMS-PROC-000148', 'Urology', 'testis removal'],
  ['Prostatectomy', 'HMS-PROC-000149', 'Urology', 'prostate removal BPH surgery'],
  ['Manual reduction of paraphimosis', 'HMS-PROC-000150', 'Urology', 'paraphimosis reduction'],
  ['Testicular torsion exploration', 'HMS-PROC-000151', 'Urology', 'scrotal exploration orchidopexy'],

  // --- Musculoskeletal and orthopaedics -------------------------------------
  ['Joint aspiration', 'HMS-PROC-000034', 'Musculoskeletal', 'arthrocentesis'],
  ['Joint injection', 'HMS-PROC-000035', 'Musculoskeletal', 'intra-articular injection'],
  ['Closed fracture reduction', 'HMS-PROC-000036', 'Musculoskeletal', 'fracture manipulation'],
  ['Plaster cast application', 'HMS-PROC-000037', 'Musculoskeletal', 'cast immobilization POP'],
  ['Plaster cast removal', 'HMS-PROC-000038', 'Musculoskeletal', 'cast removal'],
  ['Splint application', 'HMS-PROC-000039', 'Musculoskeletal', 'immobilization splint'],
  ['Open reduction and internal fixation', 'HMS-PROC-000152', 'Musculoskeletal', 'ORIF fracture plating'],
  ['External fixation of fracture', 'HMS-PROC-000153', 'Musculoskeletal', 'external fixator'],
  ['Skeletal traction', 'HMS-PROC-000154', 'Musculoskeletal', 'traction pin femoral'],
  ['Skin traction', 'HMS-PROC-000155', 'Musculoskeletal', 'buck traction'],
  ['Closed reduction of dislocation', 'HMS-PROC-000156', 'Musculoskeletal', 'shoulder hip dislocation reduction'],
  ['Tendon sheath injection', 'HMS-PROC-000157', 'Musculoskeletal', 'trigger finger de quervain injection'],
  ['Bursa aspiration', 'HMS-PROC-000158', 'Musculoskeletal', 'olecranon prepatellar bursa'],
  ['Carpal tunnel release', 'HMS-PROC-000159', 'Musculoskeletal', 'median nerve decompression'],
  ['Sequestrectomy', 'HMS-PROC-000160', 'Musculoskeletal', 'osteomyelitis sequestrum removal'],
  ['Amputation of limb', 'HMS-PROC-000161', 'Musculoskeletal', 'limb amputation'],
  ['Amputation of digit', 'HMS-PROC-000162', 'Musculoskeletal', 'finger toe amputation'],
  ['Arthrotomy and joint washout', 'HMS-PROC-000163', 'Musculoskeletal', 'septic arthritis washout'],
  ['Manipulation under anaesthesia', 'HMS-PROC-000164', 'Musculoskeletal', 'MUA joint stiffness'],

  // --- General surgery ------------------------------------------------------
  ['Appendicectomy', 'HMS-PROC-000165', 'General surgery', 'appendectomy appendix removal'],
  ['Inguinal hernia repair', 'HMS-PROC-000166', 'General surgery', 'herniorrhaphy hernioplasty groin'],
  ['Umbilical hernia repair', 'HMS-PROC-000167', 'General surgery', 'umbilical herniorrhaphy'],
  ['Exploratory laparotomy', 'HMS-PROC-000168', 'General surgery', 'laparotomy abdominal exploration'],
  ['Bowel resection and anastomosis', 'HMS-PROC-000169', 'General surgery', 'intestinal resection'],
  ['Colostomy formation', 'HMS-PROC-000170', 'General surgery', 'stoma colostomy'],
  ['Colostomy closure', 'HMS-PROC-000171', 'General surgery', 'stoma reversal'],
  ['Cholecystectomy', 'HMS-PROC-000172', 'General surgery', 'gallbladder removal'],
  ['Splenectomy', 'HMS-PROC-000173', 'General surgery', 'spleen removal'],
  ['Thyroidectomy', 'HMS-PROC-000174', 'General surgery', 'thyroid removal goitre'],
  ['Mastectomy', 'HMS-PROC-000175', 'General surgery', 'breast removal'],
  ['Breast lump excision', 'HMS-PROC-000176', 'General surgery', 'lumpectomy fibroadenoma excision'],
  ['Haemorrhoidectomy', 'HMS-PROC-000177', 'General surgery', 'piles surgery'],
  ['Rubber band ligation of haemorrhoids', 'HMS-PROC-000178', 'General surgery', 'piles banding'],
  ['Fistula-in-ano repair', 'HMS-PROC-000179', 'General surgery', 'anal fistulotomy'],
  ['Lateral anal sphincterotomy', 'HMS-PROC-000180', 'General surgery', 'anal fissure surgery'],
  ['Skin grafting', 'HMS-PROC-000181', 'General surgery', 'split thickness skin graft'],
  ['Laparoscopy', 'HMS-PROC-000182', 'General surgery', 'diagnostic laparoscopy keyhole'],
  ['Reduction of intussusception', 'HMS-PROC-000183', 'General surgery', 'paediatric intussusception reduction'],
  ['Pyloromyotomy', 'HMS-PROC-000184', 'General surgery', 'pyloric stenosis ramstedt'],

  // --- Vascular access and transfusion --------------------------------------
  ['Peripheral intravenous cannulation', 'HMS-PROC-000041', 'Vascular access', 'IV cannula insertion'],
  ['Central venous catheter insertion', 'HMS-PROC-000042', 'Vascular access', 'central line insertion'],
  ['Venous cutdown', 'HMS-PROC-000185', 'Vascular access', 'saphenous cutdown emergency access'],
  ['Intraosseous access', 'HMS-PROC-000186', 'Vascular access', 'IO needle paediatric resuscitation'],
  ['Venepuncture', 'HMS-PROC-000187', 'Vascular access', 'blood draw phlebotomy'],
  ['Blood transfusion administration', 'HMS-PROC-000188', 'Vascular access', 'transfusion blood products'],
  ['Exchange transfusion', 'HMS-PROC-000189', 'Vascular access', 'neonatal exchange transfusion jaundice'],
  ['Umbilical vein catheterization', 'HMS-PROC-000190', 'Vascular access', 'neonatal umbilical line'],

  // --- Gastrointestinal -----------------------------------------------------
  ['Nasogastric tube insertion', 'HMS-PROC-000043', 'Gastrointestinal', 'NG tube insertion'],
  ['Nasogastric tube removal', 'HMS-PROC-000044', 'Gastrointestinal', 'NG tube removal'],
  ['Gastric lavage', 'HMS-PROC-000045', 'Gastrointestinal', 'stomach washout poisoning'],
  ['Ascitic tap', 'HMS-PROC-000052', 'Gastrointestinal', 'paracentesis abdominal tap'],
  ['Therapeutic paracentesis', 'HMS-PROC-000191', 'Gastrointestinal', 'large volume ascites drainage'],
  ['Digital rectal examination', 'HMS-PROC-000192', 'Gastrointestinal', 'DRE rectal exam'],
  ['Manual evacuation of faecal impaction', 'HMS-PROC-000193', 'Gastrointestinal', 'disimpaction constipation'],
  ['Enema administration', 'HMS-PROC-000194', 'Gastrointestinal', 'bowel enema'],
  ['Proctoscopy', 'HMS-PROC-000195', 'Gastrointestinal', 'anal canal examination'],
  ['Sigmoidoscopy', 'HMS-PROC-000196', 'Gastrointestinal', 'lower endoscopy rectum sigmoid'],
  ['Colonoscopy', 'HMS-PROC-000197', 'Gastrointestinal', 'large bowel endoscopy'],
  ['Upper gastrointestinal endoscopy', 'HMS-PROC-000198', 'Gastrointestinal', 'OGD gastroscopy'],
  ['Percutaneous endoscopic gastrostomy', 'HMS-PROC-000199', 'Gastrointestinal', 'PEG feeding tube'],
  ['Liver biopsy', 'HMS-PROC-000200', 'Gastrointestinal', 'percutaneous liver biopsy'],

  // --- Respiratory and airway -----------------------------------------------
  ['Nebulization', 'HMS-PROC-000046', 'Respiratory', 'nebulizer treatment salbutamol'],
  ['Oxygen therapy initiation', 'HMS-PROC-000047', 'Respiratory', 'oxygen administration'],
  ['Endotracheal intubation', 'HMS-PROC-000048', 'Airway', 'airway intubation'],
  ['Tracheostomy tube change', 'HMS-PROC-000049', 'Airway', 'tracheostomy care'],
  ['Chest tube insertion', 'HMS-PROC-000050', 'Respiratory', 'tube thoracostomy underwater seal'],
  ['Pleural aspiration', 'HMS-PROC-000051', 'Respiratory', 'thoracentesis pleural tap'],
  ['Chest tube removal', 'HMS-PROC-000201', 'Respiratory', 'thoracostomy tube removal'],
  ['Needle thoracocentesis', 'HMS-PROC-000202', 'Respiratory', 'tension pneumothorax decompression'],
  ['Tracheostomy', 'HMS-PROC-000203', 'Airway', 'surgical airway tracheotomy'],
  ['Cricothyroidotomy', 'HMS-PROC-000204', 'Airway', 'emergency surgical airway'],
  ['Suctioning of airway', 'HMS-PROC-000205', 'Airway', 'oropharyngeal tracheal suction'],
  ['Bag valve mask ventilation', 'HMS-PROC-000206', 'Airway', 'ambu bag manual ventilation'],
  ['Mechanical ventilation initiation', 'HMS-PROC-000207', 'Respiratory', 'ventilator setup intubated'],
  ['Continuous positive airway pressure therapy', 'HMS-PROC-000208', 'Respiratory', 'CPAP neonatal respiratory support'],
  ['Chest physiotherapy', 'HMS-PROC-000209', 'Respiratory', 'percussion postural drainage'],
  ['Peak flow measurement', 'HMS-PROC-000210', 'Respiratory', 'peak expiratory flow asthma'],
  ['Spirometry', 'HMS-PROC-000211', 'Respiratory', 'lung function test'],
  ['Pulse oximetry', 'HMS-PROC-000212', 'Respiratory', 'oxygen saturation SpO2'],
  ['Sputum induction', 'HMS-PROC-000213', 'Respiratory', 'induced sputum TB specimen'],

  // --- Cardiology and emergency ---------------------------------------------
  ['Electrocardiogram recording', 'HMS-PROC-000063', 'Cardiology', 'ECG EKG'],
  ['Cardioversion', 'HMS-PROC-000064', 'Cardiology', 'electrical cardioversion'],
  ['Defibrillation', 'HMS-PROC-000065', 'Emergency', 'cardiac defibrillation'],
  ['Cardiopulmonary resuscitation', 'HMS-PROC-000214', 'Emergency', 'CPR resuscitation arrest'],
  ['Pericardiocentesis', 'HMS-PROC-000215', 'Cardiology', 'pericardial tap tamponade'],
  ['Echocardiography', 'HMS-PROC-000216', 'Cardiology', 'cardiac ultrasound echo'],
  ['Blood pressure measurement', 'HMS-PROC-000217', 'Cardiology', 'BP check vitals'],
  ['Cardiac monitoring', 'HMS-PROC-000218', 'Cardiology', 'telemetry rhythm monitoring'],
  ['Focused assessment with sonography for trauma', 'HMS-PROC-000219', 'Emergency', 'FAST scan trauma ultrasound'],
  ['Cervical spine immobilization', 'HMS-PROC-000220', 'Emergency', 'collar spinal immobilization'],
  ['Log roll and spinal precautions', 'HMS-PROC-000221', 'Emergency', 'spinal board log roll'],
  ['Triage assessment', 'HMS-PROC-000222', 'Emergency', 'emergency triage categorisation'],
  ['Rapid sequence induction', 'HMS-PROC-000223', 'Emergency', 'RSI emergency intubation'],
  ['Snakebite wound management', 'HMS-PROC-000224', 'Emergency', 'snake bite antivenom care'],

  // --- Neurology ------------------------------------------------------------
  ['Lumbar puncture', 'HMS-PROC-000040', 'Neurology', 'spinal tap CSF'],
  ['Therapeutic lumbar puncture', 'HMS-PROC-000225', 'Neurology', 'CSF drainage raised pressure cryptococcal'],
  ['Ventricular tap', 'HMS-PROC-000226', 'Neurology', 'neonatal ventricular puncture'],
  ['Burr hole drainage', 'HMS-PROC-000227', 'Neurology', 'subdural haematoma burr hole'],
  ['Craniotomy', 'HMS-PROC-000228', 'Neurology', 'skull surgery neurosurgical'],
  ['Electroencephalography', 'HMS-PROC-000229', 'Neurology', 'EEG brain wave seizure'],
  ['Nerve block', 'HMS-PROC-000230', 'Neurology', 'peripheral nerve block analgesia'],

  // --- Anaesthesia ----------------------------------------------------------
  ['General anaesthesia', 'HMS-PROC-000231', 'Anaesthesia', 'GA anaesthetic'],
  ['Spinal anaesthesia', 'HMS-PROC-000232', 'Anaesthesia', 'subarachnoid block'],
  ['Epidural anaesthesia', 'HMS-PROC-000233', 'Anaesthesia', 'epidural analgesia labour'],
  ['Local anaesthetic infiltration', 'HMS-PROC-000234', 'Anaesthesia', 'lignocaine local infiltration'],
  ['Ketamine sedation', 'HMS-PROC-000235', 'Anaesthesia', 'procedural sedation ketamine'],
  ['Procedural sedation', 'HMS-PROC-000236', 'Anaesthesia', 'conscious sedation'],
  ['Preoperative anaesthetic assessment', 'HMS-PROC-000237', 'Anaesthesia', 'pre-anaesthetic review ASA'],

  // --- Paediatrics and neonatal ---------------------------------------------
  ['Neonatal resuscitation', 'HMS-PROC-000238', 'Pediatrics', 'newborn resuscitation helping babies breathe'],
  ['Kangaroo mother care initiation', 'HMS-PROC-000239', 'Pediatrics', 'KMC skin to skin preterm'],
  ['Phototherapy', 'HMS-PROC-000240', 'Pediatrics', 'neonatal jaundice light therapy'],
  ['Newborn examination', 'HMS-PROC-000241', 'Pediatrics', 'neonatal check head to toe'],
  ['Growth monitoring and plotting', 'HMS-PROC-000242', 'Pediatrics', 'weight height MUAC growth chart'],
  ['Immunization administration', 'HMS-PROC-000243', 'Pediatrics', 'vaccination immunisation EPI'],
  ['Nasogastric feeding', 'HMS-PROC-000244', 'Pediatrics', 'NG feeds paediatric nutrition'],
  ['Therapeutic feeding for severe acute malnutrition', 'HMS-PROC-000245', 'Nutrition', 'F75 F100 RUTF malnutrition'],
  ['Nutritional assessment', 'HMS-PROC-000246', 'Nutrition', 'MUAC nutrition screening'],
  ['Oral rehydration therapy', 'HMS-PROC-000247', 'Pediatrics', 'ORS rehydration diarrhoea'],
  ['Intravenous rehydration', 'HMS-PROC-000248', 'Pediatrics', 'IV fluids dehydration resuscitation'],
  ['Umbilical cord care', 'HMS-PROC-000249', 'Pediatrics', 'chlorhexidine cord care newborn'],

  // --- Nursing and ward care ------------------------------------------------
  ['Vital signs measurement', 'HMS-PROC-000250', 'Nursing care', 'observations temperature pulse respiration'],
  ['Intramuscular injection', 'HMS-PROC-000251', 'Nursing care', 'IM injection'],
  ['Subcutaneous injection', 'HMS-PROC-000252', 'Nursing care', 'SC injection insulin'],
  ['Intravenous drug administration', 'HMS-PROC-000253', 'Nursing care', 'IV push infusion medication'],
  ['Urinary catheter care', 'HMS-PROC-000254', 'Nursing care', 'catheter hygiene maintenance'],
  ['Urinary catheter removal', 'HMS-PROC-000255', 'Nursing care', 'catheter removal trial without catheter'],
  ['Bed bath', 'HMS-PROC-000256', 'Nursing care', 'patient hygiene bathing'],
  ['Pressure area care', 'HMS-PROC-000257', 'Nursing care', 'turning repositioning pressure sore prevention'],
  ['Fluid balance monitoring', 'HMS-PROC-000258', 'Nursing care', 'input output chart'],
  ['Blood glucose monitoring', 'HMS-PROC-000259', 'Nursing care', 'RBS glucometer finger prick'],
  ['Specimen collection', 'HMS-PROC-000260', 'Nursing care', 'sample collection urine stool sputum'],
  ['Wound swab collection', 'HMS-PROC-000261', 'Nursing care', 'culture swab wound'],

  // --- Rehabilitation -------------------------------------------------------
  ['Physiotherapy session', 'HMS-PROC-000262', 'Rehabilitation', 'physio exercises mobilisation'],
  ['Occupational therapy session', 'HMS-PROC-000263', 'Rehabilitation', 'OT functional rehabilitation'],
  ['Speech and language therapy session', 'HMS-PROC-000264', 'Rehabilitation', 'speech therapy swallowing'],
  ['Gait training', 'HMS-PROC-000265', 'Rehabilitation', 'walking training crutches'],
  ['Prosthesis fitting', 'HMS-PROC-000266', 'Rehabilitation', 'artificial limb fitting'],
  ['Orthosis fitting', 'HMS-PROC-000267', 'Rehabilitation', 'brace splint orthotic fitting'],

  // --- Mental health --------------------------------------------------------
  ['Mental state examination', 'HMS-PROC-000268', 'Mental health', 'MSE psychiatric assessment'],
  ['Individual psychotherapy session', 'HMS-PROC-000269', 'Mental health', 'counselling talk therapy'],
  ['Group therapy session', 'HMS-PROC-000270', 'Mental health', 'group counselling'],
  ['Substance use assessment', 'HMS-PROC-000271', 'Mental health', 'alcohol drug screening'],
  ['Suicide risk assessment', 'HMS-PROC-000272', 'Mental health', 'self harm risk evaluation'],
  ['Electroconvulsive therapy', 'HMS-PROC-000273', 'Mental health', 'ECT'],

  // --- Oncology and palliative care -----------------------------------------
  ['Chemotherapy administration', 'HMS-PROC-000274', 'Oncology', 'cytotoxic infusion cancer treatment'],
  ['Radiotherapy session', 'HMS-PROC-000275', 'Oncology', 'radiation treatment'],
  ['Bone marrow aspiration', 'HMS-PROC-000276', 'Oncology', 'marrow aspirate biopsy'],
  ['Bone marrow trephine biopsy', 'HMS-PROC-000277', 'Oncology', 'trephine core marrow biopsy'],
  ['Palliative care review', 'HMS-PROC-000278', 'Oncology', 'palliative symptom control review'],
  ['Pain management review', 'HMS-PROC-000279', 'Oncology', 'analgesia ladder morphine review'],

  // --- HIV, TB and public health --------------------------------------------
  ['HIV testing and counselling', 'HMS-PROC-000280', 'Infectious disease', 'HCT VCT HIV test counselling'],
  ['Antiretroviral therapy initiation', 'HMS-PROC-000281', 'Infectious disease', 'ART start HIV treatment'],
  ['Adherence counselling', 'HMS-PROC-000282', 'Infectious disease', 'treatment adherence support'],
  ['Directly observed therapy', 'HMS-PROC-000283', 'Infectious disease', 'DOT TB treatment observation'],
  ['Post-exposure prophylaxis initiation', 'HMS-PROC-000284', 'Infectious disease', 'PEP needlestick exposure'],
  ['Contact tracing', 'HMS-PROC-000285', 'Infectious disease', 'index contact follow up'],
  ['Isolation precautions setup', 'HMS-PROC-000286', 'Infectious disease', 'infection control isolation barrier nursing'],
  ['Male medical circumcision counselling', 'HMS-PROC-000287', 'Infectious disease', 'SMC counselling HIV prevention'],

  // --- Diagnostics at the bedside -------------------------------------------
  ['Bedside ultrasound scan', 'HMS-PROC-000288', 'Diagnostics', 'POCUS point of care ultrasound'],
  ['Abdominal ultrasound scan', 'HMS-PROC-000289', 'Diagnostics', 'abdominal sonography'],
  ['Rapid diagnostic test for malaria', 'HMS-PROC-000290', 'Diagnostics', 'mRDT malaria rapid test'],
  ['Urine dipstick testing', 'HMS-PROC-000291', 'Diagnostics', 'urinalysis dipstick bedside'],
  ['Pregnancy test', 'HMS-PROC-000292', 'Diagnostics', 'urine hCG pregnancy test'],
  ['Anthropometric measurement', 'HMS-PROC-000293', 'Diagnostics', 'height weight BMI measurement'],
];

const toSentenceCase = (value) => {
  const text = String(value || '').trim().replace(/\s+/g, ' ');
  return text ? text.charAt(0).toUpperCase() + text.slice(1) : '';
};

const normalizeUpper = (value) => String(value || '').trim().toUpperCase();

const assertUniqueProcedureCatalog = (entries) => {
  const seenCodes = new Map();
  const seenDescriptions = new Map();
  entries.forEach(([description, code], index) => {
    const normalizedCode = normalizeUpper(code);
    const normalizedDescription = String(description).trim().toLowerCase();
    if (!normalizedCode || !normalizedDescription) {
      throw new Error(`procedureCatalog[${index}] is missing a description or code`);
    }
    if (seenCodes.has(normalizedCode)) {
      throw new Error(
        `procedureCatalog has duplicate code "${code}" at indexes ${seenCodes.get(normalizedCode)} and ${index}`
      );
    }
    if (seenDescriptions.has(normalizedDescription)) {
      throw new Error(
        `procedureCatalog has duplicate description "${description}" at indexes ${seenDescriptions.get(normalizedDescription)} and ${index}`
      );
    }
    seenCodes.set(normalizedCode, index);
    seenDescriptions.set(normalizedDescription, index);
  });
};

assertUniqueProcedureCatalog(procedureCatalog);

const buildCommonProcedureTerms = () =>
  procedureCatalog.map(([description, code, category, keywords], index) => {
    const normalizedDescription = toSentenceCase(description);
    const normalizedCode = normalizeUpper(code);
    return {
      code: normalizedCode,
      description: normalizedDescription,
      category,
      origin: 'PROCEDURE_CATALOG',
      rank: index,
      search_text: normalizeUpper(
        [normalizedDescription, normalizedCode, category, keywords].filter(Boolean).join(' ')
      ),
    };
  });

const COMMON_PROCEDURE_TERMS = Object.freeze(buildCommonProcedureTerms());

module.exports = {
  COMMON_PROCEDURE_TERMS,
};
