from pathlib import Path
import re

ROOT = Path(r"D:\coding\apps\flutter\hms")

# Patterns that refer to renamed plan files
REPLACEMENTS = [
    (re.compile(r"(dev-plan/P\d{3}_[a-z0-9_]+)\.mdc\b"), r"\1.md"),
    (re.compile(r"(dev-plan/\d{2}-[a-z0-9-]+)\.mdc\b"), r"\1.md"),
    (re.compile(r"(dev-plan/index)\.mdc\b"), r"\1.md"),
    (re.compile(r"\b(P\d{3}_[a-z0-9_]+)\.mdc\b"), r"\1.md"),
]

updated = []
skip_dirs = {".git", "node_modules", ".dart_tool", "build", "dist", "coverage"}

for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    if any(part in skip_dirs for part in path.parts):
        continue
    if path.suffix.lower() not in {
        ".md",
        ".mdc",
        ".js",
        ".ts",
        ".dart",
        ".json",
        ".yml",
        ".yaml",
        ".txt",
    }:
        continue
    # Skip the converter helper itself
    if path.name.startswith("_convert"):
        continue

    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue

    new_text = text
    for pattern, repl in REPLACEMENTS:
        new_text = pattern.sub(repl, new_text)

    if new_text != text:
        path.write_text(new_text, encoding="utf-8", newline="\n")
        updated.append(path.relative_to(ROOT).as_posix())

print(f"Updated {len(updated)} reference files")
for item in updated:
    print(item)
