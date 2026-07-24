# Step DAG design (introduced 0.6.0; hard-cut to `steps:`-only in 0.7.0)

## Concepts

- **Roots** — raw files under `data/` (no producing step). Shown as dashed **data** nodes in the pipeline display; hover for full paths.
- **Steps** — everything else: transforms, tables, figures, and format children.
- **Labels** name the **output** (e.g. `Analysis dataset`, `Table 1`); put how-it-is-built in `description` (Shiny hover + Display title).
- **Outputs** — products of steps under `outputs/`, named after the step id (e.g. `outputs/tab_1.html`, `outputs/construct_analysis_dataset/`). `outputs:` only — `artifact:` / `output:` / `stata_output:` are a hard error.
- **Parents** — explicit DAG edges via `parents:` only (`requires:` / `depends_on:` are a hard error). Multi-parent merge nodes are allowed.
- **Format steps** — `type: format`, single `parent:`; run with `format = TRUE` on the parent unless `format = FALSE`. Hidden from the sidebar; no `label:` needed. Always declare explicitly in `steps:` yaml.

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

There is no automated migrator. `prep:` / `replications:` blocks are a hard error
as of replicateEverything 0.7 (`normalize_study_steps()` stops with "Legacy prep: /
replications: blocks are not supported."). Hand-convert any surviving legacy yaml
to a single `steps:` DAG (`parents:` / `outputs:` only) before deploying.
