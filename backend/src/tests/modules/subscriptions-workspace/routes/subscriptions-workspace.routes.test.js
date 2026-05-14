jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: jest.fn(),
}));

const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const subject = require('../../../../modules/subscriptions-workspace/routes/subscriptions-workspace.routes');

describe('subscriptions-workspace.routes contract', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  it('exports an express router with registered handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('gates the router behind the subscriptions workspace feature flag', () => {
    const next = jest.fn();
    const middleware = subject.stack[0]?.handle;

    isFeatureEnabled.mockReturnValue(false);
    middleware({}, {}, next);

    expect(isFeatureEnabled).toHaveBeenCalledWith('subscriptions_workspace_v1');
    expect(next).toHaveBeenCalledWith(expect.any(HttpError));
    expect(next.mock.calls[0][0].statusCode).toBe(404);
  });

  it('allows the request through when the feature flag is enabled', () => {
    const next = jest.fn();
    const middleware = subject.stack[0]?.handle;

    isFeatureEnabled.mockReturnValue(true);
    middleware({}, {}, next);

    expect(next).toHaveBeenCalledWith();
  });
});
