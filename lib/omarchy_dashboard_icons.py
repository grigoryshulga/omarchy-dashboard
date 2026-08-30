"""Discover launcher icons without importing or executing foreign plugin QML."""

from __future__ import annotations

import argparse
import ast
import json
import os
import re
from pathlib import Path


MAX_MANIFEST_BYTES = 256 * 1024
MAX_ENTRY_BYTES = 1024 * 1024
MAX_MANIFESTS = 512
MAX_DISCOVERY_DEPTH = 4
IMAGE_EXTENSIONS = {".svg", ".png", ".webp"}
PROPERTY_ICON = re.compile(
    r"\b(?:readonly\s+)?property\s+string\s+(?:icon|heroGlyph|glyph|iconText)\s*:\s*"
    r"(?P<literal>\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*')"
)


def bounded_text(path: Path, maximum: int) -> str:
    if path.is_symlink() or not path.is_file() or path.stat().st_size > maximum:
        return ""
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return ""


def strip_comments(source: str) -> str:
    output: list[str] = []
    index = 0
    quote = ""
    while index < len(source):
        if quote:
            output.append(source[index])
            if source[index] == "\\" and index + 1 < len(source):
                index += 1
                output.append(source[index])
            elif source[index] == quote:
                quote = ""
            index += 1
        elif source[index] in "\"'":
            quote = source[index]
            output.append(source[index])
            index += 1
        elif source.startswith("//", index):
            end = source.find("\n", index + 2)
            index = len(source) if end < 0 else end
        elif source.startswith("/*", index):
            end = source.find("*/", index + 2)
            index = len(source) if end < 0 else end + 2
        else:
            output.append(source[index])
            index += 1
    return "".join(output)


def decode_literal(literal: str) -> str:
    try:
        value = ast.literal_eval(literal)
        if not isinstance(value, str):
            return ""
        return value.encode("utf-16", "surrogatepass").decode("utf-16")
    except (SyntaxError, UnicodeError, ValueError):
        return ""


def is_glyph(value: str) -> bool:
    text = value.strip()
    if not text or len(text) > 4:
        return False
    for character in text:
        point = ord(character)
        if 0xE000 <= point <= 0xF8FF or point >= 0xF0000:
            return True
        if point >= 0x2300 and not character.isalnum():
            return True
    return False


def image_candidate(plugin_dir: Path, value: object) -> dict[str, str] | None:
    if not isinstance(value, str) or Path(value).suffix.lower() not in IMAGE_EXTENSIONS:
        return None
    relative = Path(value)
    if relative.is_absolute() or ".." in relative.parts:
        return None
    unresolved = plugin_dir / relative
    if unresolved.is_symlink():
        return None
    candidate = unresolved.resolve()
    try:
        candidate.relative_to(plugin_dir.resolve())
    except ValueError:
        return None
    if not candidate.is_file():
        return None
    return {"kind": "image", "value": candidate.as_uri()}


def explicit_icon(plugin_dir: Path, manifest: dict[str, object]) -> dict[str, str] | None:
    dashboard = manifest.get("dashboard") if isinstance(manifest.get("dashboard"), dict) else {}
    bar = manifest.get("barWidget") if isinstance(manifest.get("barWidget"), dict) else {}
    values = [dashboard.get("icon"), manifest.get("icon"), bar.get("icon"), bar.get("iconName")]
    for value in values:
        image = image_candidate(plugin_dir, value)
        if image:
            return image
        if isinstance(value, str) and is_glyph(value):
            return {"kind": "glyph", "value": value.strip()}
    for relative in ("icon.svg", "icon.png", "icon.webp", "assets/icon.svg", "assets/icon.png", "assets/icon.webp"):
        image = image_candidate(plugin_dir, relative)
        if image:
            return image
    return None


def qml_icon(plugin_dir: Path, manifest: dict[str, object]) -> dict[str, str] | None:
    entry_points = manifest.get("entryPoints")
    if not isinstance(entry_points, dict):
        return None
    for key in ("barWidget", "panel", "overlay", "menu"):
        relative_value = entry_points.get(key)
        if not isinstance(relative_value, str):
            continue
        relative = Path(relative_value)
        if relative.is_absolute() or ".." in relative.parts:
            continue
        source = strip_comments(bounded_text(plugin_dir / relative, MAX_ENTRY_BYTES))
        for match in PROPERTY_ICON.finditer(source):
            value = decode_literal(match.group("literal"))
            if is_glyph(value):
                return {"kind": "glyph", "value": value.strip()}
    return None


def discover(roots: list[Path]) -> dict[str, dict[str, str]]:
    icons: dict[str, dict[str, str]] = {}
    manifest_count = 0
    for root in roots:
        if not root.is_dir():
            continue
        manifests: list[Path] = []
        for current, directories, files in os.walk(root, followlinks=False):
            current_path = Path(current)
            depth = len(current_path.relative_to(root).parts)
            directories[:] = sorted(
                name for name in directories
                if not name.startswith(".") and not (current_path / name).is_symlink()
            ) if depth < MAX_DISCOVERY_DEPTH else []
            if "manifest.json" in files:
                manifests.append(current_path / "manifest.json")
        for manifest_path in sorted(manifests):
            manifest_count += 1
            if manifest_count > MAX_MANIFESTS:
                return icons
            source = bounded_text(manifest_path, MAX_MANIFEST_BYTES)
            if not source:
                continue
            try:
                manifest = json.loads(source)
            except json.JSONDecodeError:
                continue
            if not isinstance(manifest, dict) or not isinstance(manifest.get("id"), str):
                continue
            icon = explicit_icon(manifest_path.parent, manifest) or qml_icon(manifest_path.parent, manifest)
            if icon:
                icons[manifest["id"]] = icon
    return icons


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("roots", nargs="+")
    arguments = parser.parse_args()
    roots = [Path(os.path.abspath(value)) for value in arguments.roots]
    print(json.dumps(discover(roots), ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
