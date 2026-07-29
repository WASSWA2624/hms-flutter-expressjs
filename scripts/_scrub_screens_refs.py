"""Strip screens/ inventory references from prompts after deleting screens/."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPT_ROOTS = (
    ROOT / "prompts" / "ui-permissions",
    ROOT / "prompts" / "billing-and-sections",
)

SCREEN_INV_LINE = re.compile(
    r"^- Screen inventory(?: \(read-only; do not modify\))?: `screens/[^`]+`.*\n",
    re.M,
)
SCREEN_CONSTRAINT = re.compile(
    r"^- Do not create, edit, delete, or regenerate any file under `screens/`.*\n",
    re.M,
)
SCREEN_RELEVANT = re.compile(r"^- `screens/[^`]+`\n", re.M)
SCREEN_SHARED_SECTION = re.compile(
    r"\n## Screen inventories \(read-only\)\n.*?(?=\n## |\Z)",
    re.S,
)


def scrub_prompt(text: str) -> str:
    text = SCREEN_INV_LINE.sub("", text)
    text = SCREEN_CONSTRAINT.sub("", text)
    text = SCREEN_RELEVANT.sub("", text)
    # Drop empty double blank lines introduced by removals.
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text


def main() -> None:
    updated = 0
    for prompt_root in PROMPT_ROOTS:
        for path in prompt_root.rglob("*.md"):
            original = path.read_text(encoding="utf-8")
            text = scrub_prompt(original)
            if path.name == "_shared-rules.md":
                text = SCREEN_SHARED_SECTION.sub(
                    "\n## Screen inventories\n\n"
                    "- The former `screens/` inventory folder has been removed.\n"
                    "- Do **not** recreate `screens/` or write inventory markdown there.\n"
                    "- Inventory atoms from feature presentation code, routes, and tests.\n",
                    text,
                )
            if text != original:
                path.write_text(text, encoding="utf-8", newline="\n")
                updated += 1
    print(f"updated {updated} prompt files")


if __name__ == "__main__":
    main()
