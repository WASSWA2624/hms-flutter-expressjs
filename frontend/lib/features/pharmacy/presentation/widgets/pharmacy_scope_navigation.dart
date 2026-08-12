import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

String pharmacySectionToQueryValue(PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.queue => 'queue',
    PharmacyDeskSection.inProgress => 'in-progress',
    PharmacyDeskSection.pendingPayment => 'pending-payment',
    PharmacyDeskSection.completed => 'completed',
    PharmacyDeskSection.cancelled => 'cancelled',
    PharmacyDeskSection.allOrders => 'all',
    PharmacyDeskSection.catalog => 'catalog',
    PharmacyDeskSection.suppliers => 'suppliers',
    PharmacyDeskSection.nearExpiry => 'near-expiry',
    PharmacyDeskSection.expired => 'expired',
    PharmacyDeskSection.lowStock => 'low-stock',
    PharmacyDeskSection.outOfStock => 'out-of-stock',
  };
}

PharmacyDeskSection? pharmacySectionFromQuery(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'queue':
    case 'ready':
    case 'new':
    case 'new-orders':
    case 'dispense':
      return PharmacyDeskSection.queue;
    case 'in-progress':
    case 'partial':
    case 'in_progress':
      return PharmacyDeskSection.inProgress;
    case 'pending-payment':
    case 'payment':
    case 'pending_payment':
      return PharmacyDeskSection.pendingPayment;
    case 'completed':
    case 'dispensed':
      return PharmacyDeskSection.completed;
    case 'cancelled':
    case 'canceled':
      return PharmacyDeskSection.cancelled;
    case 'all':
    case 'all-orders':
      return PharmacyDeskSection.allOrders;
    case 'catalog':
    case 'catalog-and-stock':
    case 'inventory':
    case 'stock':
      return PharmacyDeskSection.catalog;
    case 'suppliers':
    case 'supplier':
      return PharmacyDeskSection.suppliers;
    case 'near-expiry':
    case 'expiring':
    case 'expiring-soon':
      return PharmacyDeskSection.nearExpiry;
    case 'expired':
      return PharmacyDeskSection.expired;
    case 'low-stock':
    case 'low':
      return PharmacyDeskSection.lowStock;
    case 'out-of-stock':
    case 'out':
      return PharmacyDeskSection.outOfStock;
    default:
      return null;
  }
}

/// Sibling-count model: dedicated unfiltered workspace summary / stock totals.
/// Active order tab uses filtered [PharmacyWorkbench.orders.totalItemCount].
/// Active stock-alert tab uses filtered inventory [AppPage.totalItemCount].
int pharmacySectionTabCount(
  PharmacyWorkspaceState state,
  PharmacyDeskSection section, {
  PharmacyDeskSection? activeSection,
}) {
  if (activeSection == section && section.isOrderSection) {
    final int? listTotal = state.workbench.orders.totalItemCount;
    if (listTotal != null) {
      return listTotal;
    }
  }
  if (activeSection == section && section.isStockSection) {
    final int? listTotal =
        state.inventoryWorkbench.stocks.totalItemCount;
    if (listTotal != null) {
      return listTotal;
    }
  }

  final PharmacyWorkbenchSummary summary = state.workbench.summary;
  final PharmacyInventoryStockSummary stock = state.stockAlertSummary;
  return switch (section) {
    PharmacyDeskSection.queue => summary.orderedQueue,
    PharmacyDeskSection.inProgress => summary.partiallyDispensedQueue,
    PharmacyDeskSection.pendingPayment => summary.pendingPaymentQueue,
    PharmacyDeskSection.completed => summary.dispensedOrders,
    PharmacyDeskSection.cancelled => summary.cancelledOrders,
    PharmacyDeskSection.allOrders => summary.totalOrders,
    // Catalog is a management hub, not a counted worklist.
    PharmacyDeskSection.catalog => 0,
    PharmacyDeskSection.suppliers => state.suppliers.totalItemCount ?? 0,
    PharmacyDeskSection.nearExpiry => stock.expiringSoonRows,
    PharmacyDeskSection.expired => stock.expiredRows,
    PharmacyDeskSection.lowStock => stock.lowStockRows,
    PharmacyDeskSection.outOfStock => stock.outOfStockRows,
  };
}

AppTabCountTone pharmacySectionCountTone(PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.queue ||
    PharmacyDeskSection.inProgress ||
    PharmacyDeskSection.pendingPayment ||
    PharmacyDeskSection.nearExpiry ||
    PharmacyDeskSection.lowStock => AppTabCountTone.warning,
    PharmacyDeskSection.cancelled ||
    PharmacyDeskSection.expired ||
    PharmacyDeskSection.outOfStock => AppTabCountTone.danger,
    PharmacyDeskSection.completed ||
    PharmacyDeskSection.catalog ||
    PharmacyDeskSection.suppliers ||
    PharmacyDeskSection.allOrders => AppTabCountTone.info,
  };
}

IconData pharmacySectionIcon(PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.queue => Icons.medication_liquid_outlined,
    PharmacyDeskSection.inProgress => Icons.pending_actions_outlined,
    PharmacyDeskSection.pendingPayment => Icons.payments_outlined,
    PharmacyDeskSection.completed => Icons.done_all_outlined,
    PharmacyDeskSection.cancelled => Icons.cancel_outlined,
    PharmacyDeskSection.allOrders => Icons.receipt_long_outlined,
    PharmacyDeskSection.catalog => Icons.inventory_2_outlined,
    PharmacyDeskSection.suppliers => Icons.local_shipping_outlined,
    PharmacyDeskSection.nearExpiry => Icons.hourglass_bottom_outlined,
    PharmacyDeskSection.expired => Icons.event_busy_outlined,
    PharmacyDeskSection.lowStock => Icons.trending_down_outlined,
    PharmacyDeskSection.outOfStock => Icons.remove_shopping_cart_outlined,
  };
}

String pharmacySectionLabel(
  AppLocalizations l10n,
  PharmacyDeskSection section,
) {
  return switch (section) {
    PharmacyDeskSection.queue => l10n.pharmacyDeskNewOrdersLabel,
    PharmacyDeskSection.inProgress => l10n.pharmacySummaryPartialLabel,
    PharmacyDeskSection.pendingPayment => l10n.pharmacyFilterPendingPayment,
    PharmacyDeskSection.completed => l10n.pharmacyDeskCompletedOrdersLabel,
    PharmacyDeskSection.cancelled => l10n.pharmacyDeskCancelledOrdersLabel,
    PharmacyDeskSection.allOrders => l10n.pharmacyFilterAll,
    PharmacyDeskSection.catalog => l10n.pharmacyDeskCatalogLabel,
    PharmacyDeskSection.suppliers => l10n.pharmacyDeskSuppliersLabel,
    PharmacyDeskSection.nearExpiry => l10n.pharmacyDeskNearExpiryLabel,
    PharmacyDeskSection.expired => l10n.pharmacyDeskExpiredLabel,
    PharmacyDeskSection.lowStock => l10n.pharmacyDeskLowStockLabel,
    PharmacyDeskSection.outOfStock => l10n.pharmacyDeskOutOfStockLabel,
  };
}

List<AppTabItem> pharmacyTabItems(
  AppLocalizations l10n,
  PharmacyWorkspaceState state, {
  AppAccessPolicy? policy,
  PharmacyDeskSection? activeSection,
}) {
  final Iterable<PharmacyDeskSection> sections = policy == null
      ? PharmacyDeskSection.values
      : pharmacyAllowedSections(policy);
  return <AppTabItem>[
    for (final PharmacyDeskSection section in sections)
      AppTabItem(
        id: section.name,
        icon: pharmacySectionIcon(section),
        label: pharmacySectionLabel(l10n, section),
        count: section.isCatalogSection
            ? null
            : pharmacySectionTabCount(
                state,
                section,
                activeSection: activeSection,
              ),
        countTone: pharmacySectionCountTone(section),
      ),
  ];
}
