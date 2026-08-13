const { EventEmitter } = require('events');
const {
  createClientDisconnectSignal,
} = require('@lib/ai/client-disconnect-signal');

describe('createClientDisconnectSignal', () => {
  test('is not aborted after the request body has been consumed', () => {
    const req = { signal: AbortSignal.abort() };
    const res = new EventEmitter();
    res.writableEnded = false;

    const signal = createClientDisconnectSignal(req, res);

    expect(req.signal.aborted).toBe(true);
    expect(signal.aborted).toBe(false);
  });

  test('aborts when the client disconnects before the response is written', () => {
    const res = new EventEmitter();
    res.writableEnded = false;
    const signal = createClientDisconnectSignal({}, res);

    res.emit('close');

    expect(signal.aborted).toBe(true);
  });

  test('does not abort when the response finishes normally', () => {
    const res = new EventEmitter();
    res.writableEnded = true;
    const signal = createClientDisconnectSignal({}, res);

    res.emit('close');

    expect(signal.aborted).toBe(false);
  });
});
