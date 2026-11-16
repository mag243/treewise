"""Makes the UI review's report (ADR 0103) from an exported result bundle: each screen's
screenshot as <screen>-<variant>.png, a page index.html with every screen and its findings,
and findings.txt. Findings listed in allowed.txt, with their reason, are shown but count for
nothing. Exits 1 when any other finding is left.

Usage: python3 -I report.py <exported attachments folder> <output folder> <allowed.txt>
The attachments folder holds one export, or one folder per exported result bundle.
"""

import html
import json
import re
import shutil
import sys
from pathlib import Path

PREFIX = "uireview-"
VARIANT = re.compile(r"-(light|dark)$")
UNIQUE = re.compile(r"^(.*)_\d+_[0-9A-F-]+(\.\w+)?$")


def allowed_entries(path: Path) -> list[tuple[str, str, str]]:
    """Each line `screen | check | element  # reason`; a screen without its variant."""
    entries = []
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = [part.strip() for part in line.split("|")]
        if len(parts) == 3:
            entries.append((parts[0], parts[1], parts[2]))
    return entries


def is_allowed(screen: str, finding: dict, allowed) -> bool:
    bare = VARIANT.sub("", screen)
    return any(
        s in (screen, bare, "*") and c == finding["check"] and e in (finding["element"], "*")
        for s, c, e in allowed
    )


def main() -> None:
    exported, output, allowed_path = (Path(arg) for arg in sys.argv[1:4])
    allowed = allowed_entries(allowed_path) if allowed_path.exists() else []
    screens: dict[str, dict] = {}
    # One manifest per result bundle, in the folder itself or one folder per bundle in it.
    tests = [
        (path.parent, test)
        for path in sorted(exported.rglob("manifest.json"))
        for test in json.loads(path.read_text())
    ]
    for folder, test in tests:
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "")
            if not name.startswith(PREFIX):
                continue
            # Xcode adds a count and an id before the extension: name_0_<id>.findings.
            parts = UNIQUE.match(name)
            name, extension = (parts[1], parts[2] or "") if parts else (name, "")
            name = name[len(PREFIX):]
            source = folder / attachment["exportedFileName"]
            if extension == ".findings":
                screens.setdefault(name, {})["findings"] = json.loads(source.read_text() or "[]")
            else:
                shutil.copyfile(source, output / f"{name}.png")
                screens.setdefault(name, {})["image"] = f"{name}.png"
    if not screens:
        sys.exit("No screens in the result bundle.")
    lines, sections, left = [], [], 0
    for screen in sorted(screens):
        found = screens[screen].get("findings", [])
        items = []
        for finding in found:
            ok = is_allowed(screen, finding, allowed)
            left += 0 if ok else 1
            text = f"{finding['check']}: {finding['element']}: {finding['detail']}"
            lines.append(f"{'allowed ' if ok else ''}{screen}: {text}")
            items.append(f"<li class={'allowed' if ok else 'found'}>{html.escape(text)}</li>")
        image = screens[screen].get("image")
        sections.append(
            f"<section id='{screen}'><h2>{html.escape(screen)}</h2>"
            + (f"<ul>{''.join(items)}</ul>" if items else "<p class=clean>No findings.</p>")
            + (f"<img src='{image}' alt='{html.escape(screen)}'>" if image else "")
            + "</section>"
        )
    (output / "findings.txt").write_text("\n".join(lines) + ("\n" if lines else ""))
    page = f"""<!doctype html><meta charset=utf-8><title>UI Review</title>
<style>
:root{{color-scheme:light dark;font:14px -apple-system,sans-serif}}
body{{margin:24px;background:Canvas;color:CanvasText}}
section{{margin:0 0 40px}} img{{max-width:100%;border:1px solid #8884}}
.found{{color:#d33}} .allowed{{color:#888}} .clean{{color:#2a2}}
</style>
<h1>UI Review</h1><p>{len(screens)} screens, {left} findings not allowed.</p>
{''.join(sections)}"""
    (output / "index.html").write_text(page)
    print(f"    {len(screens)} screens, {left} findings")
    sys.exit(1 if left else 0)


if __name__ == "__main__":
    main()
