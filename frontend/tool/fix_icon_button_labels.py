import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1] / "lib"

pattern = re.compile(
    r"AppButton\(iconOnly:\s*true,\s*\n"
    r"(?:(?!label:)[\s\S])*?"
    r"(semanticLabel:\s*([^,\n]+(?:\([^)]*\))?[^,\n]*),)",
    re.MULTILINE,
)

for path in root.rglob("*.dart"):
    text = path.read_text(encoding="utf-8")
    if "AppButton(iconOnly:" not in text:
        continue

    def repl(match: re.Match[str]) -> str:
        block = match.group(0)
        if "label:" in block.split("semanticLabel:")[0]:
            return block
        semantic = match.group(1)
        value = match.group(2).strip()
        return block.replace(
            semantic,
            f"label: {value},\n      {semantic}",
            1,
        )

    updated = pattern.sub(repl, text)
    if updated != text:
        path.write_text(updated, encoding="utf-8")
        print(f"fixed {path.relative_to(root.parent)}")
