const subject = require('@routes/billing/billing.routes');

describe('billing.routes', () => {
  it('exports an express router with handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('registers workspace endpoints', () => {
    const routes = subject.stack.filter((layer) => layer.route);
    const hasWorkspace = routes.some((layer) => layer.route.path === '/workspace' && layer.route.methods.get);
    const hasWorkItems = routes.some((layer) => layer.route.path === '/work-items' && layer.route.methods.get);
    const hasLedger = routes.some((layer) => layer.route.path === '/patients/:patientIdentifier/ledger' && layer.route.methods.get);

    expect(hasWorkspace).toBe(true);
    expect(hasWorkItems).toBe(true);
    expect(hasLedger).toBe(true);
  });

  it('registers approval and document endpoints', () => {
    const routes = subject.stack.filter((layer) => layer.route);
    const hasApprove = routes.some((layer) => layer.route.path === '/approvals/:approvalIdentifier/approve' && layer.route.methods.post);
    const hasReject = routes.some((layer) => layer.route.path === '/approvals/:approvalIdentifier/reject' && layer.route.methods.post);
    const hasDocument = routes.some((layer) => layer.route.path === '/invoices/:invoiceIdentifier/document' && layer.route.methods.get);

    expect(hasApprove).toBe(true);
    expect(hasReject).toBe(true);
    expect(hasDocument).toBe(true);
  });
});
