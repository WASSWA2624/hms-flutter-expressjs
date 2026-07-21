"""Cut Branch functions correctly (skip `{}` in default params)."""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

REPO = Path(r"D:/coding/apps/flutter/hms")
GOOD = "f38e2ab4"


def get(rel: str) -> str:
    return subprocess.check_output(["git", "show", f"{GOOD}:{rel}"], cwd=REPO).decode(
        "utf-8"
    )


def find_body_brace(text: str, from_idx: int) -> int:
    """Find the opening `{` of a function body after `=>` or `) {` / `asyncHandler(`."""
    # Prefer arrow function body: => {
    arrow = text.find("=>", from_idx)
    # Also handle asyncHandler(async (req, res) => {
    # Find the last => before the first top-level body that isn't in params.
    # Simpler: scan for `=> {` or `) {` after const assignment.
    m = re.search(r"=>\s*\{|\)\s*\{", text[from_idx : from_idx + 400])
    if not m:
        raise RuntimeError("no function body brace")
    return from_idx + m.end() - 1  # index of '{'


def cut_function(text: str, name: str) -> str:
    m = re.search(rf"^const\s+{name}\s*=", text, re.M)
    if not m:
        print("  missing", name)
        return text
    start = m.start()
    before = text[:start]
    doc = before.rfind("\n/**\n")
    if doc >= 0:
        between = before[doc + 1 :]
        if between.strip().startswith("/**") and re.search(r"\nconst\s+", between) is None:
            start = doc + 1

    brace = find_body_brace(text, m.end())
    depth = 0
    i = brace
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                if end < len(text) and text[end] == ";":
                    end += 1
                while end < len(text) and text[end] in "\r\n":
                    end += 1
                return text[:start] + text[end:]
        i += 1
    raise RuntimeError(f"unbalanced {name}")


def cut_route_block(text: str, marker: str) -> str:
    idx = text.find(marker)
    if idx < 0:
        return text
    doc = text.rfind("\n/**", 0, idx)
    start = doc + 1 if doc >= 0 else idx
    g = text.find("router.get(", idx)
    if g < 0:
        return text
    depth = 0
    i = g + len("router.get")
    while i < len(text):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                end = i + 1
                if end < len(text) and text[end] == ";":
                    end += 1
                while end < len(text) and text[end] in "\r\n":
                    end += 1
                return text[:start] + text[end:]
        i += 1
    return text


def write(rel: str, text: str) -> None:
    for name in [
        "listPublicBranches",
        "getFacilityBranches",
        "findBranches",
        "countBranches",
    ]:
        text = re.sub(rf",?\n\s*{name},?\n", "\n", text)
    # trailing commas before }
    text = re.sub(r",(\s*})", r"\1", text)
    path = REPO / rel
    path.write_text(text, encoding="utf-8", newline="\n")
    r = subprocess.run(["node", "--check", str(path)], capture_output=True, text=True)
    print(("ok" if r.returncode == 0 else "BAD"), rel)
    if r.returncode != 0:
        print((r.stderr or "").splitlines()[:4])


def main() -> None:
    jobs = [
        (
            "backend/src/modules/public/controllers/public.controller.js",
            ["listPublicBranches"],
        ),
        (
            "backend/src/modules/public/services/public.service.js",
            ["listPublicBranches"],
        ),
        (
            "backend/src/modules/public/repositories/public.repository.js",
            ["listPublicBranches"],
        ),
        (
            "backend/src/modules/facility/controllers/facility.controller.js",
            ["getFacilityBranches"],
        ),
        (
            "backend/src/modules/facility/services/facility.service.js",
            ["getFacilityBranches"],
        ),
        (
            "backend/src/modules/facility/repositories/facility.repository.js",
            ["findBranches", "countBranches"],
        ),
    ]
    for rel, names in jobs:
        t = get(rel)
        for name in names:
            t = cut_function(t, name)
        write(rel, t)

    t = get("backend/src/modules/facility/routes/facility.routes.js")
    t = cut_route_block(t, "Get facility branches")
    write("backend/src/modules/facility/routes/facility.routes.js", t)

    # For the two repos that need prisma.branch removal: restore good, remove only complete findMany blocks
    for rel in [
        "backend/src/modules/reports-workspace/repositories/reports-workspace.repository.js",
        "backend/src/modules/dashboard-workspace/repositories/dashboard-workspace.repository.js",
    ]:
        t = get(rel)
        t = re.sub(
            r",?\s*prisma\.branch\.findMany\(\{(?:[^{}]|\{[^{}]*\})*\}\)",
            "",
            t,
        )
        t = re.sub(r"\n\s*branch_id:[^\n]+\n", "\n", t)
        t = re.sub(
            r"\n\s*if \([^\n]*\bbranch_id\b[^\n]*\) \{\n(?:[^\n]*\n)*?\s*\}\n",
            "\n",
            t,
        )
        # remove branches from destructuring: const [branches, x] -> const [x]
        t = re.sub(r"const \[branches,\s*", "const [", t)
        t = re.sub(r"\n\s*branches,\n", "\n", t)
        t = re.sub(r"\n\s*branches:\s*[^\n]+\n", "\n", t)
        write(rel, t)


if __name__ == "__main__":
    main()
