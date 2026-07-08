const normalizeStatus = (value) => String(value || '').trim().toUpperCase();

const activeItems = (items) => (Array.isArray(items) ? items.filter((item) => !item?.deleted_at) : []);

const activeLabOrderItems = (order) =>
  activeItems(order?.items).filter((item) => normalizeStatus(item?.status) !== 'CANCELLED');

const isReleasedLabResult = (result) => {
  const status = normalizeStatus(result?.status);
  return Boolean(status) && status !== 'PENDING';
};

const isLabOrderItemComplete = (item) => {
  const status = normalizeStatus(item?.status);
  if (status === 'COMPLETED') return true;
  const results = activeItems(item?.results);
  return results.length > 0 && results.every((result) => isReleasedLabResult(result));
};

const isLabOrderComplete = (order) => {
  const items = activeLabOrderItems(order);
  if (!items.length) {
    return normalizeStatus(order?.status) === 'COMPLETED';
  }
  return items.every((item) => isLabOrderItemComplete(item));
};

const resolveLabState = (orders = []) => {
  const activeOrders = activeItems(orders).filter((order) => normalizeStatus(order.status) !== 'CANCELLED');
  if (!activeOrders.length) return { code: null, pending: false, ready: false };

  const incompleteOrders = activeOrders.filter((order) => !isLabOrderComplete(order));
  const hasIncomplete = incompleteOrders.length > 0;
  const hasPendingSample = incompleteOrders.some((order) =>
    activeItems(order.samples).some((sample) => ['PENDING', 'REJECTED'].includes(normalizeStatus(sample.status)))
  );
  const hasInLab = incompleteOrders.some((order) => {
    const orderStatus = normalizeStatus(order.status);
    if (['COLLECTED', 'IN_PROCESS'].includes(orderStatus)) return true;
    return activeLabOrderItems(order).some((item) => {
      if (isLabOrderItemComplete(item)) return false;
      return ['COLLECTED', 'IN_PROCESS'].includes(normalizeStatus(item.status));
    });
  });

  return {
    code: hasIncomplete ? (hasPendingSample ? 'SAMPLE_PENDING' : hasInLab ? 'IN_LAB' : 'LAB_PENDING') : 'RESULTS_READY',
    pending: hasIncomplete,
    ready: !hasIncomplete
  };
};

module.exports = {
  resolveLabState,
  isLabOrderComplete,
  isLabOrderItemComplete,
};
