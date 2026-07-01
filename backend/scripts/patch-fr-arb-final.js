/**
 * Apply hand-reviewed French fixes for remaining problematic ARB entries.
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const frPath = path.join(__dirname, '..', '..', 'frontend', 'lib', 'l10n', 'app_fr.arb');
const fr = JSON.parse(fs.readFileSync(frPath, 'utf8'));

const FIXES = {
  theaterPageLabel: '{from}-{to} sur {total}',
  opdPageLabel: '{from}-{to} sur {total}',
  opdAvailableSlotsLabel:
    '{count, plural, =0{Aucun créneau ouvert} =1{1 créneau ouvert} other{{count} créneaux ouverts}}',
  patientsPageLabel: '{from}-{to} sur {total}',
  patientsDocumentsActivitySubtitle:
    '{count, plural, =1{1 patient n\'a pas de documents} other{{count} patients n\'ont pas de documents}}',
  ipdPharmacyClearancePending:
    '{count, plural, =1{1 commande ouverte} other{{count} commandes ouvertes}}',
  dischargePageLabel: '{from}-{to} sur {total}',
  dischargeGapBackendSubtitle: 'Prise en charge du flux de travail indisponible',
  dischargeGapInsuranceBody:
    "La validation d'assurance n'est pas encore connectée à ce flux de sortie.",
  radiologyPageLabel: 'Affichage de {from}-{to} sur {total}',
  radiologyNoTimelineBody:
    'Les événements du flux de travail apparaîtront au fur et à mesure de la progression de la commande.',
  pharmacyNoMedicationBody:
    "Cette commande n'a aucun médicament disponible dans le flux pharmacie.",
  claimsBackendGapDescription:
    'Ces éléments sont indisponibles dans le flux de réclamations actuel.',
  claimsBackendGapDraftBody:
    "La file d'attente des brouillons n'est pas disponible dans le flux de réclamations actuel.",
  labPageLabel: '{from}-{to} sur {total}',
  labBatchValidationSummaryMessage:
    '{count, plural, =1{1 test sélectionné nécessite une attention avant de poursuivre cette action.} other{{count} tests sélectionnés nécessitent une attention avant de poursuivre cette action.}}',
  operationsReportSummaryLine:
    '{total} demandes : {open} ouvertes, {inProgress} en cours, {completed} terminées.',
  biomedicalPageLabel: 'Affichage de {from}-{to} sur {total}',
  integrationsPageLabel: '{from}-{to} sur {total}',
  integrationsConfigCreateHelper:
    'Saisissez un paramètre clé=valeur par ligne. Les clés sensibles sont acceptées mais ne seront plus affichées.',
  communicationsPageLabel: '{from}-{to} sur {total}',
  mortuaryPageLabel: 'Affichage de {from}-{to} sur {total}',
  roomsBedsPageLabel: 'Affichage de {from}-{to} sur {total}',
  roomsBedsTransferDialogBody:
    "Choisissez le service de destination. La sélection du lit est effectuée par le flux de transfert IPD après approbation.",
  hrPageLabel: '{from}-{to} sur {total}',
  startupErrorTitle: "L'application n'a pas pu démarrer",
  startupErrorBody: "Redémarrez l'application ou réessayez.",
  navigationPatientsLabel: 'Registre des patients',
  patientsTitle: 'Registre des patients',
  startupLoadingBody: 'Préparation des services locaux.',
};

Object.assign(fr, FIXES);
fs.writeFileSync(frPath, `${JSON.stringify(fr, null, 2)}\n`);

const fixScript = path.join(__dirname, '..', '..', 'frontend', 'tool', 'fix_fr_arb_icu.js');
if (fs.existsSync(fixScript)) {
  execSync(`node "${fixScript}"`, { stdio: 'inherit' });
}

console.log(`[patch-fr-arb] applied ${Object.keys(FIXES).length} fixes`);
