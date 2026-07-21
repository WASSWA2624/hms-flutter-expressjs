"""Remove Branch seeding and catalog references."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(r"D:/coding/apps/flutter/hms/backend")


def patch_file(path: Path, transforms: list) -> None:
    text = path.read_text(encoding="utf-8")
    original = text
    for fn in transforms:
        text = fn(text)
    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        print("updated", path)


def main() -> None:
    catalog = ROOT / "scripts/seeders/seed-catalog.js"
    patch_file(
        catalog,
        [
            lambda t: t.replace(
                "      branch_allowance: { included_branches: 2 },\n", ""
            ),
            lambda t: t.replace("    branches: [],\n", ""),
            lambda t: t.replace("  'branch',\n", ""),
        ],
    )

    runtime = ROOT / "scripts/seeders/seed-runtime.js"
    patch_file(runtime, [lambda t: t.replace("  branch: 'BRN',\n", "")])

    org = ROOT / "scripts/seeders/seed-org-pack.js"
    text = org.read_text(encoding="utf-8")
    text = text.replace("    branches: {},\n", "")
    # Remove entire branch loop block
    text = re.sub(
        r"\n\s*for \(const branchDefinition of scenario\.branches \|\| \[\]\) \{.*?\n\s*\}\n",
        "\n",
        text,
        flags=re.S,
    )
    # Remove department branch assignment
    text = re.sub(
        r"\n\s*const branch = scenario\.branches\?.*?result\.branches\[.*?\];\n",
        "\n",
        text,
        flags=re.S,
    )
    text = text.replace("          branch_id: branch?.id || null,\n", "")
    org.write_text(text, encoding="utf-8", newline="\n")
    print("updated", org)

    verify = ROOT / "scripts/verify-demo-data.js"
    if verify.exists():
        v = verify.read_text(encoding="utf-8")
        v = re.sub(
            r"\n\s*if \(!basicPlan\?\.extension_json\?\.branch_allowance\?\.included_branches\) \{.*?\n\s*\}\n",
            "\n",
            v,
            flags=re.S,
        )
        verify.write_text(v, encoding="utf-8", newline="\n")
        print("updated", verify)

    matrix = ROOT / "src/lib/subscriptions/plan-module-matrix.js"
    patch_file(matrix, [lambda t: t.replace("        'branch',\n", "")])

    # openapi: drop branch_id property lines
    openapi = ROOT / "scripts/generate-openapi.js"
    if openapi.exists():
        o = openapi.read_text(encoding="utf-8")
        o2 = "\n".join(
            line
            for line in o.splitlines()
            if "branch_id" not in line and "/branches" not in line
        )
        if o2 != o:
            openapi.write_text(o2 + "\n", encoding="utf-8", newline="\n")
            print("updated", openapi)


if __name__ == "__main__":
    main()
