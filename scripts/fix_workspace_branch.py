"""Rewrite critical files from origin/main snapshots without Branch."""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(r"D:/coding/apps/flutter/hms")
TMP = REPO / "scripts" / "_tmp"
SRC = REPO / "backend" / "src"


def strip_promise_branch_findmany(text: str) -> str:
    return re.sub(r"\s*prisma\.branch\.findMany\(\{.*?\}\),", "", text, flags=re.S)


def drop_branch_lines(text: str) -> str:
    drop = re.compile(
        r"branch_id|branchId|branchFacility|resolveBranch|model:\s*['\"]branch['\"]|"
        r"prisma\.branch|/branches|query\.branch|serializeBranch|hasBranches|"
        r"label_key: 'tenant_facility\.checklist\.branches'|id: 'branches'|"
        r"id: 'branch'|settings\.tabs\.branch|git-branch",
        re.I,
    )
    out = []
    for line in text.splitlines(keepends=True):
        if drop.search(line) and "bank" not in line.lower():
            continue
        out.append(line)
    return "".join(out)


def main() -> None:
    # repository
    repo = (TMP / "tf-repo.js").read_text(encoding="utf-8")
    repo = strip_promise_branch_findmany(repo)
    repo = repo.replace("const [branches, departments,", "const [departments,")
    repo = re.sub(r"\n\s*branches,\n", "\n", repo)
    repo = repo.replace(
        """      return {
        branches: [],
        departments: [],""",
        """      return {
        departments: [],""",
    )
    (SRC / "modules/tenant-facility-workspace/repositories/tenant-facility-workspace.repository.js").write_text(
        repo, encoding="utf-8", newline="\n"
    )

    # service
    svc = (TMP / "tf-svc.js").read_text(encoding="utf-8")
    svc = re.sub(
        r"\n\s*\{\s*\n\s*id: 'branches',.*?\n\s*\},",
        "",
        svc,
        flags=re.S,
    )
    svc = re.sub(r"\n\s*branches = \[\],", "", svc)
    svc = re.sub(r".*facilityRecords\.branches.*\n", "", svc)
    svc = re.sub(r".*serializeBranch.*\n", "", svc)
    svc = re.sub(r".*hasBranchesConfigured.*\n", "", svc)
    svc = re.sub(
        r"\n\s*branches: facilityRecords\.branches\.map\([\s\S]*?\),",
        "",
        svc,
    )
    # orphan map leftovers like lone `),` after removed branches: map
    svc = re.sub(
        r"contact_address: contactAddress,\n\s*\),?\n",
        "contact_address: contactAddress,\n",
        svc,
    )
    # cleanup dangling serializeBranch call fragments
    svc = re.sub(
        r"\n\s*branches:\s*\n\s*facilityRecords\.branches\.map\(\(entry\) =>\n\s*serializeBranch\(entry, serializeContext\)\n\s*\),",
        "",
        svc,
    )
    (SRC / "modules/tenant-facility-workspace/services/tenant-facility-workspace.service.js").write_text(
        svc, encoding="utf-8", newline="\n"
    )

    # settings repo
    sw_repo = (TMP / "sw-repo.js").read_text(encoding="utf-8")
    sw_repo = re.sub(
        r"\s*countAndLatest\(\{\s*model: 'branch',.*?\}\)\.then\(\(value\) => \['branch', value\]\),",
        "",
        sw_repo,
        flags=re.S,
    )
    (SRC / "modules/settings-workspace/repositories/settings-workspace.repository.js").write_text(
        sw_repo, encoding="utf-8", newline="\n"
    )

    # settings service
    sw_svc = (TMP / "sw-svc.js").read_text(encoding="utf-8")
    sw_svc = re.sub(
        r"\n\s*\{\s*\n\s*id: 'branch',.*?\n\s*mandatory: false,\n\s*\},",
        "",
        sw_svc,
        flags=re.S,
    )
    (SRC / "modules/settings-workspace/services/settings-workspace.service.js").write_text(
        sw_svc, encoding="utf-8", newline="\n"
    )

    # dashboard summary
    dash = (TMP / "dash-summary.js").read_text(encoding="utf-8")
    # rewrite resolveScope cleanly
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
    dash = drop_branch_lines(dash)
    (SRC / "lib/dashboard/summary.js").write_text(dash, encoding="utf-8", newline="\n")

    print("done")


if __name__ == "__main__":
    main()
