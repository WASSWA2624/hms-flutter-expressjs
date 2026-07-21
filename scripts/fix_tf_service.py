"""Apply precise Branch removals to tenant-facility-workspace.service.js from origin."""
from pathlib import Path

REPO = Path(r"D:/coding/apps/flutter/hms")
src = (REPO / "scripts/_tmp/tf-svc.js").read_text(encoding="utf-8")

src = src.replace("    facilityRecords.branches || [],\n", "")
src = src.replace(
    """
const serializeBranch = (record, context = null) => ({
  id: safePublicId(record.human_friendly_id, record.id),
  tenant_id: context
    ? resolveFk(record.tenant_id, context, 'tenant_id')
    : safePublicId(record.tenant_id),
  facility_id: context
    ? resolveFk(record.facility_id, context, 'facility_id')
    : safePublicId(record.facility_id),
  name: record.name,
  is_active: Boolean(record.is_active),
  deleted_at: record.deleted_at || null,
});
""",
    "\n",
)
src = src.replace(
    """  branch_id: context
    ? resolveFk(record.branch_id, context)
    : safePublicId(record.branch_id),
""",
    "",
)
src = src.replace("  branches = [],\n", "")
src = src.replace(
    "  const hasBranchesConfigured = branches.length > 0 || hasFacilityIdentity;\n",
    "",
)
src = src.replace(
    """    {
      id: 'branches',
      label_key: 'tenant_facility.checklist.branches',
      completed: hasBranchesConfigured,
      priority: 2,
    },
""",
    "",
)
src = src.replace(
    """    branches: facilityRecords.branches.map((entry) =>
      serializeBranch(entry, serializeContext)
    ),
""",
    "",
)
src = src.replace("      branches: facilityRecords.branches,\n", "")
# empty-state payload may include branches: []
src = src.replace("      branches: [],\n", "")

out = REPO / "backend/src/modules/tenant-facility-workspace/services/tenant-facility-workspace.service.js"
out.write_text(src, encoding="utf-8", newline="\n")
print("wrote", out)
