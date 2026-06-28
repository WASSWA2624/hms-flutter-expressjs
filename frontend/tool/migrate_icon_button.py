import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1] / "lib"

for path in root.rglob("*.dart"):
    text = path.read_text(encoding="utf-8")
    if "AppIconButton" not in text:
        continue

    original = text
    text = text.replace("AppIconButton(", "AppButton(iconOnly: true, ")
    text = re.sub(
        r"import 'package:hosspi_hms/shared/components/app_icon_button.dart';\n",
        "",
        text,
    )

    def add_label(match: re.Match[str]) -> str:
        indent = match.group(1)
        value = match.group(2).strip()
        if "label:" in match.string[: match.start()]:
            return match.group(0)
        return f"{indent}label: {value},\n{indent}semanticLabel: {value},"

    parts: list[str] = []
    cursor = 0
    token = "AppButton(iconOnly: true, "
    while True:
        start = text.find(token, cursor)
        if start == -1:
            parts.append(text[cursor:])
            break
        parts.append(text[cursor:start])
        depth = 0
        index = start + len(token) - 1
        while index < len(text):
            char = text[index]
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    block = text[start : index + 1]
                    block = re.sub(r"(\s*)icon\s*:", r"\1leadingIcon:", block, count=1)
                    if "label:" not in block:
                        block = re.sub(
                            r"(\s*)semanticLabel\s*:\s*([^,\n]+),",
                            add_label,
                            block,
                            count=1,
                        )
                    parts.append(block)
                    cursor = index + 1
                    break
            index += 1
        else:
            parts.append(text[start:])
            break

    text = "".join(parts)

    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"updated {path.relative_to(root.parent)}")
