# Step DAG design (0.6.0)

## Concepts

- **Roots** — raw files under `data/` (no producing step). Shown as dashed **data** nodes in the pipeline display; hover for full paths.
- **Steps** — everything else: transforms, tables, figures, and format children.
- **Labels** name the **output** (e.g. `Analysis dataset`, `Table 1`); put how-it-is-built in `description` (Shiny hover + Display title).
- **Outputs** — products of steps under `outputs/`, named after the step id (e.g. `outputs/tab_1.html`, `outputs/construct_analysis_dataset/`). Prefer `outputs:` over deprecated `artifact:`.
- **Parents** — explicit DAG edges. Multi-parent merge nodes are allowed.
- **Format steps** — `type: format`, single `parent:`; run with `format = TRUE` on the parent unless `format = FALSE`. Hidden from the sidebar; no `label:` needed. Still declare explicitly in unified `steps:` yaml (legacy `format:` on replications auto-creates `<id>_format`).

## Running

```r
# Default: live run of the target; immediate parent outputs must exist
run_replication(doi, "tab_1", language = "stata", given = "parents")

# Full upstream pipeline
run_replication(doi, "tab_1", given = "nothing")

# Assume construct_analysis_dataset done; run anything else needed
run_replication(doi, "fig_4", given = "construct_analysis_dataset")

# Opt into reusing existing upstream outputs/ (target still recomputes)
run_replication(doi, "tab_1", force = FALSE)
```

Display / [load_artifact()] use precomputed files under `outputs/`.
[run_replication()] defaults to `force = TRUE` so Run is always live.

## given validation

`given` must be **downward-closed**: if step `C` is assumed complete, every ancestor of `C` must also be in `given` (or be a raw root).

## Engine alternatives

When two steps could produce the same output (e.g. R and Stata), declare one as **`precedent:`** in yaml (future builds validate uniqueness). Until then, list engines in declaration order; first wins.

## Migration

```r
migrate_legacy_steps_yaml("path/to/replication.yml")
```

Keep legacy `prep:` / `replications:` until the deployed Shiny app is updated; do not push migrated study repos until then.
