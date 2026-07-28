part of 'subscriptions_workspace_page.dart';

abstract final class _SubscriptionColumnIds {
  static const String plan = 'plan';
  static const String monthlyPrice = 'monthly_price';
  static const String annualPrice = 'annual_price';
  static const String tier = 'tier';
  static const String modules = 'modules';
  static const String planId = 'plan_id';
  static const String billingCycle = 'billing_cycle';
  static const String maxUsers = 'max_users';
  static const String maxFacilities = 'max_facilities';
  static const String maxStorage = 'max_storage';
  static const String maxModules = 'max_modules';
  static const String updatedAt = 'updated_at';
  static const String description = 'description';
  static const String tenant = 'tenant';
  static const String status = 'status';
  static const String amount = 'amount';
  static const String expiryDate = 'expiry_date';
  static const String subscriptionId = 'subscription_id';
  static const String fitStatus = 'fit_status';
  static const String startDate = 'start_date';
  static const String changeStatus = 'change_status';
  static const String tenantId = 'tenant_id';
  static const String module = 'module';
  static const String amountLimit = 'amount_limit';
  static const String renewalExpiry = 'renewal_expiry';
  static const String moduleId = 'module_id';
  static const String isAddOn = 'is_add_on';
  static const String recordId = 'record_id';
  static const String eligibility = 'eligibility';
  static const String invoice = 'invoice';
  static const String issuedAt = 'issued_at';
  static const String invoiceId = 'invoice_id';
  static const String billingStatus = 'billing_status';
  static const String dueDate = 'due_date';
  static const String paymentMethod = 'payment_method';
  static const String license = 'license';
  static const String expiresAt = 'expires_at';
  static const String licenseId = 'license_id';
  static const String endDate = 'end_date';
}

String _subscriptionResourceStorageKey(SubscriptionResource resource) {
  return resource.serverValue.replaceAll('-', '_');
}

List<AppListTableColumn<SubscriptionItem>> _subscriptionWorklistColumns(
  BuildContext context,
  SubscriptionResource resource,
) {
  return switch (resource) {
    SubscriptionResource.subscriptionPlans => _subscriptionPlanDefaultColumns(
      context,
    ),
    SubscriptionResource.subscriptions => _subscriptionDefaultColumns(context),
    SubscriptionResource.modules => _moduleDefaultColumns(context),
    SubscriptionResource.moduleSubscriptions =>
      _moduleSubscriptionDefaultColumns(context),
    SubscriptionResource.subscriptionInvoices =>
      _subscriptionInvoiceDefaultColumns(context),
    SubscriptionResource.licenses => _licenseDefaultColumns(context),
  };
}

List<AppListTableColumn<SubscriptionItem>> _subscriptionWorklistColumnChoices(
  BuildContext context,
  SubscriptionResource resource,
) {
  return switch (resource) {
    SubscriptionResource.subscriptionPlans => _subscriptionPlanOptionalColumns(
      context,
    ),
    SubscriptionResource.subscriptions => _subscriptionOptionalColumns(context),
    SubscriptionResource.modules => _moduleOptionalColumns(context),
    SubscriptionResource.moduleSubscriptions =>
      _moduleSubscriptionOptionalColumns(context),
    SubscriptionResource.subscriptionInvoices =>
      _subscriptionInvoiceOptionalColumns(context),
    SubscriptionResource.licenses => _licenseOptionalColumns(context),
  };
}

Widget _subscriptionStatusCell(SubscriptionItem item) {
  return AppWorkspaceStatusBadge(
    status: AppWorkspaceStatus(
      label: _statusLabel(item.primaryStatus),
      tone: _statusTone(item.primaryStatus),
      icon: _statusIcon(item.primaryStatus),
    ),
  );
}

String _modulesCountLabel(SubscriptionItem item) {
  final int? active = item.activeModuleCount;
  final int? max = item.maxModules;
  if (active != null && max != null) {
    return '$active / $max';
  }
  if (active != null) {
    return active.toString();
  }
  if (max != null) {
    return max.toString();
  }
  return _SubscriptionsText.notRecorded;
}

DateTime? _issuedAtDate(SubscriptionItem item) {
  return item.issuedAt ?? item.paidAt;
}

DateTime? _licenseExpiresAt(SubscriptionItem item) {
  return item.expiresAt ?? _timelineDate(item);
}

List<AppListTableColumn<SubscriptionItem>> _subscriptionPlanDefaultColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.plan,
      label: _SubscriptionsText.plan,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.name, right.name);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return AppListItemText(
          title: item.name ?? item.title,
          subtitle: item.code,
          titleStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.monthlyPrice,
      label: _SubscriptionsText.monthlyPriceUsd,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(
          left.resolvedMonthlyPrice,
          right.resolvedMonthlyPrice,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_money(context, item.resolvedMonthlyPrice, item.currency));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.annualPrice,
      label: _SubscriptionsText.annualPriceUsd,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(
          left.resolvedAnnualPrice,
          right.resolvedAnnualPrice,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_money(context, item.resolvedAnnualPrice, item.currency));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.tier,
      label: _SubscriptionsText.tier,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.tierCode, right.tierCode);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return _PlanBadge(
          label: _uniquePlanLabel(item),
          code: item.tierCode ?? item.code,
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.modules,
      label: _SubscriptionsText.modules,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(
          left.activeModuleCount,
          right.activeModuleCount,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_modulesCountLabel(item));
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _subscriptionPlanOptionalColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.planId,
      label: _SubscriptionsText.planId,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(
          left.effectiveDisplayId,
          right.effectiveDisplayId,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.effectiveDisplayId);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.billingCycle,
      label: _SubscriptionsText.billingCycle,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.billingCycle, right.billingCycle);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_statusLabel(item.billingCycle));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.maxUsers,
      label: _SubscriptionsText.maxUsers,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(left.maxUsers, right.maxUsers);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(
          item.maxUsers?.toString() ?? _SubscriptionsText.notRecorded,
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.maxFacilities,
      label: _SubscriptionsText.maxFacilities,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(
          left.maxFacilities,
          right.maxFacilities,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(
          item.maxFacilities?.toString() ?? _SubscriptionsText.notRecorded,
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.maxStorage,
      label: _SubscriptionsText.maxStorage,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(left.maxStorageMb, right.maxStorageMb);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(
          item.maxStorageMb?.toString() ?? _SubscriptionsText.notRecorded,
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.maxModules,
      label: _SubscriptionsText.maxModules,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(left.maxModules, right.maxModules);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(
          item.maxModules?.toString() ?? _SubscriptionsText.notRecorded,
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.updatedAt,
      label: _SubscriptionsText.updated,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(left.updatedAt, right.updatedAt);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, item.updatedAt));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.description,
      label: _SubscriptionsText.planDescription,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.description, right.description);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.description ?? _SubscriptionsText.notRecorded);
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _subscriptionDefaultColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.tenant,
      label: _SubscriptionsText.tenant,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.tenantLabel, right.tenantLabel);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return AppListItemText(
          title: item.tenantLabel ?? _SubscriptionsText.notRecorded,
          titleStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.plan,
      label: _SubscriptionsText.plan,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.planLabel, right.planLabel);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(
          item.planLabel ?? _SubscriptionsText.notRecorded,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.status,
      label: _SubscriptionsText.status,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.primaryStatus, right.primaryStatus);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return _subscriptionStatusCell(item);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.amount,
      label: _SubscriptionsText.amount,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(
          left.totalAmount ?? left.price,
          right.totalAmount ?? right.price,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(
          _money(context, item.totalAmount ?? item.price, item.currency),
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.expiryDate,
      label: _SubscriptionsText.expiryDate,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(
          _timelineDate(left),
          _timelineDate(right),
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, _timelineDate(item)));
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _subscriptionOptionalColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.subscriptionId,
      label: _SubscriptionsText.subscription,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(
          left.effectiveDisplayId,
          right.effectiveDisplayId,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.effectiveDisplayId);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.billingCycle,
      label: _SubscriptionsText.billingCycle,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.billingCycle, right.billingCycle);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_statusLabel(item.billingCycle));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.fitStatus,
      label: _SubscriptionsText.fitStatus,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.fitStatus, right.fitStatus);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_statusLabel(item.fitStatus));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.startDate,
      label: _SubscriptionsText.startDate,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(left.startDate, right.startDate);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, item.startDate));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.changeStatus,
      label: _SubscriptionsText.pendingChanges,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.changeStatus, right.changeStatus);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_statusLabel(item.changeStatus));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.tenantId,
      label: _SubscriptionsText.tenant,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.tenantId, right.tenantId);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.tenantId ?? _SubscriptionsText.notRecorded);
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _moduleDefaultColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.module,
      label: _SubscriptionsText.module,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.name, right.name);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return AppListItemText(
          title: item.name ?? item.title,
          subtitle: item.code,
          titleStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.status,
      label: _SubscriptionsText.status,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.primaryStatus, right.primaryStatus);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return _subscriptionStatusCell(item);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.tier,
      label: _SubscriptionsText.tier,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.tierCode, right.tierCode);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return _PlanBadge(
          label: _uniquePlanLabel(item),
          code: item.tierCode ?? item.code,
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.amountLimit,
      label: _SubscriptionsText.amountLimit,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(
          left.totalAmount ?? left.price,
          right.totalAmount ?? right.price,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_amountOrLimit(context, item));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.renewalExpiry,
      label: _SubscriptionsText.renewalExpiry,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(
          _timelineDate(left),
          _timelineDate(right),
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, _timelineDate(item)));
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _moduleOptionalColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.moduleId,
      label: _SubscriptionsText.module,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.moduleId, right.moduleId);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.moduleId ?? item.id);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.description,
      label: _SubscriptionsText.planDescription,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.description, right.description);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.description ?? _SubscriptionsText.notRecorded);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.isAddOn,
      label: _SubscriptionsText.addOn,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(
          left.isAddOn?.toString(),
          right.isAddOn?.toString(),
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(
          item.isAddOn == true
              ? _SubscriptionsText.enabled
              : _SubscriptionsText.notRecorded,
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.updatedAt,
      label: _SubscriptionsText.updated,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(left.updatedAt, right.updatedAt);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, item.updatedAt));
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _moduleSubscriptionDefaultColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.module,
      label: _SubscriptionsText.module,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.moduleLabel, right.moduleLabel);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return AppListItemText(
          title: item.moduleLabel ?? item.title,
          titleStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.tenant,
      label: _SubscriptionsText.tenant,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.tenantLabel, right.tenantLabel);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.tenantLabel ?? _SubscriptionsText.notRecorded);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.status,
      label: _SubscriptionsText.status,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.primaryStatus, right.primaryStatus);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return _subscriptionStatusCell(item);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.plan,
      label: _SubscriptionsText.plan,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.planLabel, right.planLabel);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.planLabel ?? _SubscriptionsText.notRecorded);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.expiryDate,
      label: _SubscriptionsText.expiryDate,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(
          _timelineDate(left),
          _timelineDate(right),
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, _timelineDate(item)));
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _moduleSubscriptionOptionalColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.recordId,
      label: _SubscriptionsText.record,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(
          left.effectiveDisplayId,
          right.effectiveDisplayId,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.effectiveDisplayId);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.fitStatus,
      label: _SubscriptionsText.fitStatus,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.fitStatus, right.fitStatus);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_statusLabel(item.fitStatus));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.eligibility,
      label: _SubscriptionsText.eligibility,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(
          left.entitlementDenialReason,
          right.entitlementDenialReason,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(
          item.entitlementDenialReason ?? _SubscriptionsText.notRecorded,
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.moduleId,
      label: _SubscriptionsText.module,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.moduleId, right.moduleId);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.moduleId ?? _SubscriptionsText.notRecorded);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.tenantId,
      label: _SubscriptionsText.tenant,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.tenantId, right.tenantId);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.tenantId ?? _SubscriptionsText.notRecorded);
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _subscriptionInvoiceDefaultColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.invoice,
      label: _SubscriptionsText.invoices,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(
          left.invoiceDisplayId,
          right.invoiceDisplayId,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return AppListItemText(
          title: item.invoiceDisplayId ?? _SubscriptionsText.notRecorded,
          titleStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.tenant,
      label: _SubscriptionsText.tenant,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.tenantLabel, right.tenantLabel);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.tenantLabel ?? _SubscriptionsText.notRecorded);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.status,
      label: _SubscriptionsText.status,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.primaryStatus, right.primaryStatus);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return _subscriptionStatusCell(item);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.amount,
      label: _SubscriptionsText.amount,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(
          left.totalAmount ?? left.price,
          right.totalAmount ?? right.price,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(
          _money(context, item.totalAmount ?? item.price, item.currency),
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.issuedAt,
      label: _SubscriptionsText.issuedAt,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(
          _issuedAtDate(left),
          _issuedAtDate(right),
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, _issuedAtDate(item)));
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _subscriptionInvoiceOptionalColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.invoiceId,
      label: _SubscriptionsText.invoices,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.invoiceId, right.invoiceId);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.invoiceId ?? _SubscriptionsText.notRecorded);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.billingStatus,
      label: _SubscriptionsText.invoiceStatus,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.billingStatus, right.billingStatus);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_statusLabel(item.billingStatus));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.dueDate,
      label: _SubscriptionsText.endDate,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(left.endDate, right.endDate);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, item.endDate));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.paymentMethod,
      label: _SubscriptionsText.paymentMethod,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(null, null);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return const Text(_SubscriptionsText.notRecorded);
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _licenseDefaultColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.license,
      label: _SubscriptionsText.licenseType,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.licenseType, right.licenseType);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return AppListItemText(
          title: item.licenseType ?? _SubscriptionsText.notRecorded,
          titleStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.tenant,
      label: _SubscriptionsText.tenant,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.tenantLabel, right.tenantLabel);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.tenantLabel ?? _SubscriptionsText.notRecorded);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.status,
      label: _SubscriptionsText.status,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(left.primaryStatus, right.primaryStatus);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return _subscriptionStatusCell(item);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.amount,
      label: _SubscriptionsText.amount,
      numeric: true,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareNumber(
          left.totalAmount ?? left.price,
          right.totalAmount ?? right.price,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(
          _money(context, item.totalAmount ?? item.price, item.currency),
        );
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.expiresAt,
      label: _SubscriptionsText.expiresAt,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(
          _licenseExpiresAt(left),
          _licenseExpiresAt(right),
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, _licenseExpiresAt(item)));
      },
    ),
  ];
}

List<AppListTableColumn<SubscriptionItem>> _licenseOptionalColumns(
  BuildContext context,
) {
  return <AppListTableColumn<SubscriptionItem>>[
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.licenseId,
      label: _SubscriptionsText.licenseType,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareText(
          left.effectiveDisplayId,
          right.effectiveDisplayId,
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(item.effectiveDisplayId);
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.issuedAt,
      label: _SubscriptionsText.issuedAt,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(
          _issuedAtDate(left),
          _issuedAtDate(right),
        );
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, _issuedAtDate(item)));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.startDate,
      label: _SubscriptionsText.startDate,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(left.startDate, right.startDate);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, item.startDate));
      },
    ),
    AppListTableColumn<SubscriptionItem>(
      id: _SubscriptionColumnIds.endDate,
      label: _SubscriptionsText.endDate,
      sortComparator: (SubscriptionItem left, SubscriptionItem right) {
        return appListTableCompareDateTime(left.endDate, right.endDate);
      },
      cellBuilder: (BuildContext context, SubscriptionItem item) {
        return Text(_date(context, item.endDate));
      },
    ),
  ];
}

bool _matchesSubscriptionTableSearch(
  BuildContext context,
  SubscriptionItem item,
  String query,
  SubscriptionResource resource,
) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  return _subscriptionSearchHaystack(context, item, resource).any((
    String value,
  ) {
    return value.toLowerCase().contains(normalized);
  });
}

List<String> _subscriptionSearchHaystack(
  BuildContext context,
  SubscriptionItem item,
  SubscriptionResource resource,
) {
  final List<String> values = <String>[];
  void add(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      values.add(trimmed);
    }
  }

  switch (resource) {
    case SubscriptionResource.subscriptionPlans:
      add(item.name ?? item.title);
      add(item.code);
      add(_money(context, item.resolvedMonthlyPrice, item.currency));
      add(_money(context, item.resolvedAnnualPrice, item.currency));
      add(_uniquePlanLabel(item));
      add(item.tierCode);
      add(_modulesCountLabel(item));
      add(item.effectiveDisplayId);
      add(_statusLabel(item.billingCycle));
      if (item.maxUsers != null) add(item.maxUsers.toString());
      if (item.maxFacilities != null) add(item.maxFacilities.toString());
      if (item.maxStorageMb != null) add(item.maxStorageMb.toString());
      if (item.maxModules != null) add(item.maxModules.toString());
      add(_date(context, item.updatedAt));
      add(item.description);
    case SubscriptionResource.subscriptions:
      add(item.tenantLabel);
      add(item.planLabel);
      add(_statusLabel(item.primaryStatus));
      add(_money(context, item.totalAmount ?? item.price, item.currency));
      add(_date(context, _timelineDate(item)));
      add(item.effectiveDisplayId);
      add(_statusLabel(item.billingCycle));
      add(_statusLabel(item.fitStatus));
      add(_date(context, item.startDate));
      add(_statusLabel(item.changeStatus));
      add(item.tenantId);
    case SubscriptionResource.modules:
      add(item.name ?? item.title);
      add(item.code);
      add(_statusLabel(item.primaryStatus));
      add(_uniquePlanLabel(item));
      add(item.tierCode);
      add(_amountOrLimit(context, item));
      add(_date(context, _timelineDate(item)));
      add(item.moduleId ?? item.id);
      add(item.description);
      add(_date(context, item.updatedAt));
    case SubscriptionResource.moduleSubscriptions:
      add(item.moduleLabel ?? item.title);
      add(item.tenantLabel);
      add(_statusLabel(item.primaryStatus));
      add(item.planLabel);
      add(_date(context, _timelineDate(item)));
      add(item.effectiveDisplayId);
      add(_statusLabel(item.fitStatus));
      add(item.entitlementDenialReason);
      add(item.moduleId);
      add(item.tenantId);
    case SubscriptionResource.subscriptionInvoices:
      add(item.invoiceDisplayId);
      add(item.tenantLabel);
      add(_statusLabel(item.primaryStatus));
      add(_money(context, item.totalAmount ?? item.price, item.currency));
      add(_date(context, _issuedAtDate(item)));
      add(item.invoiceId);
      add(_statusLabel(item.billingStatus));
      add(_date(context, item.endDate));
    case SubscriptionResource.licenses:
      add(item.licenseType);
      add(item.tenantLabel);
      add(_statusLabel(item.primaryStatus));
      add(_money(context, item.totalAmount ?? item.price, item.currency));
      add(_date(context, _licenseExpiresAt(item)));
      add(item.effectiveDisplayId);
      add(_date(context, _issuedAtDate(item)));
      add(_date(context, item.startDate));
      add(_date(context, item.endDate));
  }

  return values;
}
