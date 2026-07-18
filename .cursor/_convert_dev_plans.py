from pathlib import Path
import re

ROOT = Path(r"D:\coding\apps\flutter\hms")
PLAN_DIRS = [
    ROOT / "backend" / "dev-plan",
    ROOT / "frontend" / "dev-plan",
]


def strip_frontmatter(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    match = re.match(r"^---\n.*?\n---\n(.*)$", text, re.DOTALL)
    body = match.group(1) if match else text
    body = body.lstrip("\n")
    if not body.endswith("\n"):
        body += "\n"
    return body


def rewrite_plan_refs(body: str) -> str:
    body = re.sub(r"(dev-plan/[^)\s\"'`\]]+)\.mdc\b", r"\1.md", body)
    body = re.sub(r"\b(P\d{3}_[a-z0-9_]+)\.mdc\b", r"\1.md", body)
    body = re.sub(r"\b(\d{2}-[a-z0-9-]+)\.mdc\b", r"\1.md", body)
    body = re.sub(r"(?<![A-Za-z0-9_/.-])(index)\.mdc\b", r"\1.md", body)
    return body


converted = []
for plan_dir in PLAN_DIRS:
    for path in sorted(plan_dir.glob("*.mdc")):
        text = path.read_text(encoding="utf-8-sig")
        body = rewrite_plan_refs(strip_frontmatter(text))
        new_path = path.with_suffix(".md")
        new_path.write_text(body, encoding="utf-8", newline="\n")
        path.unlink()
        converted.append(new_path.relative_to(ROOT).as_posix())

print(f"Converted {len(converted)} files")
for item in converted:
    print(item)
