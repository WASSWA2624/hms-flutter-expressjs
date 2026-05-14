const {
  sanitizeFriendlyIds,
  isUuidLike,
} = require('@lib/identifiers/sanitize-friendly-ids');

describe('sanitize-friendly-ids', () => {
  const uuidValue = '550e8400-e29b-41d4-a716-446655440000';

  it('detects UUID-like strings', () => {
    expect(isUuidLike(uuidValue)).toBe(true);
    expect(isUuidLike('TEN0000001')).toBe(false);
  });

  it('keeps UUID-like id fields unchanged for contract compatibility', () => {
    const payload = {
      id: uuidValue,
      human_friendly_id: 'ENC0000001',
      patient_id: uuidValue,
      patient: {
        id: 'c56a4180-65aa-42ec-a945-5fd21dec0538',
        human_friendly_id: 'PAT0000001',
      },
    };

    const sanitized = sanitizeFriendlyIds(payload);
    expect(sanitized.id).toBe(uuidValue);
    expect(sanitized.patient_id).toBe(uuidValue);
    expect(sanitized.patient.id).toBe('c56a4180-65aa-42ec-a945-5fd21dec0538');
  });

  it('keeps UUID-like values unchanged when no friendly identifier is available', () => {
    const payload = {
      id: uuidValue,
      provider_user_id: 'c56a4180-65aa-42ec-a945-5fd21dec0538',
      nested: {
        reference_id: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
      },
    };

    const sanitized = sanitizeFriendlyIds(payload);
    expect(sanitized.id).toBe(uuidValue);
    expect(sanitized.provider_user_id).toBe('c56a4180-65aa-42ec-a945-5fd21dec0538');
    expect(sanitized.nested.reference_id).toBe('6ba7b810-9dad-11d1-80b4-00c04fd430c8');
  });

  it('preserves Date values so JSON serialization remains stable', () => {
    const createdAt = new Date('2026-02-25T17:37:22.000Z');
    const payload = {
      id: uuidValue,
      human_friendly_id: 'USR0000002',
      created_at: createdAt,
      nested: {
        updated_at: createdAt,
      },
    };

    const sanitized = sanitizeFriendlyIds(payload);
    expect(sanitized.id).toBe(uuidValue);
    expect(sanitized.created_at).toBeInstanceOf(Date);
    expect(sanitized.nested.updated_at).toBeInstanceOf(Date);
  });
});
