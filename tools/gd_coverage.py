#!/usr/bin/env python3
"""
GDScript Line Coverage Runner for Godot 4.x (Headless).

Copies the Godot project into an isolated temporary directory, instruments
executable lines in `scripts/*.gd` with a lightweight static hit tracker,
executes `tests/test_runner.gd` under `godot --headless`, and emits:
  - coverage/lcov.info       (LCOV standard)
  - coverage/coverage.json   (per-file & total coverage metrics)
  - coverage/summary.md      (Markdown table for PR comments / Step Summary)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

COV_TRACKER_GD = """extends RefCounted
## Tracker de cobertura em tempo de execução gerado pelo gd_coverage.py.

static var hits: Dictionary = {}


static func h(fid: int, line: int) -> void:
\tvar key: int = (fid << 20) | line
\thits[key] = int(hits.get(key, 0)) + 1


static func dump(out_path: String) -> void:
\tvar grouped: Dictionary = {}
\tfor key in hits.keys():
\t\tvar fid: int = int(key) >> 20
\t\tvar line: int = int(key) & 0xFFFFF
\t\tvar fid_str := str(fid)
\t\tif not grouped.has(fid_str):
\t\t\tgrouped[fid_str] = {}
\t\tgrouped[fid_str][str(line)] = hits[key]
\tvar file := FileAccess.open(out_path, FileAccess.WRITE)
\tif file != null:
\t\tfile.store_string(JSON.stringify(grouped))
\t\tfile.close()
"""

FUNC_RE = re.compile(r"^(?:static\s+)?func\s+[A-Za-z_][A-Za-z0-9_]*\s*\(")
CLASS_RE = re.compile(r"^class\s+[A-Za-z_][A-Za-z0-9_]*")
SKIP_STMT_PREFIXES = (
    "elif ",
    "elif(",
    "else:",
    "const ",
    "signal ",
    "enum ",
    "@",
    "class_name ",
    "extends ",
)


def _strip_comment_and_strings(line: str, in_triple_dq: bool, in_triple_sq: bool) -> tuple[str, bool, bool]:
    """Return code-only portion of a line (comments & string contents masked) and updated triple-quote state."""
    out: list[str] = []
    i = 0
    n = len(line)
    in_dq = False
    in_sq = False

    while i < n:
        ch = line[i]
        nxt = line[i : i + 3]
        if in_triple_dq:
            if nxt == '"""':
                in_triple_dq = False
                out.append("   ")
                i += 3
                continue
            out.append(" ")
            i += 1
            continue
        if in_triple_sq:
            if nxt == "'''":
                in_triple_sq = False
                out.append("   ")
                i += 3
                continue
            out.append(" ")
            i += 1
            continue
        if in_dq:
            if ch == "\\" and i + 1 < n:
                out.append("  ")
                i += 2
                continue
            if ch == '"':
                in_dq = False
            out.append(" ")
            i += 1
            continue
        if in_sq:
            if ch == "\\" and i + 1 < n:
                out.append("  ")
                i += 2
                continue
            if ch == "'":
                in_sq = False
            out.append(" ")
            i += 1
            continue

        if nxt == '"""':
            in_triple_dq = True
            out.append("   ")
            i += 3
            continue
        if nxt == "'''":
            in_triple_sq = True
            out.append("   ")
            i += 3
            continue
        if ch == '"':
            in_dq = True
            out.append(" ")
            i += 1
            continue
        if ch == "'":
            in_sq = True
            out.append(" ")
            i += 1
            continue
        if ch == "#":
            break
        out.append(ch)
        i += 1

    return "".join(out), in_triple_dq, in_triple_sq


def _leading_tabs(line: str) -> int:
    count = 0
    for ch in line:
        if ch == "\t":
            count += 1
        else:
            break
    return count


def instrument_gdscript(source: str, file_id: int) -> tuple[str, list[int]]:
    """
    Instrument executable lines inside functions of a GDScript file.
    Returns (instrumented_source, sorted_executable_line_numbers).
    """
    lines = source.splitlines(keepends=True)
    out_lines: list[str] = []
    exec_lines: list[int] = []

    in_triple_dq = False
    in_triple_sq = False
    paren_depth = 0
    prev_continued = False

    # Stack of active scopes: ("func", body_indent) | ("match", match_indent) | ("class", class_indent)
    func_stack: list[int] = []
    match_stack: list[int] = []
    awaiting_func_colon = False
    pending_func_indent = -1

    # Find safe line after `extends ...` (and optional `class_name ...`) to inject preload const
    inject_idx = 0
    for idx, raw in enumerate(lines):
        stripped = raw.strip()
        if stripped.startswith("class_name ") or stripped.startswith("extends ") or stripped.startswith("@"):
            inject_idx = idx + 1
        elif stripped and not stripped.startswith("#"):
            break

    for idx, raw in enumerate(lines):
        lineno = idx + 1
        if idx == inject_idx:
            out_lines.append('const _Cov := preload("res://_cov_tracker.gd")\n')

        raw_no_nl = raw.rstrip("\r\n")
        was_in_triple = in_triple_dq or in_triple_sq
        was_multiline = paren_depth > 0 or prev_continued or was_in_triple

        code_only, in_triple_dq, in_triple_sq = _strip_comment_and_strings(raw_no_nl, in_triple_dq, in_triple_sq)
        stripped = code_only.strip()
        tabs = _leading_tabs(raw_no_nl)

        # Pop closed scopes when indentation drops
        if stripped and not was_multiline:
            while func_stack and tabs <= func_stack[-1]:
                func_stack.pop()
            while match_stack and tabs <= match_stack[-1]:
                match_stack.pop()

        should_instrument = False

        if not was_multiline and stripped:
            if awaiting_func_colon:
                pass
            elif FUNC_RE.match(stripped):
                # Function declaration header; body will be deeper than `tabs`
                if stripped.endswith(":"):
                    func_stack.append(tabs)
                else:
                    awaiting_func_colon = True
                    pending_func_indent = tabs
            elif CLASS_RE.match(stripped):
                pass
            elif func_stack and tabs > func_stack[-1]:
                # Inside a function body at statement start
                is_match_pattern = bool(match_stack and tabs == match_stack[-1] + 1)
                if is_match_pattern:
                    # Match branch header (e.g. `"gancho":` or `_:`), do not instrument before pattern!
                    pass
                elif any(stripped.startswith(p) for p in SKIP_STMT_PREFIXES):
                    pass
                elif stripped == "pass":
                    pass
                else:
                    should_instrument = True
                    if stripped.startswith("match ") or stripped.startswith("match\t"):
                        match_stack.append(tabs)

        if awaiting_func_colon and stripped.endswith(":"):
            func_stack.append(pending_func_indent)
            awaiting_func_colon = False
            pending_func_indent = -1

        if should_instrument:
            indent_str = "\t" * tabs
            out_lines.append(f"{indent_str}_Cov.h({file_id}, {lineno})\n")
            exec_lines.append(lineno)

        out_lines.append(raw)

        # Update multiline tracking for next line
        for ch in code_only:
            if ch in "([{":
                paren_depth += 1
            elif ch in ")]}":
                paren_depth = max(0, paren_depth - 1)
        prev_continued = code_only.rstrip().endswith("\\")

    return "".join(out_lines), exec_lines


def _inject_dump_into_runner(runner_path: Path, dump_path: str) -> None:
    content = runner_path.read_text(encoding="utf-8")
    hook = f'\tload("res://_cov_tracker.gd").dump("{dump_path}")\n'
    if "quit(0)" not in content:
        raise RuntimeError("tests/test_runner.gd does not contain expected quit(0)/quit(1) calls")
    content = content.replace("\t\tquit(0)", f"\t{hook}\t\tquit(0)")
    content = content.replace("\t\tquit(1)", f"\t{hook}\t\tquit(1)")
    runner_path.write_text(content, encoding="utf-8")


def _copy_project(src_root: Path, dst_root: Path) -> None:
    ignore = shutil.ignore_patterns(".git", ".godot", "coverage", "review", "bin", "__pycache__")
    for item in src_root.iterdir():
        if item.name in {".git", ".godot", "coverage", "review", "bin"}:
            continue
        target = dst_root / item.name
        if item.is_dir():
            shutil.copytree(item, target, ignore=ignore)
        else:
            shutil.copy2(item, target)


def run_coverage(
    repo_root: Path,
    out_dir: Path,
    godot_bin: str,
    min_coverage: float,
    fuzz_seed: str | None,
    fuzz_iterations: str | None,
) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    scripts_dir = repo_root / "scripts"
    script_files = sorted(scripts_dir.glob("*.gd"))
    if not script_files:
        print("ERRO: Nenhum script encontrado em scripts/", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(prefix="bedlion_cov_") as tmp:
        tmp_root = Path(tmp)
        _copy_project(repo_root, tmp_root)
        (tmp_root / "_cov_tracker.gd").write_text(COV_TRACKER_GD, encoding="utf-8")

        file_map: dict[int, tuple[str, list[int]]] = {}
        for fid, orig_script in enumerate(script_files, start=1):
            rel = orig_script.relative_to(repo_root).as_posix()
            tmp_script = tmp_root / rel
            instrumented, exec_lines = instrument_gdscript(orig_script.read_text(encoding="utf-8"), fid)
            tmp_script.write_text(instrumented, encoding="utf-8")
            file_map[fid] = (rel, exec_lines)

        hits_file = tmp_root / "cov_hits.json"
        _inject_dump_into_runner(tmp_root / "tests" / "test_runner.gd", hits_file.as_posix())

        env = os.environ.copy()
        env["HOME"] = tmp_root.as_posix()
        env["XDG_DATA_HOME"] = (tmp_root / ".xdg_data").as_posix()
        if fuzz_seed:
            env["FUZZ_SEED"] = fuzz_seed
        if fuzz_iterations:
            env["FUZZ_ITERATIONS"] = fuzz_iterations

        # Warm-up import in temp project so class_name cache resolves cleanly
        imp_cmd = [godot_bin, "--headless", "--path", tmp_root.as_posix(), "--import", "--quit"]
        subprocess.run(imp_cmd, env=env, capture_output=True, text=True, check=False)

        test_cmd = [godot_bin, "--headless", "--path", tmp_root.as_posix(), "-s", "tests/test_runner.gd"]
        proc = subprocess.run(test_cmd, env=env, capture_output=True, text=True)
        print(proc.stdout)
        if proc.stderr:
            print(proc.stderr, file=sys.stderr)

        if proc.returncode != 0:
            print("ERRO: A suíte de testes falhou durante a coleta de cobertura.", file=sys.stderr)
            return proc.returncode

        if "SCRIPT ERROR:" in proc.stdout or "SCRIPT ERROR:" in proc.stderr:
            print("ERRO: Foram detectados SCRIPT ERRORs durante a execução instrumentada.", file=sys.stderr)
            return 1

        if not hits_file.exists():
            print("ERRO: Arquivo de hits de cobertura não foi gerado.", file=sys.stderr)
            return 1

        raw_hits: dict[str, dict[str, int]] = json.loads(hits_file.read_text(encoding="utf-8"))

    # Build LCOV, JSON & Markdown reports
    lcov_lines: list[str] = []
    files_report: list[dict[str, object]] = []
    total_lf = 0
    total_lh = 0

    for fid, (rel_path, exec_lines) in file_map.items():
        file_hits = raw_hits.get(str(fid), {})
        lf = len(exec_lines)
        lh = 0
        uncovered: list[int] = []
        covered_lines: list[int] = []

        lcov_lines.append("TN:")
        lcov_lines.append(f"SF:{rel_path}")
        for ln in exec_lines:
            count = int(file_hits.get(str(ln), 0))
            if count > 0:
                lh += 1
                covered_lines.append(ln)
            else:
                uncovered.append(ln)
            lcov_lines.append(f"DA:{ln},{count}")
        lcov_lines.append(f"LF:{lf}")
        lcov_lines.append(f"LH:{lh}")
        lcov_lines.append("end_of_record")

        pct = (lh / lf * 100.0) if lf > 0 else 100.0
        total_lf += lf
        total_lh += lh
        files_report.append(
            {
                "file": rel_path,
                "lines_found": lf,
                "lines_hit": lh,
                "coverage_pct": round(pct, 2),
                "covered_lines": covered_lines,
                "uncovered_lines": uncovered,
            }
        )

    total_pct = (total_lh / total_lf * 100.0) if total_lf > 0 else 100.0
    (out_dir / "lcov.info").write_text("\n".join(lcov_lines) + "\n", encoding="utf-8")

    cov_json = {
        "total_lines": total_lf,
        "covered_lines": total_lh,
        "coverage_pct": round(total_pct, 2),
        "min_coverage": min_coverage,
        "files": files_report,
    }
    (out_dir / "coverage.json").write_text(json.dumps(cov_json, indent=2), encoding="utf-8")

    md_lines = [
        "## Cobertura de Código GDScript",
        "",
        f"**Cobertura Total:** `{total_pct:.2f}%` ({total_lh}/{total_lf} linhas executáveis)",
        "",
        "| Arquivo | Cobertas | Total | Cobertura |",
        "| :--- | :---: | :---: | :---: |",
    ]
    for f in sorted(files_report, key=lambda x: (float(x["coverage_pct"]), str(x["file"])), reverse=True):
        md_lines.append(
            f"| `{f['file']}` | {f['lines_hit']} | {f['lines_found']} | {float(f['coverage_pct']):.1f}% |"
        )
    summary_text = "\n".join(md_lines) + "\n"
    (out_dir / "summary.md").write_text(summary_text, encoding="utf-8")

    print("\n" + summary_text)
    if total_pct < min_coverage:
        print(
            f"ERRO: Cobertura total ({total_pct:.2f}%) abaixo do mínimo exigido ({min_coverage:.2f}%).",
            file=sys.stderr,
        )
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Godot 4 GDScript Line Coverage Runner")
    parser.add_argument("--repo-root", default=".", help="Project root path")
    parser.add_argument("--out-dir", default="coverage", help="Output directory for lcov/json/md")
    parser.add_argument("--godot", default="godot", help="Godot binary path or name")
    parser.add_argument("--min-coverage", type=float, default=0.0, help="Fail if total coverage < threshold")
    parser.add_argument("--fuzz-seed", default=None, help="Override FUZZ_SEED")
    parser.add_argument("--fuzz-iterations", default=None, help="Override FUZZ_ITERATIONS")
    args = parser.parse_args()

    return run_coverage(
        repo_root=Path(args.repo_root).resolve(),
        out_dir=Path(args.out_dir).resolve(),
        godot_bin=args.godot,
        min_coverage=args.min_coverage,
        fuzz_seed=args.fuzz_seed,
        fuzz_iterations=args.fuzz_iterations,
    )


if __name__ == "__main__":
    sys.exit(main())
