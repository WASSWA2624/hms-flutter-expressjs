from __future__ import annotations

import re
from pathlib import Path

REPO = Path(r"D:/coding/apps/flutter/hms")
TMP = REPO / "scripts" / "_tmp"
SRC = REPO / "backend" / "src"

repo = (TMP / "tf-repo.js").read_text(encoding="utf-8")
repo = re.sub(r"\s*prisma\.branch\.findMany\(\{.*?\}\),", "", repo, flags=re.S)
repo = repo.replace("const [branches, departments,", "const [departments,")
repo = re.sub(r"\n\s*branches,\n", "\n", repo)
repo = repo.replace("        branches: [],\n", "")
(
    SRC
    / "modules/tenant-facility-workspace/repositories/tenant-facility-workspace.repository.js"
).write_text(repo, encoding="utf-8", newline="\n")

sw = (TMP / "sw-repo.js").read_text(encoding="utf-8")
sw = re.sub(
    r"\s*countAndLatest\(\{\s*model: 'branch',.*?\}\)\.then\(\(value\) => \['branch', value\]\),",
    "",
    sw,
    flags=re.S,
)
(SRC / "modules/settings-workspace/repositories/settings-workspace.repository.js").write_text(
    sw, encoding="utf-8", newline="\n"
)

ss = (TMP / "sw-svc.js").read_text(encoding="utf-8")
ss = re.sub(
    r"\n\s*\{\s*\n\s*id: 'branch',.*?\n\s*mandatory: false,\n\s*\},",
    "",
    ss,
    flags=re.S,
)
(SRC / "modules/settings-workspace/services/settings-workspace.service.js").write_text(
    ss, encoding="utf-8", newline="\n"
)

dash = (TMP / "dash-summary.js").read_text(encoding="utf-8")
dash = re.sub(
    r"const resolveScope = async \(query = \{\}, user = \{\}, effectiveRole = null, repository = null\) => \{.*?\n\};\n",
    """const resolveScope = async (query = {}, user = {}, effectiveRole = null, repository = null) => {
  const userScope = {
    tenant_id: user.tenant_id || user.tenantId || null,
    facility_id: user.facility_id || user.facilityId || null,
  };

  if (effectiveRole === ROLES.SUPER_ADMIN) {
    const tenantId = query.tenant_id || userScope.tenant_id || null;
    const facilityId = query.facility_id || userScope.facility_id || null;

    if (!tenantId) {
      return {
        tenant_id: null,
        facility_id: null,
        platform: true,
      };
    }

    return {
      tenant_id: tenantId,
      facility_id: facilityId || null,
    };
  }

  if (!userScope.tenant_id) {
    throw new HttpError('errors.auth.scope_mismatch', 403);
  }

  return userScope;
};

""",
    dash,
    count=1,
    flags=re.S,
)
drop = re.compile(
    r"branch_id|branchId|branchFacility|resolveBranch|prisma\.branch|/branches",
    re.I,
)
out = []
for line in dash.splitlines(keepends=True):
    if drop.search(line) and "bank" not in line.lower():
        continue
    out.append(line)
(SRC / "lib/dashboard/summary.js").write_text("".join(out), encoding="utf-8", newline="\n")
print("aux fixed")
