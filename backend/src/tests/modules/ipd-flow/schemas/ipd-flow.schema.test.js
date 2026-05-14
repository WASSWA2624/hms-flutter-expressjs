const {
  listIpdFlowsQuerySchema,
  admissionIdParamsSchema,
  resolveLegacyRouteParamsSchema,
  getIpdFlowQuerySchema,
  startIpdFlowSchema,
  assignBedSchema,
  requestTransferSchema,
  updateTransferSchema,
  planDischargeSchema,
  startIcuStaySchema,
  endIcuStaySchema,
  addIcuObservationSchema,
  addCriticalAlertSchema,
  resolveCriticalAlertSchema,
} = require('@validations/ipd-flow/ipd-flow.schema');

describe('ipd-flow.schema', () => {
  it('accepts list filters and parses boolean has_active_bed from query string', () => {
    const result = listIpdFlowsQuerySchema.safeParse({
      page: 1,
      limit: 20,
      tenant_id: 'TEN0000001',
      stage: 'ADMITTED_IN_BED',
      has_active_bed: 'true',
      search: 'john',
    });

    expect(result.success).toBe(true);
    expect(result.data.has_active_bed).toBe(true);
    expect(result.data.queue_scope).toBe('ACTIVE');
  });

  it('validates resolve-legacy route params', () => {
    const result = resolveLegacyRouteParamsSchema.safeParse({
      resource: 'critical-alerts',
      id: 'TRN0000001',
    });
    expect(result.success).toBe(true);
  });

  it('validates ICU-aware list filters', () => {
    const result = listIpdFlowsQuerySchema.safeParse({
      include_icu: 'true',
      icu_queue_scope: 'WITH_ICU',
      icu_status: 'ACTIVE',
      critical_severity: 'CRITICAL',
      has_critical_alert: 'true',
    });

    expect(result.success).toBe(true);
    expect(result.data.include_icu).toBe(true);
    expect(result.data.has_critical_alert).toBe(true);
  });

  it('validates get query include_icu flag', () => {
    const result = getIpdFlowQuerySchema.safeParse({ include_icu: 'true' });
    expect(result.success).toBe(true);
    expect(result.data.include_icu).toBe(true);
  });

  it('accepts UUID and HFID identifiers in admission params', () => {
    const byHfid = admissionIdParamsSchema.safeParse({ id: 'ADM0000123' });
    const byUuid = admissionIdParamsSchema.safeParse({
      id: '550e8400-e29b-41d4-a716-446655440000',
    });

    expect(byHfid.success).toBe(true);
    expect(byUuid.success).toBe(true);
  });

  it('requires destination bed for COMPLETE transfer action', () => {
    const result = updateTransferSchema.safeParse({ action: 'COMPLETE' });
    expect(result.success).toBe(false);
  });

  it('validates start payload with optional bed assignment', () => {
    const result = startIpdFlowSchema.safeParse({
      patient_id: 'PAT0000345',
      facility_id: 'FAC0000001',
      bed_id: 'BED0000012',
    });

    expect(result.success).toBe(true);
  });

  it('validates assign bed payload', () => {
    const result = assignBedSchema.safeParse({ bed_id: 'BED0000012' });
    expect(result.success).toBe(true);
  });

  it('validates transfer request payload', () => {
    const result = requestTransferSchema.safeParse({
      from_ward_id: 'WRD0000001',
      to_ward_id: 'WRD0000002',
    });
    expect(result.success).toBe(true);
  });

  it('validates discharge planning payload', () => {
    const result = planDischargeSchema.safeParse({ summary: 'Stable, continue oral meds.' });
    expect(result.success).toBe(true);
  });

  it('validates start ICU stay payload', () => {
    const result = startIcuStaySchema.safeParse({ started_at: '2026-01-01T10:00:00.000Z' });
    expect(result.success).toBe(true);
  });

  it('validates end ICU stay payload', () => {
    const result = endIcuStaySchema.safeParse({
      icu_stay_id: 'ICU0000001',
      ended_at: '2026-01-01T10:00:00.000Z',
    });
    expect(result.success).toBe(true);
  });

  it('validates add ICU observation payload', () => {
    const result = addIcuObservationSchema.safeParse({
      icu_stay_id: 'ICU0000001',
      observation: 'Stable oxygen saturation',
    });
    expect(result.success).toBe(true);
  });

  it('validates add critical alert payload', () => {
    const result = addCriticalAlertSchema.safeParse({
      icu_stay_id: 'ICU0000001',
      severity: 'HIGH',
      message: 'Escalating blood pressure trend',
    });
    expect(result.success).toBe(true);
  });

  it('validates resolve critical alert payload', () => {
    const result = resolveCriticalAlertSchema.safeParse({
      critical_alert_id: 'CAL0000001',
    });
    expect(result.success).toBe(true);
  });
});
