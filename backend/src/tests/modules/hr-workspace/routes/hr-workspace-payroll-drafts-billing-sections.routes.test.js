/**
 * Route auth for Payroll drafts process: ∩ hr:write + financial:approve.
 * Patient Billing cashier scopes are not used; process is staff compensation.
 */

const fs = require('fs');
const path = require('path');
const subject = require('../../../../modules/hr-workspace/routes/hr-workspace.routes');
const { PERMISSIONS } = require('@config/permissions');

const routesSource = fs.readFileSync(
  path.join(
    __dirname,
    '../../../../modules/hr-workspace/routes/hr-workspace.routes.js'
  ),
  'utf8'
);

describe('hr-workspace payroll process route billing-sections auth', () => {
  it('chains authorize(hr:write) then authorize(financial:approve) on process', () => {
    expect(routesSource).toMatch(
      /payroll-runs\/:payrollRunIdentifier\/process[\s\S]*?authorize\(PAYROLL_PROCESS_WRITE_SCOPES[\s\S]*?authorize\(PAYROLL_PROCESS_APPROVE_SCOPES/
    );
    expect(routesSource).toMatch(
      /PAYROLL_PROCESS_WRITE_SCOPES\s*=\s*\[PERMISSIONS\.HR_WRITE\]/
    );
    expect(routesSource).toMatch(
      /PAYROLL_PROCESS_APPROVE_SCOPES\s*=\s*\[PERMISSIONS\.FINANCIAL_APPROVE\]/
    );
    expect(PERMISSIONS.HR_WRITE).toBe('hr:write');
    expect(PERMISSIONS.FINANCIAL_APPROVE).toBe('financial:approve');
    expect(routesSource).not.toMatch(
      /payroll-runs\/:payrollRunIdentifier\/process[\s\S]{0,400}billing:write/
    );
  });

  it('keeps preview on hr:read (no patient Billing write scopes)', () => {
    expect(routesSource).toMatch(
      /payroll-runs\/:payrollRunIdentifier\/preview[\s\S]*?authorize\(HR_READ_SCOPES/
    );
  });

  it('exports router with payroll preview and process paths', () => {
    const paths = subject.stack
      .filter((entry) => entry?.route)
      .map((entry) => entry.route.path);

    expect(
      paths.some((routePath) => routePath.includes('payroll-runs') && routePath.includes('preview'))
    ).toBe(true);
    expect(
      paths.some((routePath) => routePath.includes('payroll-runs') && routePath.includes('process'))
    ).toBe(true);
  });
});
