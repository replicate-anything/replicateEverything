#!/usr/bin/env python3
"""Migrate legacy prep:/replications: blocks to unified steps: in replication.yml."""

from __future__ import annotations

import argparse
import copy
import re
from pathlib import Path

import yaml


def engine_from_code(code: str | None) -> str | None:
    if not code:
        return None
    code = str(code).lower()
    if code.endswith(".do"):
        return "stata"
    if code.endswith(".py") or code.endswith(".ipynb"):
        return "python"
    if code.endswith(".r"):
        return "r"
    return None


def format_specified(entry: dict) -> bool:
    fmt = entry.get("format")
    return fmt is not None and fmt != ""


def normalize_entry(entry: dict) -> dict:
    step = copy.deepcopy(entry)
    step_id = step.pop("id", None)
    if not step_id:
        raise ValueError("step missing id")
    step["id"] = str(step_id)

    typ = str(step.get("type") or "step").lower()
    if typ in ("prep", "pipeline"):
        typ = "transform"
    elif typ not in ("table", "figure", "format", "transform", "step"):
        if not step.get("artifact") and not step.get("output"):
            typ = "transform"
    step["type"] = typ

    parents = step.get("parents") or step.get("requires") or step.get("depends_on") or []
    if parents is None:
        parents = []
    step["parents"] = [str(p) for p in list(parents)]

    artifact = step.get("artifact")
    output = step.get("output")
    outputs = step.get("outputs")
    if outputs is None:
        out_list = []
        if artifact:
            out_list.append(str(artifact))
        if output and str(output) not in out_list:
            out_list.append(str(output))
        if out_list:
            step["outputs"] = out_list
    elif isinstance(outputs, str):
        step["outputs"] = [outputs]

    data = step.get("data")
    if data and not step.get("inputs"):
        if isinstance(data, list):
            step["inputs"] = [str(d) if not str(d).startswith(("data/", "outputs/")) else str(d) for d in data]
            step["inputs"] = [
                d if d.startswith(("data/", "outputs/")) else f"data/{d}" for d in step["inputs"]
            ]
        else:
            d = str(data)
            step["inputs"] = [d if d.startswith(("data/", "outputs/")) else f"data/{d}"]

    if not step.get("engine"):
        eng = engine_from_code(step.get("code"))
        if eng:
            step["engine"] = eng

    if typ == "transform" and not step.get("parents"):
        step["parents"] = []

    if typ in ("table", "figure") and not step.get("parents"):
        step["parents"] = []

    step.pop("make", None)
    step.pop("output", None)
    return step


def format_child(entry: dict) -> dict:
    step_id = entry["id"]
    fmt = entry.get("format")
    child = {
        "id": f"{step_id}_format",
        "type": "format",
        "label": f"{entry.get('label') or step_id} format",
        "parent": step_id,
    }
    if isinstance(fmt, str):
        if fmt.endswith(".R") or fmt.endswith(".r") or "/" in fmt or "\\" in fmt:
            child["code"] = fmt
        else:
            child["format"] = fmt
    else:
        child["format"] = fmt
    return child


def migrate_meta(meta: dict) -> dict:
    if meta.get("steps"):
        return meta

    steps: list[dict] = []
    seen: set[str] = set()

    for prep_entry in meta.get("prep") or []:
        step = normalize_entry(prep_entry)
        step["type"] = "transform"
        if step["id"] in seen:
            raise ValueError(f"duplicate step id: {step['id']}")
        seen.add(step["id"])
        steps.append(step)

    for rep in meta.get("replications") or []:
        step = normalize_entry(rep)
        if step["id"] in seen:
            raise ValueError(f"duplicate step id: {step['id']}")
        seen.add(step["id"])
        steps.append(step)
        if format_specified(rep):
            steps.append(format_child(step))

    if not steps:
        return meta

    out = copy.deepcopy(meta)
    out.pop("prep", None)
    out.pop("replications", None)
    out["steps"] = steps
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    for path in args.paths:
        meta = yaml.safe_load(path.read_text(encoding="utf-8"))
        migrated = migrate_meta(meta)
        if migrated is meta:
            print(f"SKIP {path} (already has steps: or empty)")
            continue
        text = yaml.dump(migrated, sort_keys=False, allow_unicode=True, default_flow_style=False)
        if args.dry_run:
            print(f"DRY RUN {path}\n{text[:500]}...")
        else:
            path.write_text(text, encoding="utf-8")
            print(f"MIGRATED {path}")


if __name__ == "__main__":
    main()
