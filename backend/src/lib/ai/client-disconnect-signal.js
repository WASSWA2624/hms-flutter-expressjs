/**
 * Client-disconnect AbortSignal
 *
 * Node.js IncomingMessage.signal aborts when the request body is consumed,
 * which happens before the controller runs. Passing `req.signal` into
 * outbound fetch therefore cancels every AI task immediately.
 *
 * This signal aborts only when the HTTP client disconnects before the
 * response is written.
 */

const createClientDisconnectSignal = (req, res) => {
  const controller = new AbortController();
  if (!res || typeof res.on !== 'function') {
    return controller.signal;
  }

  const onClose = () => {
    if (!res.writableEnded && !controller.signal.aborted) {
      controller.abort();
    }
  };

  res.on('close', onClose);
  return controller.signal;
};

module.exports = {
  createClientDisconnectSignal,
};
