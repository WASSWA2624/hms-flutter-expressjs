/**
 * Apply final manual French translations for strings that APIs leave unchanged.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const repoRoot = path.join(__dirname, '..', '..');

const FINAL_TRANSLATIONS = new Map([
  ['Instructions', 'Consignes'],
  ['Oral', 'Voie orale'],
  ['Impression/Conclusion', 'Impression / Conclusion'],
  ['Archive', 'Archiver'],
  ['Compensation', 'Rémunération'],
  ['Position', 'Poste'],
  ['Placement', 'Affectation'],
  ['Porter', 'Brancardier'],
  ['Physio', 'Physiothérapie'],
  ['Webhooks', 'Points de terminaison Web'],
  ['Webhook', 'Point de terminaison Web'],
  ['Variables', 'Variables'],
  ['Participants', 'Participants'],
  ['Configurations', 'Configurations'],
  ['Configuration', 'Configuration'],
  ['Administration', 'Administration'],
  ['Communications', 'Communications'],
  ['Disposition', 'Disposition'],
  ['Identification', 'Identification'],
  ['Attention', 'Attention'],
  ['{count}d', '{count} j'],
  ['{count}h', '{count} h'],
  ['{medication} {status}', '{medication} {status}'],
  ['{type} {batch}', '{type} {batch}'],
  ['{percent}%', '{percent} %'],
  ['Preparing local services.', 'Préparation des services locaux.'],
  ['Starting app', 'Démarrage de l\'application'],
]);

const applyMap = (enPath, frPath, isFrontend) => {
  const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));
  const fr = JSON.parse(fs.readFileSync(frPath, 'utf8'));
  let updated = 0;

  Object.keys(en).forEach((key) => {
    if (isFrontend && (key.startsWith('@') || key === '@@locale')) {
      return;
    }

    const english = en[key];
    if (typeof english !== 'string' || english !== fr[key]) {
      return;
    }

    const translation = FINAL_TRANSLATIONS.get(english.trim());
    if (translation && translation !== english) {
      fr[key] = translation;
      updated += 1;
    }
  });

  fs.writeFileSync(frPath, `${JSON.stringify(fr, null, 2)}\n`);
  console.log(`[finalize-fr] updated ${updated} entries in ${path.basename(frPath)}`);
};

applyMap(
  path.join(repoRoot, 'backend', 'src', 'locales', 'en.json'),
  path.join(repoRoot, 'backend', 'src', 'locales', 'fr.json'),
  false,
);

applyMap(
  path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_en.arb'),
  path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_fr.arb'),
  true,
);

const fixScript = path.join(repoRoot, 'frontend', 'tool', 'fix_fr_arb_icu.js');
if (fs.existsSync(fixScript)) {
  execSync(`node "${fixScript}"`, { stdio: 'inherit' });
}
