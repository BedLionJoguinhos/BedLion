#!/usr/bin/env python3
"""
Godot 4 Automated Code Review & Best-Practices Analyzer.

Evaluates GDScript quality, static typing, performance hot-paths, memory safety,
maintainability, gdlint/gdformat output, and test/diff coverage (from LCOV/JSON),
emitting GitHub Actions annotations and a structured Markdown PR review report.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

FUNC_DEF_RE = re.compile(r"^(\t*)(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*(->\s*[^:]+)?:")
UNTYPED_VAR_RE = re.compile(r"^\t*var\s+([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)")
PRINT_CALL_RE = re.compile(r"\b(?:print|print_debug|prints|printt)\s*\(")
LOAD_CALL_RE = re.compile(r"(?<!pre)\bload\s*\(")
TODO_RE = re.compile(r"#.*\b(TODO|FIXME|HACK|XXX)\b", re.IGNORECASE)
HUNK_RE = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")


@dataclass
class Finding:
    severity: str  # "error" | "warning" | "notice"
    rule: str
    file: str
    line: int
    message: str
    in_pr_diff: bool = False


def _git_changed_lines(repo_root: Path, base_ref: str | None) -> tuple[set[str], dict[str, set[int]]]:
    """Return (changed_files, {rel_path: set_of_added_or_modified_line_numbers})."""
    if not base_ref:
        return set(), {}

    # Ensure base_ref exists locally; fallback to HEAD~1 if needed
    cmd = ["git", "diff", "--unified=0", "--no-color", f"{base_ref}...HEAD", "--", "*.gd", "project.godot", "scenes/*.tscn"]
    proc = subprocess.run(cmd, cwd=repo_root, capture_output=True, text=True)
    if proc.returncode != 0:
        cmd_fb = ["git", "diff", "--unified=0", "--no-color", "HEAD~1..HEAD", "--", "*.gd", "project.godot", "scenes/*.tscn"]
        proc = subprocess.run(cmd_fb, cwd=repo_root, capture_output=True, text=True)
        if proc.returncode != 0:
            return set(), {}

    changed_files: set[str] = set()
    changed_lines: dict[str, set[int]] = {}
    current_file: str | None = None

    for raw in proc.stdout.splitlines():
        if raw.startswith("+++ b/"):
            current_file = raw[6:].strip()
            changed_files.add(current_file)
            changed_lines.setdefault(current_file, set())
        elif raw.startswith("@@ ") and current_file:
            m = HUNK_RE.match(raw)
            if m:
                start = int(m.group(1))
                count = int(m.group(2)) if m.group(2) is not None else 1
                if count > 0:
                    changed_lines[current_file].update(range(start, start + count))

    return changed_files, changed_lines


def analyze_gdscript(path: Path, rel_path: str, changed_lines: set[int]) -> tuple[list[Finding], dict[str, int]]:
    """Audit a single GDScript file for Godot 4 best practices and typing metrics."""
    findings: list[Finding] = []
    source = path.read_text(encoding="utf-8")
    lines = source.splitlines()

    stats = {
        "funcs_total": 0,
        "funcs_typed_return": 0,
        "params_total": 0,
        "params_typed": 0,
        "vars_total": 0,
        "vars_typed": 0,
    }

    has_class_name = any(ln.startswith("class_name ") for ln in lines[:15])
    has_doc = any(ln.startswith("##") for ln in lines[:15])
    if not has_doc:
        findings.append(
            Finding(
                severity="notice",
                rule="godot/module-docstring",
                file=rel_path,
                line=1,
                message="Adicione comentário de documentação `##` no cabeçalho explicando o papel do script.",
                in_pr_diff=bool(changed_lines),
            )
        )
    if not has_class_name and rel_path.startswith("scripts/") and rel_path not in {"scripts/partida.gd", "scripts/controles.gd"}:
        findings.append(
            Finding(
                severity="notice",
                rule="godot/class-name",
                file=rel_path,
                line=1,
                message="Considere definir `class_name` para facilitar tipagem estática em outros scripts.",
                in_pr_diff=bool(changed_lines),
            )
        )

    current_func: str | None = None
    current_func_start = 0
    current_func_indent = 0
    hot_paths = {"_process", "_physics_process", "_draw"}

    def _close_func(end_line: int) -> None:
        if current_func is not None:
            length = end_line - current_func_start
            if length > 80:
                findings.append(
                    Finding(
                        severity="warning",
                        rule="godot/long-function",
                        file=rel_path,
                        line=current_func_start,
                        message=f"Função `{current_func}` tem {length} linhas (> 80); considere extrair helpers menores.",
                        in_pr_diff=any(ln in changed_lines for ln in range(current_func_start, end_line + 1)),
                    )
                )

    for idx, raw in enumerate(lines, start=1):
        stripped = raw.strip()
        tabs = len(raw) - len(raw.lstrip("\t"))
        in_diff = idx in changed_lines

        if stripped and not stripped.startswith("#") and current_func is not None and tabs <= current_func_indent:
            _close_func(idx - 1)
            current_func = None

        m_func = FUNC_DEF_RE.match(raw)
        if m_func:
            if current_func is not None:
                _close_func(idx - 1)
            current_func = m_func.group(2)
            current_func_start = idx
            current_func_indent = len(m_func.group(1))
            params_raw = m_func.group(3).strip()
            ret_type = m_func.group(4)

            stats["funcs_total"] += 1
            if ret_type or current_func == "_init":
                stats["funcs_typed_return"] += 1
            else:
                findings.append(
                    Finding(
                        severity="warning",
                        rule="godot/missing-return-type",
                        file=rel_path,
                        line=idx,
                        message=f"Função `{current_func}` sem tipo de retorno explícito (`-> void` ou tipo).",
                        in_pr_diff=in_diff,
                    )
                )

            if params_raw:
                for p in params_raw.split(","):
                    p_clean = p.strip()
                    if not p_clean:
                        continue
                    stats["params_total"] += 1
                    if ":" in p_clean or ":=" in p_clean:
                        stats["params_typed"] += 1
                    else:
                        p_name = p_clean.split("=")[0].strip()
                        findings.append(
                            Finding(
                                severity="warning",
                                rule="godot/untyped-parameter",
                                file=rel_path,
                                line=idx,
                                message=f"Parâmetro `{p_name}` em `{current_func}` sem anotação de tipo.",
                                in_pr_diff=in_diff,
                            )
                        )
            continue

        # Variable typing check
        if re.match(r"^\t*var\s+", raw):
            stats["vars_total"] += 1
            if UNTYPED_VAR_RE.match(raw):
                var_name = UNTYPED_VAR_RE.match(raw).group(1)  # type: ignore[union-attr]
                findings.append(
                    Finding(
                        severity="notice",
                        rule="godot/untyped-variable",
                        file=rel_path,
                        line=idx,
                        message=f"Variável `{var_name}` usa `=` sem tipo explícito (`:=` ou `: Tipo`).",
                        in_pr_diff=in_diff,
                    )
                )
            else:
                stats["vars_typed"] += 1

        if not stripped or stripped.startswith("#"):
            if TODO_RE.search(raw):
                findings.append(
                    Finding(
                        severity="notice",
                        rule="godot/todo-comment",
                        file=rel_path,
                        line=idx,
                        message=f"Marcador encontrado: `{stripped}`.",
                        in_pr_diff=in_diff,
                    )
                )
            continue

        # Deep nesting inside function
        if current_func is not None and (tabs - current_func_indent) >= 5:
            findings.append(
                Finding(
                    severity="warning",
                    rule="godot/deep-nesting",
                    file=rel_path,
                    line=idx,
                    message=f"Aninhamento profundo ({tabs - current_func_indent} níveis) em `{current_func}`; prefira early returns.",
                    in_pr_diff=in_diff,
                )
            )

        # Debug prints in production scripts
        if rel_path.startswith("scripts/") and PRINT_CALL_RE.search(raw):
            findings.append(
                Finding(
                    severity="warning",
                    rule="godot/debug-print",
                    file=rel_path,
                    line=idx,
                    message="Chamada `print()` encontrada em script de produção; remova ou substitua por logger.",
                    in_pr_diff=in_diff,
                )
            )

        # Hot-path checks
        if current_func in hot_paths:
            if LOAD_CALL_RE.search(raw):
                findings.append(
                    Finding(
                        severity="error",
                        rule="godot/load-in-hot-path",
                        file=rel_path,
                        line=idx,
                        message=f"`load()` dinâmico dentro de `{current_func}` causa engasgos; use `const ... := preload(...)`.",
                        in_pr_diff=in_diff,
                    )
                )
            if current_func == "_draw" and "StyleBoxFlat.new()" in raw:
                findings.append(
                    Finding(
                        severity="warning",
                        rule="godot/alloc-in-draw",
                        file=rel_path,
                        line=idx,
                        message="Alocação de `StyleBoxFlat.new()` dentro de `_draw()`; pré-aloque no `_ready()`.",
                        in_pr_diff=in_diff,
                    )
                )

    if current_func is not None:
        _close_func(len(lines))

    return findings, stats


def parse_gdlint_log(log_path: Path, changed_lines_map: dict[str, set[int]]) -> list[Finding]:
    findings: list[Finding] = []
    if not log_path.exists():
        return findings
    # gdlint line format: path/to/file.gd:123: Error: message (rule-name)
    pat = re.compile(r"^(.+?\.gd):(\d+):\s*(Error|Warning):\s*(.+)$")
    for raw in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = pat.match(raw.strip())
        if not m:
            continue
        fpath, lineno_s, sev_s, msg = m.groups()
        lineno = int(lineno_s)
        fpath_norm = fpath.lstrip("./")
        in_diff = lineno in changed_lines_map.get(fpath_norm, set())
        findings.append(
            Finding(
                severity="error" if sev_s == "Error" else "warning",
                rule="gdlint",
                file=fpath_norm,
                line=lineno,
                message=msg,
                in_pr_diff=in_diff,
            )
        )
    return findings


def audit_project_godot(repo_root: Path) -> list[Finding]:
    findings: list[Finding] = []
    proj = repo_root / "project.godot"
    if not proj.exists():
        return findings
    text = proj.read_text(encoding="utf-8")
    if "gdscript/warnings/" not in text:
        findings.append(
            Finding(
                severity="notice",
                rule="godot/project-warnings",
                file="project.godot",
                line=1,
                message="Considere habilitar warnings estritos do GDScript (ex.: `untyped_declaration`, `unused_variable`) em `project.godot`.",
                in_pr_diff=False,
            )
        )
    return findings


def compute_diff_coverage(cov_data: dict | None, changed_lines_map: dict[str, set[int]]) -> dict[str, object]:
    if not cov_data or not changed_lines_map:
        return {"applicable": False, "changed_exec_lines": 0, "covered_changed_lines": 0, "pct": 100.0, "files": []}

    by_file = {f["file"]: f for f in cov_data.get("files", [])}
    total_changed_exec = 0
    total_changed_cov = 0
    per_file: list[dict[str, object]] = []

    for rel, lines in sorted(changed_lines_map.items()):
        if rel not in by_file:
            continue
        f_cov = by_file[rel]
        covered_set = set(f_cov.get("covered_lines", []))
        uncovered_set = set(f_cov.get("uncovered_lines", []))
        exec_in_diff = sorted(lines & (covered_set | uncovered_set))
        if not exec_in_diff:
            continue
        cov_in_diff = [ln for ln in exec_in_diff if ln in covered_set]
        uncov_in_diff = [ln for ln in exec_in_diff if ln in uncovered_set]
        total_changed_exec += len(exec_in_diff)
        total_changed_cov += len(cov_in_diff)
        pct = len(cov_in_diff) / len(exec_in_diff) * 100.0
        per_file.append(
            {
                "file": rel,
                "changed_exec": len(exec_in_diff),
                "changed_cov": len(cov_in_diff),
                "pct": round(pct, 2),
                "uncovered_lines": uncov_in_diff,
            }
        )

    pct_total = (total_changed_cov / total_changed_exec * 100.0) if total_changed_exec > 0 else 100.0
    return {
        "applicable": total_changed_exec > 0,
        "changed_exec_lines": total_changed_exec,
        "covered_changed_lines": total_changed_cov,
        "pct": round(pct_total, 2),
        "files": per_file,
    }


def emit_github_annotations(findings: list[Finding]) -> None:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        return
    # Emit annotations for PR diff items (and errors anywhere), capped to avoid flooding GitHub UI
    to_emit = [f for f in findings if f.in_pr_diff or f.severity == "error"][:40]
    for f in to_emit:
        level = "error" if f.severity == "error" else ("warning" if f.severity == "warning" else "notice")
        msg = f"[{f.rule}] {f.message}".replace("\n", " ")
        print(f"::{level} file={f.file},line={f.line}::{msg}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Godot 4 Automated Code Review")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument("--coverage-json", default="coverage/coverage.json", help="Path to coverage.json")
    parser.add_argument("--gdlint-log", default="", help="Optional path to gdlint output file")
    parser.add_argument("--gdformat-status", default="unknown", help="Status of gdformat --check (pass/fail/unknown)")
    parser.add_argument("--validate-status", default="unknown", help="Status of Godot script/scene validation")
    parser.add_argument("--base-ref", default="", help="Git base ref for PR diff analysis (e.g. origin/main)")
    parser.add_argument("--out-dir", default="review", help="Output directory for report.md and report.json")
    parser.add_argument("--min-coverage", type=float, default=0.0, help="Minimum total coverage percentage")
    parser.add_argument("--min-diff-coverage", type=float, default=0.0, help="Minimum PR diff coverage percentage")
    parser.add_argument("--fail-on-error", action="store_true", help="Exit 1 if any error-severity finding exists")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    changed_files, changed_lines_map = _git_changed_lines(repo_root, args.base_ref or None)

    all_findings: list[Finding] = []
    agg_stats = {"funcs_total": 0, "funcs_typed_return": 0, "params_total": 0, "params_typed": 0, "vars_total": 0, "vars_typed": 0}

    for gd_file in sorted((repo_root / "scripts").glob("*.gd")):
        rel = gd_file.relative_to(repo_root).as_posix()
        f_list, st = analyze_gdscript(gd_file, rel, changed_lines_map.get(rel, set()))
        all_findings.extend(f_list)
        for k in agg_stats:
            agg_stats[k] += st[k]

    all_findings.extend(audit_project_godot(repo_root))
    if args.gdlint_log:
        all_findings.extend(parse_gdlint_log(Path(args.gdlint_log), changed_lines_map))

    cov_data = None
    cov_path = Path(args.coverage_json)
    if cov_path.exists():
        cov_data = json.loads(cov_path.read_text(encoding="utf-8"))

    diff_cov = compute_diff_coverage(cov_data, changed_lines_map)
    emit_github_annotations(all_findings)

    # Typing health scores
    func_type_pct = (agg_stats["funcs_typed_return"] / agg_stats["funcs_total"] * 100.0) if agg_stats["funcs_total"] else 100.0
    param_type_pct = (agg_stats["params_typed"] / agg_stats["params_total"] * 100.0) if agg_stats["params_total"] else 100.0
    var_type_pct = (agg_stats["vars_typed"] / agg_stats["vars_total"] * 100.0) if agg_stats["vars_total"] else 100.0

    errors = [f for f in all_findings if f.severity == "error"]
    warnings = [f for f in all_findings if f.severity == "warning"]
    notices = [f for f in all_findings if f.severity == "notice"]
    pr_findings = [f for f in all_findings if f.in_pr_diff]

    total_cov_pct = float(cov_data["coverage_pct"]) if cov_data else 0.0

    # Build Markdown PR Review Report
    md: list[str] = [
        "# 🤖 Godot Code Review — BedLion",
        "",
        "## 1. Resumo de Qualidade e Cobertura",
        "",
        "| Indicador | Resultado | Meta / Status |",
        "| :--- | :---: | :---: |",
        f"| Validação Godot (`--headless`) | `{args.validate_status}` | {'✅' if args.validate_status == 'pass' else '⚠️'} |",
        f"| Formatação (`gdformat --check`) | `{args.gdformat_status}` | {'✅' if args.gdformat_status == 'pass' else ('❌' if args.gdformat_status == 'fail' else 'ℹ️')} |",
        f"| Cobertura Total (`scripts/*.gd`) | `{total_cov_pct:.2f}%` | {'✅' if total_cov_pct >= args.min_coverage else '❌'} (mín. {args.min_coverage:.0f}%) |",
    ]
    if diff_cov["applicable"]:
        md.append(
            f"| Cobertura do Diff (PR) | `{diff_cov['pct']:.2f}%` ({diff_cov['covered_changed_lines']}/{diff_cov['changed_exec_lines']}) | {'✅' if float(diff_cov['pct']) >= args.min_diff_coverage else '❌'} (mín. {args.min_diff_coverage:.0f}%) |"
        )
    md.extend(
        [
            f"| Tipagem Estática (Retorno / Params / Vars) | `{func_type_pct:.1f}%` / `{param_type_pct:.1f}%` / `{var_type_pct:.1f}%` | ℹ️ |",
            f"| Achados (Erros / Avisos / Sugestões) | `{len(errors)}` / `{len(warnings)}` / `{len(notices)}` | {'✅' if not errors else '❌'} |",
            "",
        ]
    )

    if diff_cov["applicable"]:
        md.extend(["## 2. Cobertura nas Linhas Alteradas do PR", "", "| Arquivo | Linhas Cobertas | Cobertura Diff | Linhas Sem Cobertura |", "| :--- | :---: | :---: | :--- |"])
        for df in diff_cov["files"]:  # type: ignore[attr-defined]
            uncov_str = ", ".join(str(x) for x in df["uncovered_lines"][:12]) or "—"
            if len(df["uncovered_lines"]) > 12:
                uncov_str += ", ..."
            md.append(f"| `{df['file']}` | {df['changed_cov']}/{df['changed_exec']} | {df['pct']:.1f}% | `{uncov_str}` |")
        md.append("")

    if pr_findings:
        md.extend(["## 3. Achados nas Linhas Alteradas do PR", ""])
        for f in pr_findings[:25]:
            icon = "🔴" if f.severity == "error" else ("🟡" if f.severity == "warning" else "🔵")
            md.append(f"- {icon} **`{f.file}:{f.line}`** (`{f.rule}`): {f.message}")
        if len(pr_findings) > 25:
            md.append(f"- ... e mais {len(pr_findings) - 25} achado(s) no diff.")
        md.append("")

    # Top baseline hotspots (errors & warnings across codebase)
    top_issues = [f for f in all_findings if f.severity in {"error", "warning"} and not f.in_pr_diff][:15]
    if top_issues:
        md.extend(["## 4. Principais Pontos de Atenção no Repositório", ""])
        for f in top_issues:
            icon = "🔴" if f.severity == "error" else "🟡"
            md.append(f"- {icon} **`{f.file}:{f.line}`** (`{f.rule}`): {f.message}")
        md.append("")

    if cov_data:
        low_cov = sorted(cov_data.get("files", []), key=lambda x: float(x["coverage_pct"]))[:8]
        md.extend(["## 5. Arquivos com Menor Cobertura (Oportunidades de Teste)", "", "| Arquivo | Cobertura | Cobertas / Total |", "| :--- | :---: | :---: |"])
        for lf in low_cov:
            md.append(f"| `{lf['file']}` | {float(lf['coverage_pct']):.1f}% | {lf['lines_hit']}/{lf['lines_found']} |")
        md.append("")

    report_md = "\n".join(md)
    (out_dir / "report.md").write_text(report_md, encoding="utf-8")

    report_json = {
        "summary": {
            "total_coverage_pct": total_cov_pct,
            "diff_coverage": diff_cov,
            "typing": agg_stats,
            "errors": len(errors),
            "warnings": len(warnings),
            "notices": len(notices),
            "pr_findings": len(pr_findings),
        },
        "findings": [asdict(f) for f in all_findings],
    }
    (out_dir / "report.json").write_text(json.dumps(report_json, indent=2), encoding="utf-8")

    print(report_md)

    failed = False
    if args.fail_on_error and errors:
        print("ERRO: Code review encontrou falhas críticas (severity=error).", file=sys.stderr)
        failed = True
    if cov_data and total_cov_pct < args.min_coverage:
        print(f"ERRO: Cobertura total {total_cov_pct:.2f}% < {args.min_coverage:.2f}%.", file=sys.stderr)
        failed = True
    if diff_cov["applicable"] and float(diff_cov["pct"]) < args.min_diff_coverage:
        print(f"ERRO: Cobertura do diff {diff_cov['pct']:.2f}% < {args.min_diff_coverage:.2f}%.", file=sys.stderr)
        failed = True

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
