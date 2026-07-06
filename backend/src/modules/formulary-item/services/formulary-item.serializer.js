/**
 * Formulary item response serializer.
 *
 * @module modules/formulary-item/services/formulary-item.serializer
 */

const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');

const toText = (value) => (value == null ? '' : String(value).trim());

const toPublicIdentifier = (...candidates) => {
  for (const candidate of candidates) {
    const normalized = toText(candidate);
    if (!normalized) continue;
    if (isUuidLike(normalized)) continue;
    return normalized;
  }
  return null;
};

const toIsoDateTime = (value) => {
  if (!value) return null;
  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString();
};

const joinDrugDisplay = (name, strength, form) => {
  const parts = [name, strength, form].map(toText).filter(Boolean);
  return parts.length ? parts.join(' | ') : null;
};

const mapFormularyDrugRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const name = toText(record.name) || null;
  const strength = toText(record.strength) || null;
  const form = toText(record.form) || null;

  return {
    id: publicId,
    display_id: publicId,
    name,
    code: toText(record.code) || null,
    form,
    strength,
    drug_display_name: joinDrugDisplay(name, strength, form) || toText(record.code) || null,
  };
};

const mapFormularyItemRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  const drug = mapFormularyDrugRecord(record.drug);

  return {
    id: publicId,
    display_id: publicId,
    tenant_id: toPublicIdentifier(record.tenant?.human_friendly_id, record.tenant_id),
    drug_id: toPublicIdentifier(record.drug?.human_friendly_id, record.drug_id),
    drug_display_name: drug?.drug_display_name || null,
    drug_code: drug?.code || null,
    is_active: Boolean(record.is_active),
    drug,
    created_at: toIsoDateTime(record.created_at),
    updated_at: toIsoDateTime(record.updated_at),
  };
};

module.exports = {
  mapFormularyItemRecord,
  mapFormularyDrugRecord,
};
