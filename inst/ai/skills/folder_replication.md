---
name: folder-replication
description: >-
  Set up a folder-backed replication study repo for replicate-anything (data/,
  code/, outputs/, replication.yml with a steps DAG), register a registry stub,
  and validate with replicateEverything and testthat. Use when migrating a classic
  registry paper to an external study repo, onboarding a delivered code/data folder,
  or when the user mentions folder-backed replication, study repo, rep-* DOI repos,
  steps DAG, or step inheritance.
---

# Folder-backed replication study

Turn delivered analysis materials into a **folder-backed study repository** wired to the [replicate-anything registry](https://github.com/replicate-anything/registry) and [replicateEverything](https://github.com/replicate-anything/replicateEverything).

**Not** an R package — use the package-replication skill for package-backed studies.

## Target layout

```
rep-<doi-with-hyphens>/
  replication.yml      # full metadata + unified steps: DAG
  README.md
  code/                # one script per step (transform / table / figure / format)
  data/                # raw inputs only; paths relative to repo root
  outputs/             # step products + display files (tab_1.html, prep_data/*.rds)
  tests/
    testthat.R
    testthat/
      test-<id>.R
```

Legacy repos may still use `prep:` + `replications:` and `artifacts/`; new work
uses **`steps:`** and **`outputs/`** only (replicateEverything 0.6+).

Registry keeps **stub only**:

```
registry/studies/<folder>.yml   # lightweight stub (DOI, title, study_repo link)
```

## Naming conventions

| Item | Rule | Example |
|------|------|---------|
| Registry `folder` | From `index.csv`; often DOI with `/` → `_` | `10.1177_00491241211036161` |
| Study repo name | `rep-` + DOI with `/` → `-` | `rep-10.1177-00491241211036161` |
| GitHub slug | `replicate-anything/<study-repo-name>` | `replicate-anything/rep-10.1177-00491241211036161` |
| Replication ids | `tab_1`, `fig_1`, … | Match `replication.yml` |

## Workflow checklist

Copy and track progress:

**Every study repo must declare `maintainer:` (name + email) and should declare `collections:` (APSR, PED, World Bank, IPI, …) in root `replication.yml`.** These fields copy into the registry stub and `index.csv` (via `build_registry_index()`) for the Studies tab filter and maintainer link.

```
- [ ] 1. Inventory delivered materials (scripts, data, outputs)
- [ ] 2. **Reconstruct the step DAG from the original repo** (README order, file I/O, shared prep) — Step 1b
- [ ] 3. Create GitHub study repo (empty) + local clone as monorepo sibling
- [ ] 4a. **Search all code** for R, Stata, and Python dependencies (Step 4a)
- [ ] 4b. **Write `replication.yml`** — languages, deps, **steps:** DAG, **maintainer**, **collections** (Step 4b)
- [ ] 5. Structure repo: code/, data/, outputs/; add Stata install/probe helpers if needed
- [ ] 6. Refactor code into one script per step; make_<id>() + format_<id>() where needed
- [ ] 7. Build outputs; write outputs/manifest.json
- [ ] 8. Add testthat tests (run_replication + output match)
- [ ] 9. Slim registry stub; run **`build_registry_index()`** so `index.csv` has repo, **collections**, **maintainer**, **languages**
- [ ] 10. Remove code/data from registry study folder (if migrating)
- [ ] 11. Verify replicateEverything + Shiny (Display + Run + system compatibility check)
- [ ] 12. Commit and push study repo + registry
```

## Step 1 — Inventory

For each table/figure identify:

- **id** (`tab_1`, `fig_1`, `prep_data`, …)
- **type** (`transform` | `table` | `figure` | `format`)
- **parents** — which upstream step outputs (or raw `data/` files) this step reads
- **data** / **inputs** paths (raw roots under `data/` or prior `outputs/…`)
- **outputs** — files this step writes under `outputs/`
- **analysis** logic → `make_<id>(data)` in the step script
- **display** logic → `format_<id>(object)` when yaml lists `format:` (often a separate `type: format` child)
- **engine** (`r`, `stata`, `python`) — from file extension or author README
- **dependencies** — note any `library()`, `ssc install`, `import` (full list comes in Step 4a)

## Step 1b — Reconstruct the step DAG from the original repo

**The DAG is not invented in yaml — it is recovered from the author delivery.**

replicateEverything runs steps in dependency order (`parents:` edges). Getting the
graph wrong breaks live Run, Shiny pipeline display, and extension studies that
`inherit:` upstream steps. Before writing `replication.yml`, trace the **actual**
author pipeline.

### Sources to read (in order)

| Source | What to extract |
|--------|-----------------|
| **README.txt / author guide** | Numbered pipeline (step 0 = merge data, step 1 = tables, …) |
| **Master `.do` / driver scripts** | `use`, `merge`, `save`, `esttab using …` — file I/O chain |
| **Per-table/figure scripts** | Which processed `.dta` or CSV each output reads |
| **Notebooks / `(RCODE)_*.R`** | Inputs loaded from `data/raw` vs `data/processed` |
| **Existing outputs in the zip** | Intermediate files authors expect to exist |

### Agent workflow

1. **List raw roots** — files under `data/` that no script in the repo produces (only consumed). These have **no parent step**; cite them in downstream `inputs:` / `data:`.
2. **Walk README order** — each numbered author step becomes one or more `type: transform` steps (or a table/figure if it only produces a display output).
3. **Follow writes** — every `save`, `export`, `write.csv`, `ggsave` becomes an `outputs:` path. Prefer `outputs/<step_id>/…` for intermediates, `outputs/<id>.html` or `.png` for display sinks.
4. **Split shared prep** — if three tables all `use` the same constructed `.dta`, declare **one** transform step and set `parents: [that_step]` on each table (do not duplicate prep inside every table script).
5. **Parallel engines** — when authors ship both Stata and R for the same table, use **separate step ids** (`tab_1`, `tab_1_stata`) with optional `group: tab_1`. They may read different inputs (raw vs cleaned) if that matches the author code.
6. **Format children** — when Display needs HTML/PNG but analysis returns a model or temp file, add `type: format` with `parent: <table_or_figure_id>` (or rely on auto-generated `<id>_format` from legacy migration).
7. **Draw the graph** — sanity-check: every non-root input is either under `data/` or produced by a listed parent; no cycles; `given = "parents"` on a table only requires immediate parents' `outputs/` to exist.

Example (Fearon & Laitin):

```
data/repdata.dta  →  prep_data  →  tab_1 (R, reads outputs/prep_data/…)
                └────────────────→  tab_1_stata (Stata, reads raw data/repdata.dta)
```

Reference repos: `rep-10.1017-S0003055403000534`, `rep-10.1017-s0003055426101749`.

### Step types (0.6+)

| `type` | Role | Shiny sidebar |
|--------|------|---------------|
| `transform` (aliases: `prep`, `pipeline`, `step`) | Build intermediate datasets | Pipeline |
| `table` / `figure` | Analysis + display sink | Tables / Figures |
| `format` | Format parent output for Display | Hidden (runs with `format = TRUE`) |

**Labels** name the **output** (`Table 1`, `Analysis dataset`). Put methodology in `description`.

**Edges:** `parents: [step_a, step_b]` (legacy `requires:` still parsed). Raw files are not parents — list them under `inputs:`.

**Running:**

```r
run_replication(doi, "tab_1", given = "parents")   # default: parent outputs must exist
run_replication(doi, "tab_1", given = "nothing") # run full upstream pipeline first
run_replication(doi, "tab_1", given = "prep_data") # assume prep_data done; run rest
run_replication(doi, "tab_1", force = TRUE)        # re-run even if outputs exist
```

See `inst/docs/step-dag-design.md` in the package for `given` downward-closure rules.

### Extension / reanalysis studies

When a repo reuses another study's prep but replaces analysis:

```yaml
paper:
  extends:
    repo: replicate-anything/rep-10.1017-S0003055403000534
    ref: main
    doi: 10.1017/S0003055403000534
steps:
  - inherit: prep_data
  - id: tab_1
    type: table
    parents: [prep_data]
    code: code/tab_1.R
  - inherit: tab_1_format
    code: code/format_ext.R   # only when path differs from base; same-path code/tab_1.R is auto-detected
```

Only declare steps the extension **uses** (`inherit:` or local `id:`) — not every step from the base repo. Inherited format steps source **extension** code when the inherited `code:` path exists locally (same path as base is enough). Inherited steps run in the **base** checkout; extension steps read base `outputs/`. See vignette `reanalysis-studies` and `inst/docs/step-inheritance.md`.

## Step 2 — Create the study repository

**GitHub:** create an empty repo under `replicate-anything` (no README if you will push an existing tree).

**This machine:** `gh` may be unavailable. Alternatives:

- GitHub web UI → New repository
- Or after local `git init`, add remote and push once the empty repo exists

```bash
cd rep-<doi-hyphenated>
git init -b main
git remote add origin https://github.com/replicate-anything/rep-<doi-hyphenated>.git
```

Place the folder as a **sibling** of `registry/` and `replicateEverything/` in the monorepo for local dev.

## Step 4 — `replication.yml` (dependency search + construction)

**`replication.yml` is the contract** between the study repo and replicateEverything. Shiny, live Run, and **Check system compatibility** read only what you declare here — they do not guess study-specific packages or pipeline order. **Infer the step DAG from the original repo (Step 1b), search the code for dependencies (Step 4a), then write yaml (Step 4b).**

### Step 4a — Search for all libraries and dependencies

Before drafting yaml, **search the entire study tree** (delivered folder and/or refactored `code/`) and collect every external dependency. Do not rely on memory or a single main script.

**Agent rule:** run ripgrep (or equivalent) across `code/`, `data/`, notebooks, and the author README; deduplicate; map each hit to the correct yaml field (R vs Stata vs Python). Re-run the search after refactoring — new `library()` / `import` calls often appear when scripts are split.

| Engine | Search patterns (examples) | Yaml destination |
|--------|---------------------------|------------------|
| **R** | `library(`, `require(`, `requireNamespace(`, `::` on package names | `paper.dependencies:` (study-wide CRAN list) |
| **Stata** | `ssc install`, `net install`, `ado install`, `github install`; commands like `reghdfe`, `esttab`, `eststo`, `ftools`, `ivreg2`, `outreg2` | `stata_packages:` (study-wide SSC ado names) |
| **Python** | `^import `, `^from ` in `.py`; notebook `pip install`; `requirements.txt` | `python_dependencies:` (study-wide PyPI names) |
| **All** | Author README / `README.txt` “Requirements”, “Software”, numbered install steps | Cross-check; README often lists Stata SSC stacks authors forgot to script |

Example searches (adjust paths to the study):

```bash
# R packages
rg -n "library\\(|require\\(|requireNamespace\\(" code/ --glob "*.{R,r}"

# Stata user-written commands and installs
rg -n "ssc install|net install|ado install|github install" code/ --glob "*.do"
rg -n "\\b(reghdfe|esttab|eststo|ftools|ivreg2|outreg2|reghdfe|xttabond)\\b" code/ --glob "*.do"

# Python
rg -n "^(import |from )" code/ --glob "*.py"
rg -n "pip install|!pip" code/ --glob "*.{py,ipynb}"
```

**Also check:** `DESCRIPTION` (if migrating from an R package), `requirements.txt`, `renv.lock`, `environment.yml`, and `install_*.do` / `install_*.R` the authors shipped.

**Deduplicate into three lists:**

1. **R (CRAN)** — package names only (not Stata ado names).
2. **Stata (SSC)** — ado command names for `stata_packages:` (e.g. `reghdfe`, `estout`, `ftools`). When **`reghdfe` appears anywhere in `.do` files, also list `require`** — SSC `reghdfe` 6.x depends on it and tables fail at runtime without it even when `help reghdfe` works. replicateEverything auto-installs from SSC and auto-probes (`which` + `help`; refreshes the `ftools` / `reghdfe` / `require` stack when needed).
3. **Python (PyPI)** — distribution names (`scikit-learn`, not `sklearn`).

**Do not** put Stata ado names in `paper.dependencies` or R `dependencies:` — replicateEverything installs CRAN packages for R only.

### Step 4b — Construct `replication.yml`

Use the inventory from Step 4a and the DAG from Step 1b. **Declare languages explicitly** so Shiny system compatibility knows what to probe.

**Minimal full study (unified `steps:` block):**

```yaml
paper:
  doi: https://doi.org/10.1177/00491241211036161
  title: "..."
  journal: "..."
  year: 2022
  authors: "..."
  study_folder: rep-10.1177-00491241211036161
  dependencies:
    - ggplot2
    - haven

repo: replicate-anything/rep-10.1177-00491241211036161

maintainer:
  name: Jane Maintainer
  email: maintainer@example.org

collections:
  - IPI

languages:
  - r
  - stata

python_dependencies:
  - pandas

stata_packages:
  - reghdfe
  - require
  - estout

steps:
  - id: build_data
    type: transform
    label: Build analysis dataset
    parents: []
    inputs:
      - data/raw/survey.dta
    outputs:
      - outputs/build_data/analysis.dta
    engine: stata
    code: code/steps/build_data.do

  - id: fig_1
    type: figure
    label: Figure 1
    description: Short caption for Shiny
    parents:
      - build_data
    engine: r
    inputs:
      - outputs/build_data/analysis.dta
    code: code/fig_1.R
    format: format_fig_1
    outputs:
      - outputs/fig_1.png
    artifact: outputs/fig_1.png

  - id: fig_1_format
    type: format
    parent: fig_1
    code: code/fig_1.R

  - id: tab_1
    type: table
    label: Table 1
    parents:
      - build_data
    engine: stata
    inputs:
      - outputs/build_data/analysis.dta
    code: code/tables/tab_1.do
    format: code/helpers/format_stata.R
    outputs:
      - outputs/tab_1.html
    artifact: outputs/tab_1.html
```

Legacy layout (`prep:` + `replications:` + `artifacts/`) still loads via
`compile_steps_from_legacy()` but **new studies must use `steps:` + `outputs/`**.

**Construction rules:**

| Yaml field | Source |
|------------|--------|
| `steps:` | **Step 1b** — DAG from original repo (parents, inputs, outputs) |
| `languages:` | Union of engines across all steps |
| `paper.dependencies` | All unique CRAN packages from R scripts and format helpers |
| `python_dependencies:` | All unique PyPI names from Python scripts/notebooks |
| `stata_packages:` | User-written ado names from `.do` files — include **`require`** whenever **`reghdfe`** is listed |
| `maintainer:` | **Required** — name + email |
| `collections:` | Tags copied to registry `index.csv` |
| `steps[].parents` | Immediate upstream steps (not raw `data/` files) |
| `steps[].outputs` | Files this step produces under `outputs/` |
| `steps[].artifact` | Primary display file for tables/figures (= main `outputs/` path) |
| `steps[].engine` | `r`, `stata`, or `python` — must match `code:` extension |
| `steps[].dependencies` | **R only** — extra CRAN packages for that step |

**Tables with external data:** add `data:` and/or `inputs:` on the step row.

**Shiny Server (large files):** place files at `data/<study_folder>/<basename>` beside the app. Use the study repo folder name (`paper.study_folder` or `rep-<doi-with-hyphens>`), not the registry stub folder (`10.x_y`).

**Tables without format step:** omit `format:`; `artifact:` is usually `.html` from analysis output.

**Validate yaml before moving on:**

```r
yaml::read_yaml("replication.yml")
replicateEverything::describe_study_dag(meta)  # after parsing — sanity-check graph
replicateEverything::check_study_compatibility("<doi>")
replicateEverything::install_study_dependencies("<doi>")
```

### Step 4c — replicateEverything conventions (no package hardcoding)

The **replicateEverything** package reads study metadata only — it does not embed study-specific package names or install commands. Every folder-backed study must declare what the package needs in **replication.yml** and helper scripts under **code/helpers/**.

### Required for all folder-backed studies

| Item | Location | Purpose |
|------|----------|---------|
| Full `replication.yml` | repo root | `paper:`, **`steps:`** DAG, `repo:` slug |
| `languages:` | top-level (recommended) | `r`, `stata`, `python` — used by system compatibility check |
| `code:` per step | `code/<id>.R` or `.do` | Live Run executes this |
| `artifact:` / `outputs:` per step | `outputs/<id>.{html,png,…}` | Shiny Display tab |
| Registry stub | `registry/studies/<folder>.yml` | Points to study repo; not the full yaml |

If `languages:` is omitted, engines are inferred from `engine:` / `code:` extensions on steps.

**System compatibility** (Shiny button or `study_system_compatibility()`) reads only yaml declarations and probes this machine — no installs. Declare everything explicitly:

```yaml
languages:
  - r
  - stata
  - python

paper:
  dependencies:
    - ggplot2
    - haven

python_dependencies:
  - pandas

stata_packages:
  - reghdfe
  - estout

stata_deps_probe: code/helpers/probe_stata_deps.do   # optional
stata_dependencies:
  - code/helpers/install_stata_deps.do              # optional
```

### Package-backed vs folder-backed (maintainer API)

Both study types use the **same maintainer functions** for dependency setup:

| Task | Function |
|------|----------|
| Probe machine | `check_study_compatibility(doi)` |
| Install deps | `install_study_dependencies(doi)` |
| Registry bulk install | `install_registry_dependencies()` |
| Layout | `replication_kind(meta)` → `"folder"` or `"package"` |
| Artifact root | `study_output_dir(meta, ctx)` — **`outputs/`** for folder studies |

**Build** still uses kind-specific builders: `build_study_artifacts()` (folder) vs `build_package_artifacts()` (package). Declare the same yaml fields (`languages:`, `paper.dependencies`, `python_dependencies:`, `stata_*`) in both layouts.

### Stata studies — declare packages in yaml (default)

**Most studies only need a list:**

```yaml
languages:
  - stata

stata_packages:
  - reghdfe
  - require
  - estout
  - ftools
```

replicateEverything **auto-generates** maintainer install and compatibility probe from this list:
- `ssc install <pkg>, replace` for each package (`estout` → probes `eststo`)
- `ftools, compile` when `ftools` or `reghdfe` is listed
- Installs **`require`** when `reghdfe` is listed (SSC 6.x dependency)
- Refreshes broken GitHub `reghdfe` 6.x stacks on shared servers

Maintainers: `install_study_dependencies(doi)` once. Live Run and Shiny probe only.

| Field | When to use |
|-------|-------------|
| `stata_packages:` | **Default** — SSC ado command names from your `.do` files |
| `stata_deps_probe:` | Optional custom check-only `.do` (rare; e.g. non-SSC probes) |
| `stata_dependencies:` | Optional custom install `.do` (rare; GitHub-only stacks, exotic pins) |

**Do not** call install scripts from table/prep runners or `init_study_paths.do`.

### R / Python replications

| Field | Example | Purpose |
|-------|---------|-------------|
| `languages:` | `[r, python]` | Engines for system compatibility check |
| `dependencies:` (paper) | `[ggplot2]` | R CRAN packages |
| `python_dependencies:` | `[pandas]` | Pip packages (study-wide; preferred over per-entry lists) |
| `code:` ending in `.py` / `.ipynb` | `code/fig_1.py` | Python engine |
| `format:` | `format_fig_1` or `code/helpers/format_stata.R` | Display step when artifact is HTML/PNG |

### Outputs and data (summary)

- **`outputs:`** — canonical step products; **`artifact:`** is the display path Shiny reads (usually the primary html/png under `outputs/`).
- **Data ≤ 50 MB** — commit under `data/` so clones work for live Run.
- **Data > 50 MB** — gitignore by explicit filename; stage under `registry/data/<folder>/`; rely on precomputed `outputs/` for Display when absent locally.

### Checklist before opening a PR

```
- [ ] Step 1b: DAG traced from author README / scripts; parents match real file I/O
- [ ] Step 4a: dependency search re-run after final code layout
- [ ] replication.yml: languages + deps + steps: complete; each code:/inputs:/outputs: path exists
- [ ] describe_study_dag() / Shiny pipeline view looks correct
- [ ] check_study_compatibility() passes (or documents expected gaps)
- [ ] outputs/ committed; manifest if used
- [ ] Registry stub + index.csv repo column updated
- [ ] study tests: testthat::test_dir("tests/testthat")
- [ ] audit_everything() or package tests pass with fixture study
```

## Step 5 — Data files (git vs. large files)

Live replication (the Shiny **Run** button, and any fresh clone) works from a
**clone of the study repo**. If an input file is not committed, the clone lacks
it and Stata/R/Python steps fail with "file not found". So **commit data by
default** — do not blanket-gitignore `data/`.

Rule, keyed to GitHub's limits (soft warning at 50 MB, hard reject at 100 MB):

| File size | Handling |
|-----------|----------|
| **≤ 50 MB** | Commit it in the study repo under `data/`. Live runs work from any clone. |
| **> 50 MB** | Do **not** put it in git. Stage it under the registry data area (`registry/data/<folder>/`) for manual deploy to the server, and document its source (URL/DOI/Dataverse) in `data/raw/README.md`. Live runs from a bare clone won't have it; rely on precomputed `outputs/` instead. |

Recommended `.gitignore` (keep data; exclude only logs, staging, and oversized inputs which you list explicitly):

```gitignore
.Rproj.user/
*.log
outputs/staging/

# Commit data so live replication works from a clone. Only exclude inputs
# too large for git (>50 MB): keep those out, stage under registry/data/<folder>/,
# and deploy to the server manually. List any such files explicitly below.
```

Do **not** use blanket patterns like `data/raw/*.dta` — that silently drops all
inputs and breaks live replication.

## Step 6 — Code scripts (`code/<id>.R` or `.do`)

Each step script must be **self-contained**:

1. Header comment with study repo URL
2. `library(...)` for dependencies
3. `make_<id>(data)` — analysis; returns model, data.frame, ggplot, etc.
4. `format_<id>(object)` — display step when yaml lists `format: format_<id>`
5. Footer that runs locally: `make_<id>(...) |> format_<id>()` or load data from declared `inputs:`

**Split rule:** if Shiny stores **display** files (HTML/PNG), analysis output should be the **object** passed to `format_*`, not the formatted HTML (unless no format step).

Transform steps write to paths declared in `outputs:` (under `outputs/<step_id>/`).

Reference: `rep-10.1017-S0003055403000534/code/tab_1.R`, `rep-10.1177-00491241211036161/code/fig_1.R`.

## Step 7 — Build outputs

Build from monorepo:

```r
configure_local_monorepo("path/to/replicate_everything")
build_study_artifacts("<doi-or-handle>", install_deps = TRUE)
# Or per step:
run_replication("<doi>", "tab_1", given = "nothing", format = TRUE, install_deps = TRUE)
```

Commit under `outputs/`:

- Figures → `outputs/fig_N.png`
- Formatted tables → `outputs/tab_N.html`
- Intermediates → `outputs/<step_id>/…`
- `outputs/manifest.json` — from `build_study_artifacts()` or hand-written

`registry/scripts/build_artifacts.R` **skips** folder-backed papers.

## Step 8 — Registry stub

`registry/studies/<folder>.yml` only (flat file, not a subfolder):

```yaml
paper:
  doi: https://doi.org/...
  title: "..."
  materials: folder
  study_repo: replicate-anything/rep-<doi-hyphenated>
  study_folder: rep-<doi-hyphenated>
  study_ref: main
repo: replicate-anything/rep-<doi-hyphenated>
```

Update `registry/index.csv` — set `repo` column to the study slug (not `replicate-anything/registry`).

Delete `code/`, `data/`, `outputs/` under the registry paper folder.

## Step 9 — Tests (`tests/testthat/`)

Use **explicit** `testthat::` prefixes. Pattern per replication:

```r
DOI <- "10.1177/00491241211036161"
WHAT <- "fig_1"
FOLDER <- "10.1177_00491241211036161"
STUDY_REPO <- "replicate-anything/rep-10.1177-00491241211036161"

# run_replication returns analysis object
replicateEverything::run_replication(DOI, WHAT)

# With format when yaml defines format_*
replicateEverything::run_replication(DOI, WHAT, format = TRUE)

# Compare to committed output: HTML normalize or PNG md5 after ggsave(8,6,150)
replicateEverything::run_replication(DOI, WHAT, given = "parents", format = TRUE)
```

Configure options in tests:

```r
options(
  replicateEverything.registry_root = "<path>/registry",
  replicateEverything.index = local_index,  # row with repo = STUDY_REPO
  replicateEverything.use_sibling_packages = TRUE,
  replicateEverything.study_folders_root = "<monorepo-root>"
)
```

Run: `testthat::test_dir("tests/testthat")` from study repo root.

## Step 10 — Verification checks

Run in order; stop on failure.

| Check | Command / action |
|-------|------------------|
| Yaml parses | `yaml::read_yaml("replication.yml")` |
| Each `code:` file exists | `file.exists()` |
| Each `data:` file exists | if specified |
| `run_replication` | `replicateEverything::run_replication(doi, id)` |
| Formatted output | `format = TRUE` when `format:` in yaml |
| Artifact load | `load_artifact(doi, id)` with sibling options |
| Live vs artifact | study `testthat` tests |
| Registry stub | `is_folder_study_replication(meta)` TRUE |
| Shiny | load study; Display + Code tabs |
| build_artifacts skip | folder paper skipped in registry script |

```r
replicateEverything::validate_artifact(doi, "fig_1", folder = "<registry-folder>")
replicateEverything::render_for_display(doi, "fig_1", folder = "<registry-folder>")
```

## Step 11 — Commit and push

Two repositories:

1. **Study repo** — all materials + tests
2. **registry** — stub, `index.csv`, removed materials

```bash
# study repo
git add -A && git commit -m "Add folder-backed replication materials"
git push -u origin main

# registry
git add studies/<folder> index.csv
git commit -m "Point <folder> to folder-backed study repo"
git push origin main
```

## Migrating from classic registry

1. Copy `replication.yml`, `code/`, `data/`, `outputs/` from legacy `registry/papers/<folder>/` (or a materialized study folder) to new study repo
2. Ensure study `replication.yml` is the **full** copy with **`steps:`** DAG, not the registry stub
3. Migrate legacy `prep:`/`replications:` to `steps:` with `migrate_legacy_steps_yaml()` if needed
3. Download any gitignored/large data from GitHub raw if missing locally
4. Follow steps 6–9 above

**Examples:** `rep-10.1017-S0003055403000534` (Fearon & Laitin), `rep-10.1177-00491241211036161` (Bounding Causes).

## replicateEverything routing (for debugging)

- `paper.materials: folder` or `index.csv` `repo` ≠ `replicate-anything/registry` → folder-backed
- Materials resolve from sibling `rep-*` folder or `raw.githubusercontent.com/<study-repo>/main/`
- Registry stub always under `registry/studies/<folder>.yml`

See `registry/guides/folder-replication.md` in the monorepo.

## Registry `index.csv` columns

When merging a study row into [registry/index.csv](https://github.com/replicate-anything/registry/blob/main/index.csv), **`maintainer`**, **`collections`**, and **`languages`** live in the registry stub yaml (`studies/<folder>.yml`) copied from the study repo. Rebuild the full index with `build_registry_index(registry_root)` — no fetch from individual study repos required.

| Column | Source |
|--------|--------|
| `collections` | Pipe-separated tags from stub `collections:` (`APSR\|PED`) |
| `maintainer_name`, `maintainer_email` | stub `maintainer:` block |
| `languages` | Semicolon-separated engines from stub `languages:` |

`prepare_folder_paper()` / `write_folder_registry_stub()` copy these fields into the study's `registry/replication.yml`. **Every new contribution must name a maintainer** — do not leave these blank.

## Common pitfalls

- **Inventing the DAG without reading the author repo** — wrong `parents:` breaks Run and inheritance; always trace README + file I/O first (Step 1b)
- **Skipping Step 4a** — yaml missing `reghdfe`, `require`, `haven`, or `pandas` because only the main script was read
- **`reghdfe` without `require`** — probe can pass while table code fails at runtime with `r(9)` on shared servers
- **No maintainer** — every study repo needs `maintainer:` (name + email)
- **Stata names in `paper.dependencies`** — use `stata_packages:` instead
- Putting the **stub** yaml in the study repo (must be **full** yaml with `steps:`)
- Forgetting to update `index.csv` `repo` column
- **`artifacts/` instead of `outputs/`** on new studies (0.6+)
- Missing `format_*` when display file is HTML/PNG but analysis returns raw models
- Extension study listing every base step — only `inherit:` / local steps belong in the extension yaml
- Tests without `replicateEverything.index` override for the new `repo` slug
