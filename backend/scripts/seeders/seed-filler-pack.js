/**
 * Lightweight top-up for non-curated models that can be filled safely.
 *
 * Skips models with required foreign keys that cannot be satisfied from
 * provided anchors. Never invents orphan FK values.
 *
 * Loops until each eligible model reaches `targetCount` rows.
 */

const { CURATED_MODELS } = require('./seed-catalog');

/** Only fill models whose required FKs are in this allowlist (demo anchors). */
const SAFE_REQUIRED_FK_FIELDS = new Set([
  'tenant_id',
  'facility_id',
  'patient_id',
  'user_id',
  'inventory_item_id',
  'equipment_registry_id',
  'staff_profile_id',
]);

const shouldSkipFieldForFiller = (field) =>
  field.isId ||
  field.isList ||
  field.kind === 'object' ||
  field.name.endsWith('_id');

const requiredForeignKeys = (meta) =>
  meta.fields.filter(
    (field) =>
      field.kind === 'scalar' &&
      field.name.endsWith('_id') &&
      !field.isId &&
      !field.isOptional &&
      !field.hasDefault
  );

const pickAnchor = (anchors, fieldName, index) => {
  if (!anchors || typeof anchors !== 'object') return undefined;
  if (anchors[fieldName]) {
    const value = anchors[fieldName];
    if (Array.isArray(value)) {
      return value.length > 0 ? value[index % value.length] : undefined;
    }
    return value;
  }

  // Common plural aliases: patient_id <- patient_ids
  const plural = `${fieldName}s`;
  if (Array.isArray(anchors[plural]) && anchors[plural].length > 0) {
    return anchors[plural][index % anchors[plural].length];
  }

  return undefined;
};

const seedFillerPack = async (ctx, targetCount = 0, anchors = {}) => {
  const parsedTarget = Number.parseInt(String(targetCount), 10);
  if (!Number.isFinite(parsedTarget) || parsedTarget <= 0) {
    return {
      skipped: true,
      reason: 'target_count_zero',
      created: 0,
      processed: 0,
      skipped_models: 0,
    };
  }

  let created = 0;
  let processed = 0;
  let skippedModels = 0;
  const failures = [];

  for (const [modelName, meta] of ctx.schema.modelsByName.entries()) {
    if (CURATED_MODELS.has(modelName)) continue;

    const delegate = ctx.prisma[modelName];
    if (!delegate || typeof delegate.count !== 'function' || typeof delegate.upsert !== 'function') {
      continue;
    }

    const fkFields = requiredForeignKeys(meta);
    if (fkFields.some((field) => !SAFE_REQUIRED_FK_FIELDS.has(field.name))) {
      skippedModels += 1;
      continue;
    }
    // Skip models with unique constraints on FK columns (cannot volume-fill safely).
    if (fkFields.some((field) => field.isUnique)) {
      skippedModels += 1;
      continue;
    }
    const unresolvedFk = fkFields.find(
      (field) => pickAnchor(anchors, field.name, 0) === undefined
    );
    if (unresolvedFk) {
      skippedModels += 1;
      continue;
    }

    const requiredScalars = meta.fields.filter(
      (field) =>
        !shouldSkipFieldForFiller(field) &&
        !field.isOptional &&
        !field.hasDefault &&
        !field.isUpdatedAt
    );

    const currentCount = await delegate.count({
      where: meta.fieldByName.has('deleted_at') ? { deleted_at: null } : undefined,
    });
    if (currentCount >= parsedTarget) {
      processed += 1;
      continue;
    }

    for (let nextIndex = currentCount + 1; nextIndex <= parsedTarget; nextIndex += 1) {
      const payload = {};

      for (const field of fkFields) {
        payload[field.name] = pickAnchor(anchors, field.name, nextIndex);
      }

      // Optional ownership fields when present — keep filler tenant-scoped.
      for (const optionalFk of ['tenant_id', 'facility_id', 'patient_id', 'user_id']) {
        if (!meta.fieldByName.has(optionalFk)) continue;
        if (payload[optionalFk] !== undefined) continue;
        const value = pickAnchor(anchors, optionalFk, nextIndex);
        if (value !== undefined) payload[optionalFk] = value;
      }

      for (const field of requiredScalars) {
        payload[field.name] =
          ctx.schema.enumValuesByName.get(field.type)?.[0] ??
          (field.type === 'String'
            ? `${modelName}_${field.name}_${nextIndex}`
            : field.type === 'Boolean'
              ? false
              : field.type === 'DateTime'
                ? ctx.date(-nextIndex)
                : 0);
      }

      try {
        await ctx.upsert(modelName, `filler:${modelName}:${nextIndex}`, payload, {
          publicIdPrefix: modelName.slice(0, 4).toUpperCase(),
          seedMeta: false,
        });
        created += 1;
      } catch (error) {
        failures.push(`${modelName}#${nextIndex}:${error.message}`);
        // Stop hammering a model that cannot be filled safely.
        break;
      }
    }

    processed += 1;
  }

  if (failures.length > 0) {
    console.warn(
      `Filler pack skipped ${failures.length} failing upsert(s); first: ${failures[0]}`
    );
  }

  return {
    skipped: false,
    created,
    processed,
    skipped_models: skippedModels,
    failures: failures.length,
  };
};

module.exports = {
  seedFillerPack,
  requiredForeignKeys,
  pickAnchor,
};
