jest.mock('@prisma/client', () => ({
  report_definition: {
    count: jest.fn()},
  report_run: {
    count: jest.fn()},
  report_schedule: {
    count: jest.fn()},
  dashboard_widget: {
    count: jest.fn()},
  kpi_snapshot: {
    count: jest.fn()},
  analytics_event: {
    count: jest.fn()}}));

const prisma = require('@prisma/client');
const reportsWorkspaceRepository = require('@repositories/reports-workspace/reports-workspace.repository');

const countDelegates = [
  prisma.report_definition.count,
  prisma.report_run.count,
  prisma.report_schedule.count,
  prisma.dashboard_widget.count,
  prisma.kpi_snapshot.count,
  prisma.analytics_event.count];

describe('reports-workspace.repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    countDelegates.forEach((delegate) => delegate.mockResolvedValue(0));
  });

  it('does not apply unsupported facility or branch filters to dashboard widget summary queries', async () => {
    await reportsWorkspaceRepository.findSummary({
      tenant_id: 'tenant-internal-1',
      facility_id: 'facility-internal-1'});

    const widgetScopes = prisma.dashboard_widget.count.mock.calls.map(
      ([query]) => query.where
    );

    expect(widgetScopes).toHaveLength(2);
    widgetScopes.forEach((where) => {
      expect(where).toEqual(
        expect.objectContaining({
          deleted_at: null,
          tenant_id: 'tenant-internal-1'})
      );
      expect(where).not.toHaveProperty('facility_id');
    });

    expect(prisma.report_definition.count.mock.calls[0][0].where).toMatchObject({
      deleted_at: null,
      tenant_id: 'tenant-internal-1',
      facility_id: 'facility-internal-1'});
    expect(prisma.report_definition.count.mock.calls[0][0].where).not.toHaveProperty(
    );

    expect(prisma.kpi_snapshot.count.mock.calls[0][0].where).toMatchObject({
      deleted_at: null,
      tenant_id: 'tenant-internal-1',
      facility_id: 'facility-internal-1',
      threshold_state: 'CRITICAL'});
  });
});
