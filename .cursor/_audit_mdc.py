"""Audit .cursor/*.mdc files against rule-file-standards.mdc."""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
files = sorted(
    f for f in root.rglob("*.mdc") if ".cursor" in f.parts
)


def word_count(text: str) -> int:
    return len(re.findall(r"\S+", text))


def parse_frontmatter(content: str):
    if not content.startswith("---"):
        return None, content
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", content, re.DOTALL)
    if not m:
        return None, content
    return m.group(1), m.group(2)


issues = []
compliant = []

for f in files:
    rel = str(f.relative_to(root)).replace("\\", "/")
    content = f.read_text(encoding="utf-8")
    wc = word_count(content)
    fm, body = parse_frontmatter(content)
    probs = []

    if fm is None:
        probs.append("missing/invalid frontmatter")
    else:
        has_desc = bool(re.search(r"^description:\s*.+", fm, re.M))
        has_aa = bool(re.search(r"^alwaysApply:\s*(true|false)\s*$", fm, re.M))
        aa_true = bool(re.search(r"^alwaysApply:\s*true\s*$", fm, re.M))
        aa_false = bool(re.search(r"^alwaysApply:\s*false\s*$", fm, re.M))
        has_globs = bool(re.search(r"^globs:", fm, re.M))
        if not has_desc:
            probs.append("missing description")
        if not has_aa:
            probs.append("missing alwaysApply")
        if aa_true and has_globs:
            probs.append("globs present with alwaysApply:true (should omit)")
        if aa_false and not has_globs:
            probs.append("missing globs with alwaysApply:false")

    if not re.search(r"^#\s+\S", body, re.M):
        probs.append("missing H1")

    h1 = re.search(r"^#\s+.+$", body, re.M)
    if h1:
        after = body[h1.end() :].lstrip()
        if after.startswith("##"):
            probs.append("missing purpose statement after H1")
        elif not after:
            probs.append("empty body after H1")

    if not re.search(r"^##\s+\S", body, re.M):
        probs.append("missing H2 sections")

    if wc > 251:
        probs.append(f"word count {wc} > 251")

    if probs:
        issues.append((rel, wc, probs))
    else:
        compliant.append((rel, wc))

print(f"Total: {len(files)}")
print(f"Compliant: {len(compliant)}")
print(f"Non-compliant: {len(issues)}")
print()
print("=== COMPLIANT ===")
for rel, wc in compliant:
    print(f"  OK ({wc}w) {rel}")
print()
print("=== NON-COMPLIANT ===")
for rel, wc, probs in issues:
    print(f"  FAIL ({wc}w) {rel}")
    for p in probs:
        print(f"    - {p}")
