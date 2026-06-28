import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1] / "lib" / "features"

fixes = {
    "billing/presentation/controllers/billing_workspace_controller.dart": (
        "    const BillingWorkspaceQuery query = BillingWorkspaceQuery();\n"
        "    final Result<BillingWorkspaceOverview> overviewResult = await _repository\n"
        "        .getWorkspace(query);\n\n"
        "    return overviewResult.when(",
        "    return runWorkspaceInitialLoad(ref, () async {\n"
        "      const BillingWorkspaceQuery query = BillingWorkspaceQuery();\n"
        "      final Result<BillingWorkspaceOverview> overviewResult = await _repository\n"
        "          .getWorkspace(query);\n\n"
        "      return overviewResult.when(",
        "    );\n    });",
        "    );",
    ),
    "physiotherapy/presentation/controllers/physiotherapy_workspace_controller.dart": (
        "    final Result<PhysiotherapyWorkspaceState> result =\n        await _loadInitialState();",
        "    final Result<PhysiotherapyWorkspaceState> result =\n        await runWorkspaceInitialLoad(ref, _loadInitialState);",
        None,
        None,
    ),
    "housekeeping/presentation/controllers/housekeeping_workspace_controller.dart": (
        "    const HousekeepingWorkspaceQuery query = HousekeepingWorkspaceQuery();\n"
        "    final Result<HousekeepingWorkspaceLoad> loadResult = await _repository\n"
        "        .getWorkspace(query);\n\n"
        "    return loadResult.when(",
        "    return runWorkspaceInitialLoad(ref, () async {\n"
        "      const HousekeepingWorkspaceQuery query = HousekeepingWorkspaceQuery();\n"
        "      final Result<HousekeepingWorkspaceLoad> loadResult = await _repository\n"
        "          .getWorkspace(query);\n\n"
        "      return loadResult.when(",
        "    );\n    });",
        "    );",
    ),
    "reports/presentation/controllers/reports_workspace_controller.dart": (
        "    const ReportsWorkspaceQuery query = ReportsWorkspaceQuery();\n"
        "    final Result<ReportsWorkspaceOverview> overviewResult =\n"
        "        await _loadReportingOverview(query);\n\n"
        "    return overviewResult.when(",
        "    return runWorkspaceInitialLoad(ref, () async {\n"
        "      const ReportsWorkspaceQuery query = ReportsWorkspaceQuery();\n"
        "      final Result<ReportsWorkspaceOverview> overviewResult =\n"
        "          await _loadReportingOverview(query);\n\n"
        "      return overviewResult.when(",
        "    );\n    });",
        "    );",
    ),
    "settings/presentation/controllers/settings_workspace_controller.dart": (
        "    return _load(const SettingsWorkspaceQuery());",
        "    return runWorkspaceInitialLoad(\n      ref,\n      () => _load(const SettingsWorkspaceQuery()),\n    );",
        None,
        None,
    ),
    "discharge/presentation/controllers/discharge_workspace_controller.dart": (
        "    return _loadWorkspace(query);",
        "    return runWorkspaceInitialLoad(ref, () => _loadWorkspace(query));",
        None,
        None,
    ),
    "integrations/presentation/controllers/integrations_workspace_controller.dart": (
        "    return _loadSnapshot(const IntegrationWorkspaceQuery());",
        "    return runWorkspaceInitialLoad(\n      ref,\n      () => _loadSnapshot(const IntegrationWorkspaceQuery()),\n    );",
        None,
        None,
    ),
    "rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart": (
        "    return _loadState(RoomsBedsQuery(facilityId: facilityId));",
        "    return runWorkspaceInitialLoad(\n      ref,\n      () => _loadState(RoomsBedsQuery(facilityId: facilityId)),\n    );",
        None,
        None,
    ),
}

for rel, spec in fixes.items():
    path = root / rel.replace("/", "\\") if False else root / Path(rel)
    from pathlib import Path
    path = root / Path(*rel.split("/"))
    text = path.read_text(encoding="utf-8")
    old, new, close_old, close_new = spec
    if old not in text:
        print("skip", rel)
        continue
    text = text.replace(old, new, 1)
    if close_old and close_new:
        # close the last failure branch in build()
        idx = text.find(new)
        segment = text[idx:]
        # replace last `    );` before next method with close pattern - fragile
        # use explicit close for billing-like
        if close_old in segment:
            segment = segment.replace(close_old, close_new, 1)
            text = text[:idx] + segment
    path.write_text(text, encoding="utf-8")
    print("fixed", rel)

# claims - wrap build
claims_path = root / "claims/presentation/controllers/claims_workspace_controller.dart"
claims = claims_path.read_text(encoding="utf-8")
if "runWorkspaceInitialLoad" not in claims:
    claims = claims.replace(
        "    const ClaimsQueueQuery query = ClaimsQueueQuery();\n"
        "    final Result<AppPage<ClaimsQueueItem>> queueResult = await _repository\n"
        "        .listQueue(query);\n\n"
        "    return queueResult.when(",
        "    return runWorkspaceInitialLoad(ref, () async {\n"
        "      const ClaimsQueueQuery query = ClaimsQueueQuery();\n"
        "      final Result<AppPage<ClaimsQueueItem>> queueResult = await _repository\n"
        "          .listQueue(query);\n\n"
        "      return queueResult.when(",
        1,
    )
    # find failure branch end in build - add closing
    claims = re.sub(
        r"(failure: \(AppFailure failure\) \{\n        return Result<ClaimsWorkspaceState>\.failure\(failure\);\n      \},\n    \);)\n  \}",
        r"\1\n    });\n  }",
        claims,
        count=1,
    )
    claims_path.write_text(claims, encoding="utf-8")
    print("fixed claims")
