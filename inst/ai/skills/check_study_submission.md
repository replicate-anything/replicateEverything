---
name: check-study-submission
description: >-
  Review a replicateEverything study submission before registry/Shiny: diagnose
  "no steps" / yaml hard errors, empty folders, unnecessary material, missing
  outputs, and contributor checklist gaps. Use when reviewing PRs, contributor
  deliveries, Shiny "no steps" / "no replications" errors, or pre-sync audits.
---

# Check a study submission

Maintainer / review pass for a folder-backed (or package-backed) study before
Shiny and registry sync. Companion to `folder_replication.md` and
`include_study_in_registry.md` — those teach how to build; this teaches how to
**reject or request fixes**.

**Gold shape:** `rep-template/`. Prefer keeping author code/data in the original
deposit (or Pattern B Dataverse access → `outputs/`) and pointing at it from yaml —
do not copy wholesale archives into the study repo. OpenICPSR: see
`openicpsr_to_replicateEverything.md` (commit needed inputs only).

## Quick diagnosis: Shiny says "no steps" / "no replications"

The study yaml often **does** list `steps:` — Shiny still fails when the package
cannot **normalize** them, or never fetches the study yaml.

| Cause | How to confirm | Fix |
|-------|----------------|-----|
| Deprecated `artifact:` / `output:` / `stata_output:` on a step | Grep yaml; or `normalize_study_steps(yaml::read_yaml("replication.yml"))` errors with `use outputs: only` | Delete those keys; keep `outputs:` only |
| Legacy `prep:` / `replications:` / `requires:` / `depends_on:` | Same call hard-errors | Convert to unified `steps:` + `parents:` |
| Empty `parents: []` | Grep | Omit `parents` on roots (style; usually not fatal) |
| Registry stub only (no enrichment) | Stub under `registry/studies/` has no `steps:`; study repo missing / private / wrong `repo:` | Push public study repo; set `repo:` / `paper.study_repo`; ensure raw `replication.yml` fetchable |
| Private / 404 / network fetch failure | `list_replications()` / Shiny message mentions HTTP 404/403 or network error for the study `replication.yml` URL | Push public study repo; fix `repo:` / `study_ref` |
| Yaml normalize error (e.g. `artifact:`) | Package normalize message surfaced (not swallowed into empty index) | Fix hard-error fields above; re-run `list_replications("local")` |
| Genuinely empty stub | Message says fetched yaml has no `steps:` block | Add steps to study yaml |

```r
# From study repo root — must succeed before any Shiny claim
yaml::read_yaml("replication.yml")
list_replications("local")
describe_study_dag("local")
```

If `list_replications("local")` fails with `uses artifact:; use outputs: only`, that
is the Shiny blocker — not a missing `steps:` block.

## Submission review checklist

Run through in order; stop on hard blockers.

### A. Yaml contract (hard blockers)

```
- [ ] Non-empty `steps:` DAG; no `prep:` / `replications:`
- [ ] No `artifact:` / `output:` / `stata_output:` / `requires:` / `depends_on:`
- [ ] `outputs:` on every product step; omit empty `parents: []`
- [ ] `maintainer:` name + email filled (not blank keys)
- [ ] `collections:` present when known (e.g. APSR)
- [ ] `repo:` / study_folder / languages declared
- [ ] Format children: `type: format` + `parent:` when Display needs `format_*` (no unused `label:`)
- [ ] `list_replications("local")` and `describe_study_dag("local")` succeed
```

### B. Materials lean-ness / surgical pulls

Ideal: **yaml points at what is needed**; do not ship unused deposit material;
**never** download a full Dataverse zip when file ids suffice.

```
- [ ] No ethics / instruments / questionnaires / appendix-only blobs unless a declared step needs them
- [ ] **Surgical pulls:** file-id / `?format=original` only — no `archive_original` / full DVN zip unless Pattern C justified in README
- [ ] Prefer Pattern B access → `outputs/` (or Pattern A materialize when fetch is not a claimed product) over committing raw when file ids exist
- [ ] OpenICPSR / no file API: commit **only** yaml-declared inputs; full unzip stays in `original_studies/` — no unused deposit bulk
- [ ] Prefer package `fetch_dataverse_file()` / `engine: dataverse` — no study-local `httr::GET` / `download.file` download helpers
- [ ] Prefer sourcing author scripts in place (Pattern C) over rewriting when scripts are standalone; still use file-id manifest rows when possible
- [ ] For monolithic `.Rmd` only: thin `make_*` extracts are OK — document the Rmd chunk mapping in README
- [ ] No empty directories (no `data/raw/` with only a placeholder README if nothing is committed there — document fetch in root README instead, or commit ≤50 MB data)
- [ ] No study-local `registry/` handoff
- [ ] No scratch / staging / deposit cache committed (`outputs/deposit/`, `outputs/staging/` gitignored)
```

### B2. Incomplete / blocked steps

**DAG membership:** put a step in `steps:` only if it is a **replication claim**
(Display / audit). Proprietary prep or other blocked stages that are **not** on
the path to a claimed output belong in README / study popup — **not** as orphan
Unavailable nodes.

**Shiny UX (claimed but unavailable):** show Code as usual; replace Run with a
**padlock** (data_unavailable) or **hammer/tool** (requires_engine / audit
missing-engine skip) that opens the availability message on click. Do not add a
separate Unavailable badge or strikethrough when the Run-slot icon conveys the
gap. Studies list shows the same padlock/hammer next to language icons.

```
- [ ] Steps that cannot run declare `incomplete: true` (audit must **skip** them — not fail)
- [ ] Engine gaps: `requires_engine:` + `blocked_reason:`; check deposit for precomputed gold before concluding unavailable
- [ ] Proprietary / restricted data: `data_unavailable: proprietary` (+ `blocked_reason:`) — distinct from engine-missing and from audit fail/timeout
- [ ] No orphan Unavailable nodes — blocked prep off the claim path stays in docs/popup, not `steps:`
- [ ] Wrapper-granularity DAG (README tables) — not one node per unused micro-script
- [ ] Partial-replication popup drivers present when incomplete steps exist (`requires_engine` / `data_unavailable` / counts)
- [ ] Shiny Run slot: padlock for `data_unavailable`, hammer for missing-engine (not Unavailable row badges)
```

Grep helpers for heaviness (from study root):

```bash
rg -n "api/access/dataset|:persistentId|archive_original|download_dataverse_dataset_archive" .
rg -n "httr::GET|download\\.file\\(" code/
rg -n "get_dataframe_by_name" code/
git ls-files "data/**" "outputs/**/*.dta" "outputs/**/*.csv" 2>/dev/null | head
```

### C. Outputs and Display

```
- [ ] Every **runnable** table/figure step has a committed display sink under `outputs/` (`.html` / `.png`)
- [ ] Claimed Dataverse access steps (`engine: dataverse`) have `file_id` + `outputs:` (Display uses yaml summary; binary may stay gitignored)
- [ ] Incomplete / `data_unavailable` / `requires_engine` steps may lack sinks — that is expected; do not force-bake them
- [ ] `check_and_bake_study` / `check_display_sink_rows` would fail if Display would show “not on disk yet” for a non-gap step
- [ ] `outputs/manifest.json` matches files that actually exist
- [ ] Intermediate RDS/DTA under `outputs/<step_id>/` either committed (if needed for `given = "parents"`) or rebuildable via DAG
- [ ] `build_study_outputs()` / `check_and_bake_study(".")` clean (incomplete steps skipped)
```

### D. Code conventions

```
- [ ] Pure `make_<id>()` / `format_<id>()` — interactive `sys.nframe()` footers optional, not required
- [ ] Analysis vs format split where Display needs it
- [ ] `source()` / `do` links resolve (`check_replication()` → code_links)
- [ ] Dependencies searched (Step 4a) and declared (`paper.dependencies`, `stata_packages`, `python_dependencies`)
- [ ] Tests call package APIs (`run_replication` / `load_artifact`), not only raw `source()`
```

### E. Registry readiness

```
- [ ] Study repo pushed and **public** (or otherwise fetchable by the Shiny host)
- [ ] Contributor: `check_and_bake_study(".")` — no study-local stub
- [ ] Maintainer: `sync_study_to_registry()` + `build_registry_index()` / `refresh_registry()`
- [ ] `index.csv` has repo, collections, maintainer_*, languages (never hand-thin the CSV)
```

## Reviewer commands

```r
library(replicateEverything)
setwd("path/to/rep-…")

yaml::read_yaml("replication.yml")
list_replications("local", include = "all")
describe_study_dag("local")
check_replication("local")          # or doi / path
check_and_bake_study(".", build_artifacts = TRUE)
```

Grep helpers (from study root):

```bash
rg -n "^\s*(artifact|output|stata_output|requires|depends_on):" replication.yml
rg -n "parents:\s*\[\s*\]" replication.yml
rg -n "sys\.nframe\(\)" code/
```

## Contributor feedback tone

- Lead with **blockers** that break Shiny / normalize (usually 1–3 bullets).
- Keep secondary style notes short (footers, empty folders, README drift).
- Point at `rep-template` and `check_and_bake_study(".")` as the pre-submit gate.
- Do not invent DAG changes without tracing author I/O (`folder_replication.md` Step 1b).
