"""Final compliance audit against rule-file-standards.mdc."""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
files = sorted(f for f in root.rglob("*.mdc") if ".cursor" in f.parts)


def word_count(text: str) -> int:
    return len(re.findall(r"\S+", text))


def parse(c: str):
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", c, re.DOTALL)
    return (m.group(1), m.group(2)) if m else (None, c)


# Instructional weak forms in body (exclude alwaysApply frontmatter)
WEAK_INSTR = re.compile(
    r"(?i)(?:^|\s)(-\s*)?(Do not|Don't|Never |Avoid |Must avoid|Should avoid|"
    r"must never|Must never|, never |; never |\band never\b|\bis never\b)"
)

issues = []
ok = []
for f in files:
    rel = str(f.relative_to(root)).replace("\\", "/")
    content = f.read_text(encoding="utf-8")
    wc = word_count(content)
    fm, body = parse(content)
    probs = []

    if fm is None:
        probs.append("missing/invalid frontmatter")
    else:
        has_desc = bool(re.search(r"^description:\s*.+", fm, re.M))
        aa_true = bool(re.search(r"^alwaysApply:\s*true\s*$", fm, re.M))
        aa_false = bool(re.search(r"^alwaysApply:\s*false\s*$", fm, re.M))
        has_globs = bool(re.search(r"^globs:", fm, re.M))
        if not has_desc:
            probs.append("missing description")
        if not (aa_true or aa_false):
            probs.append("missing alwaysApply")
        if aa_true and has_globs:
            probs.append("globs with alwaysApply:true")
        if aa_false and not has_globs:
            probs.append("missing globs")
        # list-format globs
        if has_globs and aa_false:
            if not re.search(r"^globs:\s*$", fm, re.M) or not re.search(
                r"^\s+-\s+", fm, re.M
            ):
                # allow globs:\n  - 
                if not re.search(r"^globs:\n(\s+-\s+.+\n?)+", fm, re.M):
                    probs.append("globs not YAML list")

    if not re.search(r"^#\s+\S", body, re.M):
        probs.append("missing H1")
    h1 = re.search(r"^#\s+.+$", body, re.M)
    if h1:
        after = body[h1.end() :].lstrip()
        if after.startswith("##"):
            probs.append("missing purpose after H1")
    if not re.search(r"^##\s+\S", body, re.M):
        probs.append("missing H2")
    if wc > 251:
        probs.append(f"words {wc} > 251")

    for m in WEAK_INSTR.finditer(body):
        # skip section titles that are descriptive after fix
        line_start = body.rfind("\n", 0, m.start()) + 1
        line = body[line_start : body.find("\n", m.start())]
        probs.append(f"weak modal: {line.strip()[:90]}")

    if probs:
        issues.append((rel, wc, probs))
    else:
        ok.append((rel, wc))

print(f"Total: {len(files)}")
print(f"Compliant: {len(ok)}")
print(f"Non-compliant: {len(issues)}")
if issues:
    print("\n=== FAIL ===")
    for rel, wc, probs in issues:
        print(f"{rel} ({wc}w)")
        for p in probs:
            print(f"  - {p}")
