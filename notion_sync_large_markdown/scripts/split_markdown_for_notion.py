#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path


HEADING_RE = re.compile(r"^(#{1,3})\s+")


def split_front_matter(lines):
    if len(lines) >= 2 and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                return lines[: i + 1], lines[i + 1 :]
    return [], lines


def build_sections(lines):
    sections = []
    current = []

    for line in lines:
        if HEADING_RE.match(line) and current:
            sections.append("".join(current))
            current = [line]
        else:
            current.append(line)

    if current:
        sections.append("".join(current))

    return sections


def split_large_section(section, max_bytes):
    if len(section.encode("utf-8")) <= max_bytes:
        return [section]

    heading = ""
    body = section

    first_line, sep, remainder = section.partition("\n")
    if HEADING_RE.match(first_line):
        heading = first_line + (sep or "")
        body = remainder

    parts = re.split(r"(\n\s*\n)", body)
    chunks = []
    current = heading

    for part in parts:
        if len((current + part).encode("utf-8")) <= max_bytes or not current:
            current += part
            continue
        if current:
            chunks.append(current)
        current = part

    if current:
        chunks.append(current)

    oversized = []
    for chunk in chunks:
        if len(chunk.encode("utf-8")) <= max_bytes:
            oversized.append(chunk)
            continue
        lines = chunk.splitlines(keepends=True)
        current_line_chunk = ""
        for line in lines:
            if len(line.encode("utf-8")) > max_bytes:
                if current_line_chunk:
                    oversized.append(current_line_chunk)
                    current_line_chunk = ""

                piece = ""
                for char in line:
                    if len((piece + char).encode("utf-8")) <= max_bytes:
                        piece += char
                        continue
                    oversized.append(piece)
                    piece = char
                if piece:
                    oversized.append(piece)
                continue

            if (
                len((current_line_chunk + line).encode("utf-8")) <= max_bytes
                or not current_line_chunk
            ):
                current_line_chunk += line
                continue
            oversized.append(current_line_chunk)
            current_line_chunk = line
        if current_line_chunk:
            oversized.append(current_line_chunk)

    return oversized


def pack_chunks(front_matter, sections, max_bytes):
    chunks = []
    current = front_matter

    for section in sections:
        candidates = split_large_section(section, max_bytes)
        for candidate in candidates:
            if not current:
                current = candidate
                continue
            if len((current + candidate).encode("utf-8")) <= max_bytes:
                current += candidate
                continue
            chunks.append(current)
            current = candidate

    if current:
        chunks.append(current)

    return chunks


def ensure_title_in_first_chunk(chunks, title_line):
    if not chunks or not title_line:
        return chunks

    first = chunks[0]
    if title_line in first:
        return chunks

    chunks[0] = title_line + "\n" + first.lstrip("\n")
    return chunks


def write_output(chunks, out_dir, source_path):
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "source_path": str(source_path),
        "chunk_count": len(chunks),
        "chunks": [],
    }

    for idx, chunk in enumerate(chunks, start=1):
        file_name = f"part-{idx:03d}.md"
        path = out_dir / file_name
        path.write_text(chunk, encoding="utf-8")
        manifest["chunks"].append(
            {
                "index": idx,
                "file_name": file_name,
                "path": str(path),
                "bytes": len(chunk.encode("utf-8")),
                "starts_with_heading": bool(HEADING_RE.match(chunk)),
            }
        )

    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def main():
    parser = argparse.ArgumentParser(
        description="Split a markdown file into Notion-safe chunk files."
    )
    parser.add_argument("input_path", help="Absolute or relative path to the source markdown file")
    parser.add_argument(
        "--out-dir",
        required=True,
        help="Directory where part-XXX.md files and manifest.json will be written",
    )
    parser.add_argument(
        "--max-bytes",
        type=int,
        default=400000,
        help="Target maximum bytes per chunk before writing a new part",
    )
    args = parser.parse_args()

    input_path = Path(args.input_path).expanduser().resolve()
    out_dir = Path(args.out_dir).expanduser().resolve()

    text = input_path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    front_matter, body_lines = split_front_matter(lines)

    title_line = ""
    for line in body_lines:
        if line.startswith("# "):
            title_line = line.rstrip("\n")
            break

    sections = build_sections(body_lines)
    chunks = pack_chunks("".join(front_matter), sections, args.max_bytes)
    chunks = ensure_title_in_first_chunk(chunks, title_line)
    manifest = write_output(chunks, out_dir, input_path)
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
