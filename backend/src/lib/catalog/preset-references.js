/**
 * Who points at a catalog definition.
 *
 * Deduplicating per-tenant catalog rows onto shared platform presets means
 * repointing every foreign key that referenced the row being retired. Missing
 * one would either break the constraint or, worse, leave an order pointing at a
 * soft-deleted definition.
 *
 * The referrer list is derived from `schema.prisma` rather than written out by
 * hand, so a table added later is picked up without anyone remembering to
 * update this file. The schema is parsed directly because Prisma 7's runtime
 * DMMF no longer carries `relationFromFields` or `relationOnDelete` - it keeps
 * only the relation name - so the FK column cannot be recovered from it.
 *
 * @module lib/catalog/preset-references
 */

const fs = require('fs');
const path = require('path');

const SCHEMA_PATH = path.join(__dirname, '..', '..', '..', 'prisma', 'schema.prisma');

/** `  lab_test  lab_test  @relation(fields: [lab_test_id], references: [id], onDelete: Cascade)` */
const RELATION_LINE = /^\s*\w+\s+(\w+)(\??)\s+@relation\(\s*fields:\s*\[\s*([\w,\s]+)\]\s*,\s*references:\s*\[\s*id\s*\]([^)]*)\)/;

let cachedReferrers = null;

/**
 * Parse every FK relation in the schema once.
 *
 * @returns {Map<string, {model: string, field: string, optional: boolean, onDelete: string|null}[]>}
 *   Target model name → referrers holding a foreign key to it
 */
const parseReferrers = () => {
  if (cachedReferrers) return cachedReferrers;

  const schema = fs.readFileSync(SCHEMA_PATH, 'utf8');
  const byTarget = new Map();

  let currentModel = null;
  for (const rawLine of schema.split(/\r?\n/)) {
    const line = rawLine.replace(/\/\/.*$/, '');

    const modelStart = line.match(/^model\s+(\w+)\s*\{/);
    if (modelStart) {
      currentModel = modelStart[1];
      continue;
    }
    if (/^\}/.test(line)) {
      currentModel = null;
      continue;
    }
    if (!currentModel) continue;

    const relation = line.match(RELATION_LINE);
    if (!relation) continue;

    const [, targetModel, optionalMark, fieldList, tail] = relation;
    const field = fieldList.split(',')[0].trim();
    if (!field) continue;

    const onDelete = (tail.match(/onDelete:\s*(\w+)/) || [])[1] || null;

    if (!byTarget.has(targetModel)) byTarget.set(targetModel, []);
    byTarget.get(targetModel).push({
      model: currentModel,
      field,
      optional: optionalMark === '?',
      onDelete,
    });
  }

  cachedReferrers = byTarget;
  return cachedReferrers;
};

/**
 * Every foreign key column pointing at one model's id.
 *
 * @param {string} definitionModel - e.g. 'lab_test'
 * @returns {{model: string, field: string, optional: boolean, onDelete: string|null}[]}
 */
const listDefinitionReferrers = (definitionModel) => {
  const found = parseReferrers().get(definitionModel) || [];
  return [...found].sort(
    (a, b) => a.model.localeCompare(b.model) || a.field.localeCompare(b.field)
  );
};

/**
 * Referrers split by what repointing them means.
 *
 * `adoption` is the domain's own facility offering table, which the backfill
 * rewrites deliberately. `cascading` rows are owned by the definition and are
 * carried with it. Everything else is operational history that must survive
 * untouched except for the id it points at.
 *
 * @param {string} definitionModel
 * @param {string|null} [adoptionModel]
 * @returns {{adoption: Object[], cascading: Object[], operational: Object[]}}
 */
const classifyReferrers = (definitionModel, adoptionModel = null) => {
  const all = listDefinitionReferrers(definitionModel);

  return {
    adoption: all.filter((entry) => entry.model === adoptionModel),
    cascading: all.filter(
      (entry) => entry.model !== adoptionModel && entry.onDelete === 'Cascade'
    ),
    operational: all.filter(
      (entry) => entry.model !== adoptionModel && entry.onDelete !== 'Cascade'
    ),
  };
};

/**
 * The key two definitions must share to be considered the same thing.
 *
 * `code` is authoritative when a row carries one - it is what a shared catalog
 * is keyed on clinically. Otherwise fall back to the normalised naming field,
 * which is how a duplicate created by hand in two tenants presents. Returns
 * null when neither is usable, so the caller leaves the row alone rather than
 * guessing.
 *
 * @param {Object} definition
 * @param {string} [nameField]
 * @returns {string|null}
 */
const buildDedupeKey = (definition = {}, nameField = 'name') => {
  const code = String(definition.code ?? '').trim().toLowerCase();
  if (code) return `code:${code}`;

  const name = String(definition[nameField] ?? '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
  return name ? `name:${name}` : null;
};

module.exports = {
  listDefinitionReferrers,
  classifyReferrers,
  buildDedupeKey,
};
