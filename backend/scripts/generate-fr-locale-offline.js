/**
 * Fast offline French locale generation from English sources.
 *
 * Usage (from repo root):
 *   node backend/scripts/generate-fr-locale-offline.js
 */

const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..', '..');

const EXACT_PHRASES = new Map([
  ['HOSSPI Hospital Management System', 'HOSSPI Système de gestion hospitalière'],
  ['HOSSPI HMS', 'HOSSPI HMS'],
  ['Settings', 'Paramètres'],
  ['Language', 'Langue'],
  ['English', 'Anglais'],
  ['French', 'Français'],
  ['Refresh', 'Actualiser'],
  ['Try again', 'Réessayer'],
  ['Save', 'Enregistrer'],
  ['Cancel', 'Annuler'],
  ['Close', 'Fermer'],
  ['Delete', 'Supprimer'],
  ['Edit', 'Modifier'],
  ['Add', 'Ajouter'],
  ['Search', 'Rechercher'],
  ['Profile', 'Profil'],
  ['Password', 'Mot de passe'],
  ['Email', 'E-mail'],
  ['Male', 'Homme'],
  ['Female', 'Femme'],
  ['Other', 'Autre'],
  ['Unknown', 'Inconnu'],
  ['Light', 'Clair'],
  ['Dark', 'Sombre'],
  ['System', 'Système'],
  ['Preferences', 'Préférences'],
  ['Theme', 'Thème'],
  ['Account', 'Compte'],
  ['Notifications', 'Notifications'],
  ['Logout', 'Déconnexion'],
  ['Login', 'Connexion'],
  ['Sign in', 'Se connecter'],
  ['Sign out', 'Se déconnecter'],
  ['Loading', 'Chargement'],
  ['Error', 'Erreur'],
  ['Success', 'Succès'],
  ['Warning', 'Avertissement'],
  ['Required', 'Obligatoire'],
  ['Optional', 'Facultatif'],
  ['Active', 'Actif'],
  ['Inactive', 'Inactif'],
  ['Pending', 'En attente'],
  ['Approved', 'Approuvé'],
  ['Rejected', 'Rejeté'],
  ['Completed', 'Terminé'],
  ['Cancelled', 'Annulé'],
  ['Yes', 'Oui'],
  ['No', 'Non'],
  ['All', 'Tous'],
  ['None', 'Aucun'],
  ['Name', 'Nom'],
  ['Status', 'Statut'],
  ['Date', 'Date'],
  ['Time', 'Heure'],
  ['Notes', 'Notes'],
  ['Description', 'Description'],
  ['Details', 'Détails'],
  ['Actions', 'Actions'],
  ['Filters', 'Filtres'],
  ['Export', 'Exporter'],
  ['Import', 'Importer'],
  ['Print', 'Imprimer'],
  ['Download', 'Télécharger'],
  ['Upload', 'Téléverser'],
  ['Back', 'Retour'],
  ['Next', 'Suivant'],
  ['Previous', 'Précédent'],
  ['Submit', 'Soumettre'],
  ['Confirm', 'Confirmer'],
  ['Continue', 'Continuer'],
  ['Select', 'Sélectionner'],
  ['Clear', 'Effacer'],
  ['Reset', 'Réinitialiser'],
  ['Update', 'Mettre à jour'],
  ['Create', 'Créer'],
  ['Remove', 'Retirer'],
  ['View', 'Voir'],
  ['Open', 'Ouvrir'],
  ['Copy', 'Copier'],
  ['Help', 'Aide'],
  ['Dashboard', 'Tableau de bord'],
  ['Patients', 'Patients'],
  ['Appointments', 'Rendez-vous'],
  ['Billing', 'Facturation'],
  ['Pharmacy', 'Pharmacie'],
  ['Laboratory', 'Laboratoire'],
  ['Radiology', 'Radiologie'],
  ['Nursing', 'Soins infirmiers'],
  ['Emergency', 'Urgences'],
  ['Admission', 'Admission'],
  ['Discharge', 'Sortie'],
  ['Ward', 'Service'],
  ['Room', 'Chambre'],
  ['Bed', 'Lit'],
  ['Doctor', 'Médecin'],
  ['Nurse', 'Infirmier'],
  ['Patient', 'Patient'],
  ['Choose English or French for the app interface.', 'Choisissez l\'anglais ou le français pour l\'interface de l\'application.'],
  ['Set HOSSPI HMS preferences.', 'Définir les préférences HOSSPI HMS.'],
  ['Theme, language, and local display choices.', 'Thème, langue et choix d\'affichage locaux.'],
  ['App language', 'Langue de l\'application'],
  ['Use system, light, or dark mode.', 'Utiliser le mode système, clair ou sombre.'],
  ['Follow the device setting.', 'Suivre le réglage de l\'appareil.'],
  ['Profile updated.', 'Profil mis à jour.'],
  ['Profile could not be updated.', 'Le profil n\'a pas pu être mis à jour.'],
]);

const WORD_REPLACEMENTS = [
  ['successfully', 'avec succès'],
  ['not found', 'introuvable'],
  ['already exists', 'existe déjà'],
  ['is required', 'est requis'],
  ['are required', 'sont requis'],
  ['must be', 'doit être'],
  ['must not', 'ne doit pas'],
  ['cannot', 'ne peut pas'],
  ['Could not', 'Impossible de'],
  ['could not', 'n\'a pas pu'],
  ['Invalid', 'Invalide'],
  ['invalid', 'invalide'],
  ['Unauthorized', 'Non autorisé'],
  ['Forbidden', 'Interdit'],
  ['permission', 'autorisation'],
  ['permissions', 'autorisations'],
  ['created', 'créé'],
  ['updated', 'mis à jour'],
  ['deleted', 'supprimé'],
  ['retrieved', 'récupéré'],
  ['listed', 'listé'],
  ['account', 'compte'],
  ['password', 'mot de passe'],
  ['Showing ', 'Affichage de '],
  [' of ', ' sur '],
  ['email', 'e-mail'],
  ['address', 'adresse'],
  ['appointment', 'rendez-vous'],
  ['admission', 'admission'],
  ['patient', 'patient'],
  ['facility', 'établissement'],
  ['tenant', 'locataire'],
  ['department', 'département'],
  ['branch', 'succursale'],
  ['record', 'dossier'],
  ['records', 'dossiers'],
  ['report', 'rapport'],
  ['reports', 'rapports'],
  ['invoice', 'facture'],
  ['payment', 'paiement'],
  ['subscription', 'abonnement'],
  ['settings', 'paramètres'],
  ['profile', 'profil'],
  ['user', 'utilisateur'],
  ['users', 'utilisateurs'],
  ['role', 'rôle'],
  ['roles', 'rôles'],
  ['module', 'module'],
  ['modules', 'modules'],
  ['search', 'recherche'],
  ['filter', 'filtre'],
  ['filters', 'filtres'],
  ['status', 'statut'],
  ['active', 'actif'],
  ['inactive', 'inactif'],
  ['pending', 'en attente'],
  ['approved', 'approuvé'],
  ['rejected', 'rejeté'],
  ['cancelled', 'annulé'],
  ['completed', 'terminé'],
  ['scheduled', 'planifié'],
  ['available', 'disponible'],
  ['unavailable', 'indisponible'],
  ['required', 'requis'],
  ['optional', 'facultatif'],
  ['warning', 'avertissement'],
  ['error', 'erreur'],
  ['errors', 'erreurs'],
  ['message', 'message'],
  ['messages', 'messages'],
  ['notification', 'notification'],
  ['notifications', 'notifications'],
  ['workspace', 'espace de travail'],
  ['dashboard', 'tableau de bord'],
  ['summary', 'résumé'],
  ['details', 'détails'],
  ['history', 'historique'],
  ['notes', 'notes'],
  ['description', 'description'],
  ['name', 'nom'],
  ['date', 'date'],
  ['time', 'heure'],
  ['phone', 'téléphone'],
  ['contact', 'contact'],
  ['contacts', 'contacts'],
  ['save', 'enregistrer'],
  ['cancel', 'annuler'],
  ['close', 'fermer'],
  ['delete', 'supprimer'],
  ['edit', 'modifier'],
  ['add', 'ajouter'],
  ['create', 'créer'],
  ['update', 'mettre à jour'],
  ['remove', 'retirer'],
  ['view', 'voir'],
  ['open', 'ouvrir'],
  ['select', 'sélectionner'],
  ['confirm', 'confirmer'],
  ['submit', 'soumettre'],
  ['continue', 'continuer'],
  ['back', 'retour'],
  ['next', 'suivant'],
  ['previous', 'précédent'],
  ['refresh', 'actualiser'],
  ['loading', 'chargement'],
  ['processing', 'traitement'],
  ['please', 'veuillez'],
  ['before', 'avant'],
  ['after', 'après'],
  ['today', 'aujourd\'hui'],
  ['yesterday', 'hier'],
  ['tomorrow', 'demain'],
  ['all', 'tous'],
  ['none', 'aucun'],
  ['yes', 'oui'],
  ['no', 'non'],
  ['or', 'ou'],
  ['and', 'et'],
  ['with', 'avec'],
  ['without', 'sans'],
  ['from', 'de'],
  ['to', 'à'],
  ['for', 'pour'],
  ['the', 'le'],
  ['The', 'Le'],
  ['a', 'un'],
  ['A', 'Un'],
  ['an', 'un'],
  ['An', 'Un'],
  ['your', 'votre'],
  ['Your', 'Votre'],
  ['this', 'ce'],
  ['This', 'Ce'],
  ['that', 'cette'],
  ['That', 'Cette'],
  ['when', 'lorsque'],
  ['while', 'pendant'],
  ['during', 'pendant'],
  ['using', 'en utilisant'],
  ['use', 'utiliser'],
  ['used', 'utilisé'],
  ['show', 'afficher'],
  ['hide', 'masquer'],
  ['enable', 'activer'],
  ['disable', 'désactiver'],
  ['enabled', 'activé'],
  ['disabled', 'désactivé'],
  ['new', 'nouveau'],
  ['old', 'ancien'],
  ['current', 'actuel'],
  ['default', 'par défaut'],
  ['custom', 'personnalisé'],
  ['total', 'total'],
  ['count', 'nombre'],
  ['type', 'type'],
  ['types', 'types'],
  ['category', 'catégorie'],
  ['categories', 'catégories'],
  ['list', 'liste'],
  ['item', 'élément'],
  ['items', 'éléments'],
  ['field', 'champ'],
  ['fields', 'champs'],
  ['value', 'valeur'],
  ['values', 'valeurs'],
  ['option', 'option'],
  ['options', 'options'],
  ['result', 'résultat'],
  ['results', 'résultats'],
  ['request', 'demande'],
  ['requests', 'demandes'],
  ['response', 'réponse'],
  ['action', 'action'],
  ['actions', 'actions'],
  ['access', 'accès'],
  ['security', 'sécurité'],
  ['administration', 'administration'],
  ['configuration', 'configuration'],
  ['integration', 'intégration'],
  ['integrations', 'intégrations'],
  ['service', 'service'],
  ['services', 'services'],
  ['provider', 'prestataire'],
  ['providers', 'prestataires'],
  ['clinical', 'clinique'],
  ['medical', 'médical'],
  ['hospital', 'hôpital'],
  ['health', 'santé'],
  ['care', 'soins'],
  ['treatment', 'traitement'],
  ['diagnosis', 'diagnostic'],
  ['procedure', 'procédure'],
  ['prescription', 'ordonnance'],
  ['medication', 'médicament'],
  ['medications', 'médicaments'],
  ['dosage', 'posologie'],
  ['dose', 'dose'],
  ['allergy', 'allergie'],
  ['allergies', 'allergies'],
  ['vital', 'vital'],
  ['vitals', 'signes vitaux'],
  ['lab', 'laboratoire'],
  ['radiology', 'radiologie'],
  ['pharmacy', 'pharmacie'],
  ['nursing', 'soins infirmiers'],
  ['emergency', 'urgence'],
  ['icu', 'soins intensifs'],
  ['theater', 'bloc opératoire'],
  ['mortuary', 'morgue'],
  ['housekeeping', 'entretien'],
  ['biomedical', 'biomédical'],
  ['physiotherapy', 'physiothérapie'],
  ['hr', 'rh'],
  ['staff', 'personnel'],
  ['employee', 'employé'],
  ['employees', 'employés'],
  ['shift', 'quart'],
  ['schedule', 'planning'],
  ['leave', 'congé'],
  ['payroll', 'paie'],
  ['compensation', 'rémunération'],
  ['invoice', 'facture'],
  ['invoices', 'factures'],
  ['claim', 'réclamation'],
  ['claims', 'réclamations'],
  ['payment', 'paiement'],
  ['payments', 'paiements'],
  ['amount', 'montant'],
  ['currency', 'devise'],
  ['price', 'prix'],
  ['plan', 'forfait'],
  ['plans', 'forfaits'],
  ['subscription', 'abonnement'],
  ['license', 'licence'],
  ['tenant', 'locataire'],
  ['facility', 'établissement'],
  ['facilities', 'établissements'],
  ['branch', 'succursale'],
  ['branches', 'succursales'],
  ['department', 'département'],
  ['departments', 'départements'],
  ['unit', 'unité'],
  ['units', 'unités'],
  ['ward', 'service'],
  ['wards', 'services'],
  ['room', 'chambre'],
  ['rooms', 'chambres'],
  ['bed', 'lit'],
  ['beds', 'lits'],
  ['occupancy', 'occupation'],
  ['occupied', 'occupé'],
  ['vacant', 'vacant'],
  ['reserved', 'réservé'],
  ['maintenance', 'maintenance'],
  ['equipment', 'équipement'],
  ['asset', 'actif'],
  ['assets', 'actifs'],
  ['inventory', 'inventaire'],
  ['stock', 'stock'],
  ['supplier', 'fournisseur'],
  ['order', 'commande'],
  ['orders', 'commandes'],
  ['dispatch', 'expédition'],
  ['trip', 'trajet'],
  ['ambulance', 'ambulance'],
  ['transport', 'transport'],
  ['triage', 'triage'],
  ['consultation', 'consultation'],
  ['encounter', 'consultation'],
  ['encounters', 'consultations'],
  ['visit', 'visite'],
  ['visits', 'visites'],
  ['outpatient', 'ambulatoire'],
  ['inpatient', 'hospitalisé'],
  ['referral', 'orientation'],
  ['referrals', 'orientations'],
  ['transfer', 'transfert'],
  ['transfers', 'transferts'],
  ['handoff', 'passation'],
  ['handoffs', 'passations'],
  ['discharge', 'sortie'],
  ['admit', 'admettre'],
  ['admitted', 'admis'],
  ['discharged', 'sorti'],
  ['registered', 'enregistré'],
  ['registration', 'inscription'],
  ['verification', 'vérification'],
  ['verified', 'vérifié'],
  ['suspended', 'suspendu'],
  ['suspension', 'suspension'],
  ['approval', 'approbation'],
  ['awaiting', 'en attente de'],
  ['sign in', 'se connecter'],
  ['sign out', 'se déconnecter'],
  ['log in', 'se connecter'],
  ['log out', 'se déconnecter'],
  ['logged in', 'connecté'],
  ['logged out', 'déconnecté'],
  ['session', 'session'],
  ['token', 'jeton'],
  ['expired', 'expiré'],
  ['expires', 'expire'],
  ['timeout', 'délai d\'attente'],
  ['network', 'réseau'],
  ['connection', 'connexion'],
  ['offline', 'hors ligne'],
  ['online', 'en ligne'],
  ['sync', 'synchronisation'],
  ['synchronized', 'synchronisé'],
  ['realtime', 'temps réel'],
  ['live', 'en direct'],
  ['draft', 'brouillon'],
  ['published', 'publié'],
  ['archived', 'archivé'],
  ['template', 'modèle'],
  ['templates', 'modèles'],
  ['reported', 'signalé'],
  ['resolved', 'résolu'],
  ['open', 'ouvert'],
  ['closed', 'fermé'],
  ['assigned', 'assigné'],
  ['unassigned', 'non assigné'],
  ['priority', 'priorité'],
  ['high', 'élevé'],
  ['medium', 'moyen'],
  ['low', 'faible'],
  ['critical', 'critique'],
  ['urgent', 'urgent'],
  ['routine', 'routine'],
  ['normal', 'normal'],
  ['abnormal', 'anormal'],
  ['positive', 'positif'],
  ['negative', 'négatif'],
  ['male', 'homme'],
  ['female', 'femme'],
  ['other', 'autre'],
  ['unknown', 'inconnu'],
  ['first name', 'prénom'],
  ['middle name', 'deuxième prénom'],
  ['last name', 'nom de famille'],
  ['gender', 'genre'],
  ['age', 'âge'],
  ['birth', 'naissance'],
  ['death', 'décès'],
  ['identifier', 'identifiant'],
  ['identifiers', 'identifiants'],
  ['reference', 'référence'],
  ['code', 'code'],
  ['label', 'libellé'],
  ['labels', 'libellés'],
  ['title', 'titre'],
  ['body', 'corps'],
  ['header', 'en-tête'],
  ['footer', 'pied de page'],
  ['menu', 'menu'],
  ['navigation', 'navigation'],
  ['toolbar', 'barre d\'outils'],
  ['panel', 'panneau'],
  ['section', 'section'],
  ['tab', 'onglet'],
  ['tabs', 'onglets'],
  ['row', 'ligne'],
  ['rows', 'lignes'],
  ['column', 'colonne'],
  ['columns', 'colonnes'],
  ['table', 'tableau'],
  ['chart', 'graphique'],
  ['graph', 'graphique'],
  ['metric', 'indicateur'],
  ['metrics', 'indicateurs'],
  ['kpi', 'indicateur clé'],
  ['summary card', 'carte récapitulative'],
  ['empty state', 'état vide'],
  ['no data', 'aucune donnée'],
  ['no results', 'aucun résultat'],
  ['not available', 'non disponible'],
  ['not supported', 'non pris en charge'],
  ['not allowed', 'non autorisé'],
  ['not configured', 'non configuré'],
  ['not implemented', 'non implémenté'],
  ['coming soon', 'bientôt disponible'],
  ['work in progress', 'en cours'],
  ['beta', 'bêta'],
  ['preview', 'aperçu'],
  ['demo', 'démo'],
  ['seed', 'amorçage'],
  ['test', 'test'],
  ['tests', 'tests'],
  ['validation', 'validation'],
  ['validated', 'validé'],
  ['failed', 'échoué'],
  ['failure', 'échec'],
  ['succeeded', 'réussi'],
  ['success', 'succès'],
  ['retry', 'réessayer'],
  ['try again', 'réessayer'],
  ['starting app', 'Démarrage de l\'application'],
  ['Preparing local services.', 'Préparation des services locaux.'],
  ['The app could not start', 'L\'application n\'a pas pu démarrer'],
  ['Restart the app or try again.', 'Redémarrez l\'application ou réessayez.'],
];

const TEMPLATE_RULES = [
  [/^(.+) not found$/i, '$1 introuvable'],
  [/^(.+) created successfully$/i, '$1 créé avec succès'],
  [/^(.+) updated successfully$/i, '$1 mis à jour avec succès'],
  [/^(.+) deleted successfully$/i, '$1 supprimé avec succès'],
  [/^(.+) retrieved successfully$/i, '$1 récupéré avec succès'],
  [/^(.+) listed successfully$/i, '$1 listé avec succès'],
  [/^Cannot (.+)$/i, 'Impossible de $1'],
  [/^Failed to (.+)$/i, 'Échec de $1'],
  [/^Unable to (.+)$/i, 'Impossible de $1'],
  [/^Invalid (.+)$/i, '$1 invalide'],
  [/^(.+) is required$/i, '$1 est requis'],
  [/^(.+) are required$/i, '$1 sont requis'],
  [/^(.+) must be (.+)$/i, '$1 doit être $2'],
  [/^(.+) already exists$/i, '$1 existe déjà'],
  [/^(.+) is already (.+)$/i, '$1 est déjà $2'],
  [/^(.+) could not be (.+)$/i, '$1 n\'a pas pu être $2'],
  [/^No (.+) found$/i, 'Aucun $1 trouvé'],
  [/^No (.+) available$/i, 'Aucun $1 disponible'],
];

const protectBracedSegments = (text) => {
  const tokens = [];
  let result = '';
  let index = 0;

  while (index < text.length) {
    if (text[index] !== '{') {
      result += text[index];
      index += 1;
      continue;
    }

    let depth = 0;
    let end = index;
    while (end < text.length) {
      if (text[end] === '{') {
        depth += 1;
      }
      if (text[end] === '}') {
        depth -= 1;
        if (depth === 0) {
          end += 1;
          break;
        }
      }
      end += 1;
    }

    const segment = text.slice(index, end);
    const token = `__PH${tokens.length}__`;
    tokens.push(segment);
    result += token;
    index = end;
  }

  return { protectedText: result, tokens };
};

const restoreBracedSegments = (text, tokens) => {
  let restored = text;
  tokens.forEach((token, tokenIndex) => {
    restored = restored.replace(`__PH${tokenIndex}__`, token);
  });
  return restored;
};

const translatePluralOrSelectSegment = (segment) => {
  const pluralMatch = segment.match(/^\{([^,]+),\s*plural,(.*)\}$/s);
  if (pluralMatch) {
    const variable = pluralMatch[1];
    const body = pluralMatch[2];
    const translatedBody = body.replace(
      /(=\d+|\w+)\s*\{([^{}]*)\}/g,
      (match, keyword, content) => `${keyword} {${applyWordReplacements(content)}}`,
    );
    return `{${variable}, plural,${translatedBody}}`;
  }

  const selectMatch = segment.match(/^\{([^,]+),\s*select,(.*)\}$/s);
  if (selectMatch) {
    const variable = selectMatch[1];
    const body = selectMatch[2];
    const translatedBody = body.replace(
      /(\w+)\s*\{([^{}]*)\}/g,
      (match, keyword, content) => `${keyword} {${applyWordReplacements(content)}}`,
    );
    return `{${variable}, select,${translatedBody}}`;
  }

  return segment;
};

const translateWithBraces = (text) => {
  let result = '';
  let index = 0;

  while (index < text.length) {
    if (text[index] !== '{') {
      const nextBrace = text.indexOf('{', index);
      const end = nextBrace === -1 ? text.length : nextBrace;
      result += applyWordReplacements(text.slice(index, end));
      index = end;
      continue;
    }

    let depth = 0;
    let end = index;
    while (end < text.length) {
      if (text[end] === '{') {
        depth += 1;
      }
      if (text[end] === '}') {
        depth -= 1;
        if (depth === 0) {
          end += 1;
          break;
        }
      }
      end += 1;
    }

    const segment = text.slice(index, end);
    if (/,\s*(plural|select)\s*,/.test(segment)) {
      result += translatePluralOrSelectSegment(segment);
    } else {
      result += segment;
    }

    index = end;
  }

  return result;
};

const protectPlaceholders = protectBracedSegments;
const restorePlaceholders = restoreBracedSegments;

const applyWordReplacements = (text) => {
  let result = text;
  WORD_REPLACEMENTS.forEach(([from, to]) => {
    const pattern = new RegExp(`\\b${from.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'g');
    result = result.replace(pattern, to);
  });
  return result;
};

const offlineTranslate = (text) => {
  if (!text || typeof text !== 'string') {
    return text;
  }

  const trimmed = text.trim();
  if (!trimmed) {
    return text;
  }

  if (EXACT_PHRASES.has(trimmed)) {
    return EXACT_PHRASES.get(trimmed);
  }

  for (const [pattern, replacement] of TEMPLATE_RULES) {
    if (pattern.test(trimmed)) {
      return trimmed.replace(pattern, replacement);
    }
  }

  if (trimmed.includes('{')) {
    return translateWithBraces(trimmed);
  }

  return applyWordReplacements(trimmed);
};

const translateObjectValues = (source) => {
  const output = {};
  Object.keys(source).forEach((key) => {
    const value = source[key];
    output[key] = typeof value === 'string' ? offlineTranslate(value) : value;
  });
  return output;
};

const generateBackendFr = () => {
  const sourcePath = path.join(repoRoot, 'backend', 'src', 'locales', 'en.json');
  const targetPath = path.join(repoRoot, 'backend', 'src', 'locales', 'fr.json');
  const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
  const translated = translateObjectValues(source);
  fs.writeFileSync(targetPath, `${JSON.stringify(translated, null, 2)}\n`);
  console.log(`[fr-offline] Wrote ${targetPath} (${Object.keys(translated).length} keys)`);
};

const generateFrontendFr = () => {
  const sourcePath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_en.arb');
  const targetPath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_fr.arb');
  const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
  const output = { '@@locale': 'fr' };

  Object.keys(source).forEach((key) => {
    if (key === '@@locale') {
      return;
    }

    if (key.startsWith('@')) {
      output[key] = source[key];
      return;
    }

    const value = source[key];
    output[key] = typeof value === 'string' ? offlineTranslate(value) : value;
    const metadataKey = `@${key}`;
    if (Object.prototype.hasOwnProperty.call(source, metadataKey)) {
      output[metadataKey] = source[metadataKey];
    }
  });

  fs.writeFileSync(targetPath, `${JSON.stringify(output, null, 2)}\n`);
  console.log(`[fr-offline] Wrote ${targetPath}`);
};

const main = () => {
  generateBackendFr();
  generateFrontendFr();
};

if (require.main === module) {
  main();
}

module.exports = {
  offlineTranslate,
  generateBackendFr,
  generateFrontendFr,
};
