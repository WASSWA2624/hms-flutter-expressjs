const { mapLabOrderRecord } = require('@services/lab-workspace/lab.serializer');

const buildOrderRecord = (encounter) => ({
  id: 'order-internal-1',
  human_friendly_id: 'LAB0000001',
  status: 'IN_PROCESS',
  ordered_at: new Date('2026-03-01T08:00:00.000Z'),
  created_at: new Date('2026-03-01T08:00:00.000Z'),
  updated_at: new Date('2026-03-01T08:00:00.000Z'),
  patient_id: 'patient-internal-1',
  encounter_id: encounter?.id || null,
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT0000001',
    first_name: 'Amina',
    last_name: 'Stone'},
  encounter,
  items: [],
  samples: []});

describe('lab.serializer encounter context', () => {
  it('maps an OPD encounter as an outpatient source without ward/bed', () => {
    const order = mapLabOrderRecord(
      buildOrderRecord({
        id: 'encounter-internal-1',
        human_friendly_id: 'ENC0000001',
        encounter_type: 'OPD',
        status: 'OPEN',
        provider_user_id: 'doctor-1',
        admissions: []})
    );

    expect(order.encounter_id).toBe('ENC0000001');
    expect(order.encounter_type).toBe('OPD');
    expect(order.encounter_source).toBe('OPD');
    expect(order.is_inpatient).toBe(false);
    expect(order.ward_name).toBeNull();
    expect(order.bed_label).toBeNull();
    expect(order.location_label).toBeNull();
    expect(order.encounter).toEqual(
      expect.objectContaining({
        id: 'ENC0000001',
        type: 'OPD',
        source: 'OPD',
        is_inpatient: false})
    );
  });

  it('maps an inpatient encounter with ward, room and bed location', () => {
    const order = mapLabOrderRecord(
      buildOrderRecord({
        id: 'encounter-internal-2',
        human_friendly_id: 'ENC0000002',
        encounter_type: 'INPATIENT',
        status: 'OPEN',
        provider_user_id: 'doctor-2',
        admissions: [
          {
            id: 'admission-internal-1',
            human_friendly_id: 'ADM0000001',
            status: 'ADMITTED',
            bed_assignments: [
              {
                id: 'assignment-internal-1',
                bed: {
                  id: 'bed-internal-1',
                  human_friendly_id: 'BED0000001',
                  label: 'Bed 4',
                  ward: { id: 'ward-1', name: 'Medical Ward' },
                  room: { id: 'room-1', name: 'Room 2' }}}]}]})
    );

    expect(order.encounter_source).toBe('IPD');
    expect(order.is_inpatient).toBe(true);
    expect(order.ward_name).toBe('Medical Ward');
    expect(order.bed_label).toBe('Bed 4');
    expect(order.location_label).toBe('Medical Ward · Room 2 · Bed 4');
    expect(order.encounter.admission_id).toBe('ADM0000001');
  });

  it('returns null encounter context when no encounter is linked', () => {
    const order = mapLabOrderRecord(buildOrderRecord(null));
    expect(order.encounter).toBeNull();
    expect(order.encounter_type).toBeNull();
    expect(order.is_inpatient).toBe(false);
  });
});
