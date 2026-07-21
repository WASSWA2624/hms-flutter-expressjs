"""Strip org-branch references from backend JS/JSON (not bank-branch / jest coverage)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(r"D:/coding/apps/flutter/hms/backend")

# Files/dirs to skip
SKIP_PARTS = {"node_modules", ".git", "uploads", "logs"}

BANK_SAFE = re.compile(
    r"bank[_ ]?branch|PLATFORM_BANK_BRANCH|subscriptionBankBranch|coverageThreshold|branches:\s*\{",
    re.I,
)


def should_skip(path: Path) -> bool:
    return any(p in SKIP_PARTS for p in path.parts)


def main() -> None:
    # Unregister router
    router = ROOT / "src" / "app" / "router.js"
    text = router.read_text(encoding="utf-8")
    text = re.sub(
        r"\n?apiV1Router\.use\('/branches', require\('\.\./modules/branch/routes/branch\.routes'\)\);\n?",
        "\n",
        text,
    )
    router.write_text(text, encoding="utf-8")
    print("updated router.js")

    # Count remaining references for report
    patterns = [
        r"\bbranch_id\b",
        r"\bbranchId\b",
        r"['\"]branch['\"]",
        r"/branches",
        r"modules/branch",
        r"model:\s*['\"]branch['\"]",
        r"softDeleteBranch",
        r"hasBranchesConfigured",
        r"branch_allowance",
        r"included_branches",
        r"restore_requires_active_branch",
        r"getFacilityBranches",
        r"listPublicBranches",
        r"\bBranch\b",
    ]
    combined = re.compile("|".join(f"({p})" for p in patterns))

    hits: list[tuple[str, int, str]] = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if should_skip(path):
            continue
        if path.suffix.lower() not in {".js", ".json", ".md", ".txt"}:
            continue
        if "prisma/migrations" in str(path).replace("\\", "/"):
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except Exception:
            continue
        for i, line in enumerate(content.splitlines(), 1):
            if BANK_SAFE.search(line):
                continue
            if "jest.config" in str(path) and "branches:" in line:
                continue
            if combined.search(line):
                hits.append((str(path.relative_to(ROOT)), i, line.strip()[:140]))

    out = ROOT.parent / "scripts" / "branch_backend_hits.txt"
    out.write_text(
        "\n".join(f"{p}:{n}: {line}" for p, n, line in hits),
        encoding="utf-8",
    )
    print(f"wrote {len(hits)} hits to {out}")


if __name__ == "__main__":
    main()
