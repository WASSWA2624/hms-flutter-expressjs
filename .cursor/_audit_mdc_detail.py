"""Inspect globs format and weak modal phrasing."""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
files = sorted(f for f in root.rglob("*.mdc") if ".cursor" in f.parts)


def parse(c: str):
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", c, re.DOTALL)
    return (m.group(1), m.group(2)) if m else (None, c)


print("=== GLOBS FORMAT ===")
for f in files:
    fm, _ = parse(f.read_text(encoding="utf-8"))
    if not fm:
        continue
    if "globs:" not in fm:
        aa = "true" if "alwaysApply: true" in fm else "false/missing"
        print(f"  no-globs ({aa}): {f.relative_to(root)}")
        continue
    lines = fm.splitlines()
    for i, ln in enumerate(lines):
        if ln.startswith("globs:"):
            block = [ln]
            for j in range(i + 1, len(lines)):
                if lines[j].startswith(" ") or lines[j].startswith("\t"):
                    block.append(lines[j])
                else:
                    break
            print(f"  {f.relative_to(root)}: {block}")
            break

print()
print("=== WEAK / NONSTANDARD MODALS ===")
pat = re.compile(
    r"(?i)\b(never|do not|don't|always|avoid|make sure|ensure that|need to|have to)\b"
)
for f in files:
    content = f.read_text(encoding="utf-8")
    hits = [
        (i + 1, ln.strip())
        for i, ln in enumerate(content.splitlines())
        if pat.search(ln)
    ]
    if hits:
        print(f"{f.relative_to(root)}")
        for n, ln in hits:
            print(f"  L{n}: {ln[:120]}")
        print()
