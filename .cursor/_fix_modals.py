"""Normalize modal verbs in .cursor/*.mdc files for rule-file-standards compliance.

Transforms instructional weak forms to must/must not/should/may.
Does not change frontmatter or non-imperative prose like 'how to avoid'.
"""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
files = sorted(f for f in root.rglob("*.mdc") if ".cursor" in f.parts)

# Skip the standards doc itself for content transforms (it describes the verbs)
SKIP = {root / ".cursor" / "rule-file-standards.mdc"}


def transform_body(body: str) -> str:
    lines = body.splitlines(keepends=True)
    out = []
    for line in lines:
        raw = line
        # Only transform list items and headings that are instructional
        stripped = line.lstrip()
        is_bullet = stripped.startswith(("- ", "* "))
        is_heading = stripped.startswith("#")

        if not (is_bullet or is_heading):
            # Still normalize "must never" / "Must never" in any body line
            line = re.sub(r"\bmust never\b", "must not", line)
            line = re.sub(r"\bMust never\b", "Must not", line)
            out.append(line)
            continue

        # Bullet / heading transforms
        # Do not / Don't at start of bullet text (after "- ")
        line = re.sub(
            r"^(\s*[-*]\s+)Do not\b",
            r"\1Must not",
            line,
        )
        line = re.sub(
            r"^(\s*[-*]\s+)Don't\b",
            r"\1Must not",
            line,
        )
        line = re.sub(
            r"^(\s*[-*]\s+)Never\b",
            r"\1Must not",
            line,
        )
        line = re.sub(
            r"^(\s*[-*]\s+)Avoid\b",
            r"\1Must not",
            line,
        )
        line = re.sub(
            r"^(\s*[-*]\s+)Must avoid\b",
            r"\1Must not",
            line,
        )
        line = re.sub(
            r"^(\s*[-*]\s+)Should avoid\b",
            r"\1Should not",
            line,
        )

        # Mid-bullet: ", never " / "; never " / " and never "
        line = re.sub(r", never\b", ", and must not", line)
        line = re.sub(r"; never\b", "; must not", line)
        line = re.sub(r"\band never\b", "and must not", line)
        line = re.sub(r"\bbut never\b", "but must not", line)
        line = re.sub(r"\bmust never\b", "must not", line)
        line = re.sub(r"\bMust never\b", "Must not", line)

        # "do not" mid-bullet (lowercase)
        line = re.sub(r"\bdo not\b", "must not", line)
        line = re.sub(r"\bdon't\b", "must not", line)

        # "Must avoid" / "Should avoid" / "must avoid" / "should avoid" anywhere in bullet
        line = re.sub(r"\bMust avoid\b", "Must not", line)
        line = re.sub(r"\bmust avoid\b", "must not", line)
        line = re.sub(r"\bShould avoid\b", "Should not", line)
        line = re.sub(r"\bshould avoid\b", "should not", line)

        # "and avoid X" / "to avoid X" in requirements — only when clearly instructional
        # "to avoid duplicate" → keep if purpose; "and avoid N+1" → "and must not create N+1"
        line = re.sub(r"\band avoid\b", "and must not allow", line)

        # Heading: (never queue) etc.
        if is_heading:
            line = re.sub(r"\(never\b", "(must not", line)

        out.append(line)
    return "".join(out)


changed = []
for f in files:
    if f in SKIP:
        continue
    content = f.read_text(encoding="utf-8")
    m = re.match(r"^(---\n.*?\n---\n?)(.*)$", content, re.DOTALL)
    if not m:
        continue
    fm, body = m.group(1), m.group(2)
    new_body = transform_body(body)
    if new_body != body:
        f.write_text(fm + new_body, encoding="utf-8")
        changed.append(str(f.relative_to(root)).replace("\\", "/"))

print(f"Updated {len(changed)} files:")
for c in changed:
    print(f"  {c}")
