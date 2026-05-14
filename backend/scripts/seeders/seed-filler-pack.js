const { CURATED_MODELS } = require('./seed-catalog');

const shouldSkipFieldForFiller = (field) =>
  field.isId ||
  field.isList ||
  field.kind === 'object' ||
  field.name.endsWith('_id');

const seedFillerPack = async (ctx, targetCount = 0) => {
  const parsedTarget = Number.parseInt(String(targetCount), 10);
  if (!Number.isFinite(parsedTarget) || parsedTarget <= 0) {
    return {
      skipped: true,
      reason: 'target_count_zero',
      created: 0,
      processed: 0,
    };
  }

  let created = 0;
  let processed = 0;

  for (const [modelName, meta] of ctx.schema.modelsByName.entries()) {
    if (CURATED_MODELS.has(modelName)) continue;

    const delegate = ctx.prisma[modelName];
    if (!delegate || typeof delegate.count !== 'function' || typeof delegate.upsert !== 'function') continue;

    const requiredFields = meta.fields.filter(
      (field) =>
        !shouldSkipFieldForFiller(field) &&
        !field.isOptional &&
        !field.hasDefault &&
        !field.isUpdatedAt
    );

    if (requiredFields.some((field) => field.name.endsWith('_id'))) continue;

    const currentCount = await delegate.count();
    if (currentCount >= parsedTarget) {
      processed += 1;
      continue;
    }

    const nextIndex = currentCount + 1;
    const payload = {};
    for (const field of requiredFields) {
      payload[field.name] = ctx.schema.enumValuesByName.get(field.type)?.[0] ??
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
      processed += 1;
    } catch (_error) {
      processed += 1;
    }
  }

  return {
    skipped: false,
    created,
    processed,
  };
};

module.exports = {
  seedFillerPack,
};
