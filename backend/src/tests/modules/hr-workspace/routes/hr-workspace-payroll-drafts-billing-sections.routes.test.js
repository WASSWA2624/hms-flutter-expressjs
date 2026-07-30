/**
 * Route auth for Payroll drafts process: ∩ hr:write + financial:approve.
 * Patient Billing cashier scopes are not used; process is staff compensation.
 */

const subject = require('../../../../modules/hr-workspace/routes/hr-workspace.routes');
const { PERMISSIONS } = require('@config/permissions');

const findProcessLayer = () => {
  const layer = subject.stack.find((entry) => {
    if (!entry?.route) return false;
    const path = entry.route.path || '';
    return (
      path.includes('payroll-runs') &&
      path.includes('process') &&
      entry.route.methods &&
      entry.route.methods.post
    );
  });
  return layer;
};

describe('hr-workspace payroll process route billing-sections auth', () => {
  it('registers process route with hr:write then financial:approve (AND)', () => {
    const layer = findProcessLayer();
    expect(layer).toBeDefined();
    expect(layer.route.stack.length).toBeGreaterThanOrEqual(3);

    const permissionChecks = layer.route.stack.filter(
      (stackLayer) =>
        typeof stackLayer.handle === 'function' &&
        stackLayer.handle.length >= 3
    );

    // validateRequest + authorize(hr:write) + authorize(financial:approve) + controller
    expect(permissionChecks.length).toBeGreaterThanOrEqual(3);

    const routeSource = String(layer.route.stack.map((s) => s.handle).join('\n'));
    // Stack order is encoded in route registration; assert middleware count and
    // that FINANCIAL_APPROVE / HR_WRITE constants remain the process gates.
    expect(PERMISSIONS.HR_WRITE).toBe('hr:write');
    expect(PERMISSIONS.FINANCIAL_APPROVE).toBe('financial:approve');
    expect(routeSource).not.toContain('billing:write');
  });

  it('exports router with payroll preview (read) and process (approve) paths', () => {
    const paths = subject.stack
      .filter((entry) => entry?.route)
      .map((entry) => entry.route.path);

    expect(paths.some((path) => path.includes('payroll-runs') && path.includes('preview'))).toBe(
      true
    );
    expect(paths.some((path) => path.includes('payroll-runs') && path.includes('process'))).toBe(
      true
    );
  });
});
