const { resolveLabState, isLabOrderComplete } = require('@services/opd-flow/opd-diagnostics-state');

const completedItem = (resultStatus = 'NORMAL') => ({
  deleted_at: null,
  status: 'COMPLETED',
  results: [{ deleted_at: null, status: resultStatus }],
});

const pendingItem = () => ({
  deleted_at: null,
  status: 'IN_PROCESS',
  results: [{ deleted_at: null, status: 'PENDING' }],
});

describe('opd-diagnostics-state resolveLabState', () => {
  it('returns RESULTS_READY when all active items are completed', () => {
    const state = resolveLabState([
      {
        status: 'COMPLETED',
        deleted_at: null,
        items: [completedItem('NORMAL'), completedItem('ABNORMAL')],
        samples: [{ deleted_at: null, status: 'RECEIVED' }],
      },
    ]);

    expect(state).toEqual({
      code: 'RESULTS_READY',
      pending: false,
      ready: true,
    });
  });

  it('ignores cancelled items when determining completion', () => {
    const state = resolveLabState([
      {
        status: 'IN_PROCESS',
        deleted_at: null,
        items: [
          completedItem('NORMAL'),
          {
            deleted_at: null,
            status: 'CANCELLED',
            results: [],
          },
        ],
        samples: [{ deleted_at: null, status: 'PENDING' }],
      },
    ]);

    expect(state).toEqual({
      code: 'RESULTS_READY',
      pending: false,
      ready: true,
    });
    expect(
      isLabOrderComplete({
        status: 'IN_PROCESS',
        items: [
          completedItem('NORMAL'),
          { deleted_at: null, status: 'CANCELLED', results: [] },
        ],
      })
    ).toBe(true);
  });

  it('treats released results as complete even when order status lags', () => {
    const state = resolveLabState([
      {
        status: 'IN_PROCESS',
        deleted_at: null,
        items: [completedItem('VERIFIED')],
        samples: [{ deleted_at: null, status: 'RECEIVED' }],
      },
    ]);

    expect(state.code).toBe('RESULTS_READY');
    expect(state.pending).toBe(false);
  });

  it('keeps lab pending while any active item still has pending results', () => {
    const state = resolveLabState([
      {
        status: 'IN_PROCESS',
        deleted_at: null,
        items: [completedItem('NORMAL'), pendingItem()],
        samples: [{ deleted_at: null, status: 'RECEIVED' }],
      },
    ]);

    expect(state).toEqual({
      code: 'IN_LAB',
      pending: true,
      ready: false,
    });
  });

  it('reports SAMPLE_PENDING when incomplete work still needs a sample', () => {
    const state = resolveLabState([
      {
        status: 'ORDERED',
        deleted_at: null,
        items: [
          {
            deleted_at: null,
            status: 'ORDERED',
            results: [],
          },
        ],
        samples: [{ deleted_at: null, status: 'PENDING' }],
      },
    ]);

    expect(state).toEqual({
      code: 'SAMPLE_PENDING',
      pending: true,
      ready: false,
    });
  });
});
