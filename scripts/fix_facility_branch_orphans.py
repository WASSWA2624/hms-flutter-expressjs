"""Remove orphaned facility-branch leftovers that break Node syntax."""
from pathlib import Path

ROOT = Path(r"D:/coding/apps/flutter/hms/backend/src/modules/facility")

# --- routes: drop broken GET branches route ---
routes = (ROOT / "routes/facility.routes.js").read_text(encoding="utf-8")
marker = "\n/**\n * @description Get facility branches with pagination\n"
if marker in routes:
    head, _, rest = routes.partition(marker)
    # keep everything after module.exports if present after orphan
    export_idx = rest.find("\nmodule.exports = router;")
    if export_idx >= 0:
        routes = head.rstrip() + "\n\n" + rest[export_idx + 1 :]
    else:
        routes = head.rstrip() + "\n\nmodule.exports = router;\n"
    (ROOT / "routes/facility.routes.js").write_text(routes, encoding="utf-8", newline="\n")
    print("fixed routes")

# --- service: drop orphaned getFacilityBranches body ---
service = (ROOT / "services/facility.service.js").read_text(encoding="utf-8")
marker = "\n/**\n * Get facility branches with pagination\n"
if marker in service:
    head, _, rest = service.partition(marker)
    export_idx = rest.find("\nmodule.exports = {")
    if export_idx >= 0:
        # remove getFacilityBranches from exports if present
        exports = rest[export_idx + 1 :]
        exports = exports.replace("  getFacilityBranches,\n", "")
        service = head.rstrip() + "\n\n" + exports
    (ROOT / "services/facility.service.js").write_text(service, encoding="utf-8", newline="\n")
    print("fixed service")

# --- repository: drop findBranches/countBranches ---
repo = (ROOT / "repositories/facility.repository.js").read_text(encoding="utf-8")
marker = "\n/**\n * Find facility branches by facility ID\n"
if marker in repo:
    head, _, rest = repo.partition(marker)
    export_idx = rest.find("\nmodule.exports = {")
    if export_idx >= 0:
        exports = rest[export_idx + 1 :]
        exports = exports.replace("  findBranches,\n", "")
        exports = exports.replace("  countBranches,\n", "")
        repo = head.rstrip() + "\n\n" + exports
    (ROOT / "repositories/facility.repository.js").write_text(repo, encoding="utf-8", newline="\n")
    print("fixed repository")

print("done")
