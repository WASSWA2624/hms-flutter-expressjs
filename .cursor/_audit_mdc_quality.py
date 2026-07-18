"""Deeper quality audit against rule-file-standards.mdc."""
import re
from pathlib import Path
from collections import Counter

root = Path(__file__).resolve().parent.parent
files = sorted(f for f in root.rglob("*.mdc") if ".cursor" in f.parts)

MODALS = re.compile(r"\b(must not|must|should not|should|may not|may)\b", re.I)
WEAK = re.compile(
    r"\b(always|never|don't|do not|can't|cannot|need to|needs to|have to|ensure that|make sure|try to|avoid)\b",
    re.I,
)


def parse_frontmatter(content: str):
    if not content.startswith("---"):
        return None, content
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", content, re.DOTALL)
    if not m:
        return None, content
    return m.group(1), m.group(2)


quality = []
for f in files:
    rel = str(f.relative_to(root)).replace("\\", "/")
    content = f.read_text(encoding="utf-8")
    fm, body = parse_frontmatter(content)
    notes = []

    # description checks
    desc_m = re.search(r"^description:\s*(.+)$", fm or "", re.M)
    if desc_m:
        desc = desc_m.group(1).strip()
        if desc.count(".") > 1:
            notes.append(f"description not single-sentence: {desc[:80]}")
        if len(desc.split()) > 25:
            notes.append(f"description long ({len(desc.split())} words)")

    # globs format - standards show list form
    if fm and re.search(r"^globs:", fm, re.M):
        # string form: globs: "foo" or globs: foo
        # list form: globs:\n  - "foo"
        if re.search(r"^globs:\s*[^\n\[\s]", fm, re.M) and not re.search(
            r"^globs:\s*$", fm, re.M
        ):
            # single-line globs value
            line = re.search(r"^globs:\s*(.+)$", fm, re.M)
            if line and not line.group(1).strip().startswith("["):
                notes.append(f"globs not list format: {line.group(1)[:60]}")

    # modal usage
    modals = MODALS.findall(body)
    weak = WEAK.findall(body)
    modal_count = len(modals)
    weak_count = len(weak)

    # actionable bullets: count imperative-ish vs prose paragraphs
    bullets = len(re.findall(r"^[\-\*]\s+", body, re.M))
    # long paragraphs (lines > 120 chars that aren't bullets/code)
    long_lines = [
        ln
        for ln in body.splitlines()
        if len(ln) > 140
        and not ln.strip().startswith(("-", "*", "#", "```", "|"))
    ]

    if weak_count > modal_count and weak_count >= 3:
        notes.append(f"prefer must/should/may over weak phrasing ({weak_count} weak vs {modal_count} modal)")
    if long_lines:
        notes.append(f"{len(long_lines)} long prose lines (>140 chars)")
    if bullets == 0 and len(body.split()) > 80:
        notes.append("no bullet lists (prefer concise bullets)")

    # sample weak phrases
    if notes:
        quality.append((rel, notes, Counter(w.lower() for w in weak), Counter(m.lower() for m in modals)))

print(f"Files with quality notes: {len(quality)} / {len(files)}")
print()
for rel, notes, weak_c, modal_c in quality:
    print(f"{rel}")
    for n in notes:
        print(f"  - {n}")
    if weak_c:
        print(f"  weak: {dict(weak_c)}")
    if modal_c:
        print(f"  modals: {dict(modal_c)}")
    print()
