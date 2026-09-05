"""Read-only comparison; reference archives are never extracted or executed."""
import hashlib
import json
import re
import zipfile
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

WORK = Path(__file__).resolve().parent
ADDON = WORK / "EncounterLab"
OUT = WORK.parent / "outputs"
import argparse
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archives', nargs='+', type=Path, help='Reference ZIPs to compare locally')
REFERENCES = [(p, hashlib.sha256(p.read_bytes()).hexdigest().upper()) for p in parser.parse_args().archives]
WINDOW = 8
MIN_CHARS = 160
LONG_BRACKET = re.compile(r"\[(=*)\[")


def digest(data):
    return hashlib.sha256(data).hexdigest().upper()


def file_digest(path):
    result = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest().upper()


def strip_lua_comments(text):
    # Preserve strings and newlines; recognize Lua quoted and long-bracket strings.
    # This is lexical normalization only, not a Lua parser or execution engine.
    result = []
    i = 0
    while i < len(text):
        if text.startswith("--", i):
            start = LONG_BRACKET.match(text, i + 2)
            if start:
                close = "]" + start.group(1) + "]"
                end = text.find(close, i + 2 + len(start.group(0)))
                end = len(text) if end == -1 else end + len(close)
                result.append("\n" * text[i:end].count("\n"))
                result.append(" ")
                i = end
            else:
                end = text.find("\n", i)
                i = len(text) if end == -1 else end
        elif text[i] in "\"'":
            quote = text[i]
            end = i + 1
            while end < len(text):
                if text[end] == "\\":
                    end += 2
                elif text[end] == quote:
                    end += 1
                    break
                else:
                    end += 1
            result.append(text[i:end])
            i = end
        elif start := LONG_BRACKET.match(text, i):
            close = "]" + start.group(1) + "]"
            end = text.find(close, i + len(start.group(0)))
            end = len(text) if end == -1 else end + len(close)
            result.append(text[i:end])
            i = end
        else:
            result.append(text[i])
            i += 1
    return "".join(result)


def lua_windows(data):
    decoded = data.decode("utf-8-sig", errors="replace")
    lines = []
    for number, line in enumerate(strip_lua_comments(decoded).splitlines(), 1):
        normalized = " ".join(line.strip().split())
        if not normalized or normalized in {"end", "end;", "else", "do", "then", "repeat"}:
            continue
        if not re.search(r"[A-Za-z0-9_]", normalized):
            continue
        lines.append((number, normalized))
    windows = []
    for index in range(max(0, len(lines) - WINDOW + 1)):
        window = lines[index:index + WINDOW]
        joined = "\n".join(value for _, value in window)
        if len(re.sub(r"\s", "", joined)) >= MIN_CHARS:
            windows.append((digest(joined.encode("utf-8")), window[0][0], window[-1][0]))
    return windows


def addon_snapshot():
    return {p.relative_to(ADDON).as_posix(): p.read_bytes()
            for p in sorted(ADDON.rglob("*")) if p.is_file()}


def main():
    started = datetime.now(timezone.utc).isoformat()
    snapshot = addon_snapshot()
    addon_hashes = {name: digest(data) for name, data in snapshot.items()}
    candidate_index = defaultdict(list)
    candidate_window_count = 0
    for name, data in snapshot.items():
        if name.lower().endswith(".lua"):
            windows = lua_windows(data)
            candidate_window_count += len(windows)
            for key, first, last in windows:
                candidate_index[key].append({"file": name, "line_start": first, "line_end": last})

    reference_records = []
    exact_matches = []
    window_matches = []
    for path, expected in REFERENCES:
        before = path.stat()
        actual = file_digest(path)
        record = {"archive": path.name, "bytes": before.st_size,
                  "expected_sha256": expected, "actual_sha256": actual,
                  "expected_sha256_matches": actual == expected,
                  "file_entries": 0, "lua_entries": 0, "eligible_lua_windows": 0}
        if actual != expected:
            raise RuntimeError("Reference archive hash does not match supplied expectation: " + path.name)
        with zipfile.ZipFile(path, "r") as archive:
            for entry in archive.infolist():
                if entry.is_dir():
                    continue
                # Read entry bytes in memory only; no extraction or reference-code execution.
                data = archive.read(entry)
                record["file_entries"] += 1
                entry_hash = digest(data)
                for name, candidate_hash in addon_hashes.items():
                    if candidate_hash == entry_hash:
                        exact_matches.append({"addon_file": name, "archive": path.name,
                                              "reference_entry": entry.filename, "sha256": entry_hash})
                if not entry.filename.lower().endswith(".lua"):
                    continue
                record["lua_entries"] += 1
                windows = lua_windows(data)
                record["eligible_lua_windows"] += len(windows)
                for key, first, last in windows:
                    for candidate in candidate_index.get(key, []):
                        window_matches.append({"addon": candidate, "archive": path.name,
                                               "reference_entry": entry.filename,
                                               "reference_line_start": first,
                                               "reference_line_end": last,
                                               "normalized_window_sha256": key})
        after = path.stat()
        record["unchanged_during_read"] = (before.st_size == after.st_size
                                             and before.st_mtime_ns == after.st_mtime_ns
                                             and file_digest(path) == actual)
        reference_records.append(record)

    after_snapshot = addon_snapshot()
    stable = (addon_hashes == {name: digest(data) for name, data in after_snapshot.items()})
    file_records = [{"path": name, "bytes": len(snapshot[name]), "sha256": value}
                    for name, value in addon_hashes.items()]
    manifest_text = "\n".join(f"{name}\0{value}" for name, value in sorted(addon_hashes.items()))
    limitations = [
        "Hash and normalized-window checks cannot prove independent authorship or the complete absence of derivation.",
        "Whole-file SHA256 detects byte-identical files only; changed, re-encoded, cropped or otherwise transformed media can evade it.",
        "Lua matching is lexical, not semantic. Renaming, reformatting across lines, reordering, short fragments and rewritten logic can evade it.",
        "Eight significant-line windows require at least 160 non-whitespace characters. Shorter reuse and excluded structural lines are outside this check.",
        "Normalization strips Lua comments, drops blank and selected structural-only lines, and collapses within-line whitespace (including within strings); matches require human review and may reflect conventional API usage.",
        "Only the listed addon snapshot and the supplied archives were compared. No internet corpus, author history, licensing review or live WoW behavior was evaluated.",
    ]
    report = {
        "title": "EncounterLab alpha reference-comparison audit",
        "started_utc": started, "completed_utc": datetime.now(timezone.utc).isoformat(),
        "addon_root": "EncounterLab", "addon_file_count": len(snapshot),
        "addon_lua_file_count": sum(name.lower().endswith(".lua") for name in snapshot),
        "addon_media_file_count": sum(name.startswith("Media/") for name in snapshot),
        "addon_snapshot_unchanged_during_audit": stable,
        "addon_manifest_sha256": digest(manifest_text.encode("utf-8")),
        "addon_manifest_sha256_definition": "SHA256 of UTF-8 sorted path + NUL + uppercase SHA256 rows joined with LF, without final LF",
        "addon_files": file_records, "reference_archives": reference_records,
        "exact_file_matches": exact_matches,
        "lua_comparison": {"window_significant_lines": WINDOW, "minimum_non_whitespace_characters": MIN_CHARS,
                           "addon_eligible_windows": candidate_window_count,
                           "matched_window_occurrences": window_matches},
        "reference_archives_extracted": False, "reference_code_executed": False,
        "limitations": limitations,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    json_path = OUT / "EncounterLab-provenance-audit.json"
    md_path = OUT / "EncounterLab-provenance-audit.md"
    json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    rows = [
        "# EncounterLab alpha: reference comparison", "",
        "This limited technical comparison checks the addon snapshot below against the supplied reference archives. It cannot establish independent authorship.", "",
        f"- Completed (UTC): {report['completed_utc']}",
        f"- Addon files: {len(snapshot)}; Lua files: {report['addon_lua_file_count']}; media files: {report['addon_media_file_count']}",
        f"- Byte-identical files in reference archives: {len(exact_matches)}",
        f"- Matching normalized Lua windows: {len(window_matches)}",
        f"- Addon unchanged during comparison: {'yes' if stable else 'NO'}",
        "- Reference archives were not extracted and their code was not executed.", "",
        "## Reference archives", "",
        "| Archive | SHA256 | Expected hash verified | Files | Lua files | Lua windows |",
        "| --- | --- | --- | ---: | ---: | ---: |",
    ]
    for ref in reference_records:
        rows.append(f"| {ref['archive']} | `{ref['actual_sha256']}` | {'yes' if ref['expected_sha256_matches'] else 'NO'} | {ref['file_entries']} | {ref['lua_entries']} | {ref['eligible_lua_windows']} |")
    rows.extend([
        "", "## Method and limits", "",
        f"SHA256 compares every addon file with every archive entry. Lua is also compared in windows of {WINDOW} significant lines containing at least {MIN_CHARS} non-whitespace characters ({candidate_window_count} addon windows). Comments, blank lines and selected structural lines are excluded; within-line whitespace is normalized. This is not a Lua parser or semantic comparison.", "",
        "These checks cannot prove independent authorship or rule out derivation. Renaming, rewritten logic, short fragments, line wrapping and modified or re-encoded media can evade detection. Matches can reflect common API patterns and require review. Other sources, development history, licensing and live WoW behavior are outside this comparison.", "",
        "## Verified addon snapshot", "",
        f"Manifest-SHA256: `{report['addon_manifest_sha256']}`", "",
        "| Addon file | Bytes | SHA256 |", "| --- | ---: | --- |",
    ])
    for entry in file_records:
        rows.append(f"| {entry['path']} | {entry['bytes']} | `{entry['sha256']}` |")
    if exact_matches or window_matches:
        rows.extend(["", "Individual matches with filenames and line positions are in the JSON report; reference code is not reproduced."])
    rows.extend(["", "The JSON report contains complete counts, checksums, method details and limitations.", ""])
    md_path.write_text("\n".join(rows), encoding="utf-8")
    print(json.dumps({"json": str(json_path), "markdown": str(md_path),
                      "addon_file_count": len(snapshot), "exact_file_matches": len(exact_matches),
                      "lua_window_matches": len(window_matches), "addon_eligible_windows": candidate_window_count,
                      "stable_snapshot": stable, "reference_archives": reference_records,
                      "addon_manifest_sha256": report["addon_manifest_sha256"]}, indent=2))
    if not stable or not all(ref["unchanged_during_read"] for ref in reference_records):
        raise SystemExit("Input changed during audit; results must be rerun.")


if __name__ == "__main__":
    main()
