---
name: folder-replication
description: >-
  Set up a folder-backed replication study repo for replicate-anything (data/,
  code/, artifacts/, replication.yml), register a registry stub, and validate
  with replicateEverything and testthat. Use when migrating a classic registry
  paper to an external study repo, onboarding a delivered code/data folder, or
  when the user mentions folder-backed replication, study repo, or rep-* DOI repos.
---

# Folder-backed replication study

Turn delivered analysis materials into a **folder-backed study repository** wired to the [replicate-anything registry](https://github.com/replicate-anything/registry) and [replicateEverything](https://github.com/replicate-anything/replicateEverything).

**Not** an R package — use the package-replication skill for package-backed studies.

## Target layout

```
rep-<doi-with-hyphens>/
  replication.yml      # full metadata + replications list
  README.md
  code/                # one script per table/figure (make_* + format_*)
  data/                # optional; paths relative to repo root
  artifacts/           # precomputed display files + manifest.json
  tests/
    testthat.R
    testthat/
      test-<id>.R
```

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

```
- [ ] 1. Inventory delivered materials (scripts, data, outputs)
- [ ] 2. Create GitHub study repo (empty) + local clone as monorepo sibling
- [ ] 3a. **Search all code** for R, Stata, and Python dependencies (Step 3a)
- [ ] 3b. **Write `replication.yml`** — languages, deps, prep, replications (Step 3b)
- [ ] 4. Structure repo: code/, data/, artifacts/; add Stata install/probe helpers if needed
- [ ] 5. Refactor code into make_<id>() + format_<id>() per replication
- [ ] 6. Build artifacts; write artifacts/manifest.json
- [ ] 7. Add testthat tests (run_replication + artifact match)
- [ ] 8. Slim registry stub; update index.csv repo column
- [ ] 9. Remove code/data/artifacts from registry study folder (if migrating)
- [ ] 10. Verify replicateEverything + Shiny (Display + Run + system compatibility check)
- [ ] 11. Commit and push study repo + registry
```

## Step 1 — Inventory

For each table/figure identify:

- **id** (`tab_1`, `fig_1`)
- **type** (`table` | `figure`)
- **data** paths (or none if generated in code)
- **analysis** logic → `make_<id>(data)`
- **display** logic → `format_<id>(object)` (HTML table, ggplot, etc.)
- **engine** (`r`, `stata`, `python`) — from file extension or author README
- **dependencies** — note any `library()`, `ssc install`, `import` (full list comes in Step 3a)

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

## Step 3 — `replication.yml` (dependency search + construction)

**`replication.yml` is the contract** between the study repo and replicateEverything. Shiny, live Run, and **Check system compatibility** read only what you declare here — they do not guess study-specific packages. **Always search the code first, then write the yaml.**

### Step 3a — Search for all libraries and dependencies

Before drafting yaml, **search the entire study tree** (delivered folder and/or refactored `code/`) and collect every external dependency. Do not rely on memory or a single main script.

**Agent rule:** run ripgrep (or equivalent) across `code/`, `data/`, notebooks, and the author README; deduplicate; map each hit to the correct yaml field (R vs Stata vs Python). Re-run the search after refactoring — new `library()` / `import` calls often appear when scripts are split.

| Engine | Search patterns (examples) | Yaml destination |
|--------|---------------------------|------------------|
| **R** | `library(`, `require(`, `requireNamespace(`, `::` on package names | `paper.dependencies:` (study-wide CRAN list) |
| **Stata** | `ssc install`, `net install`, `ado install`, `github install`; commands like `reghdfe`, `esttab`, `eststo`, `ftools`, `ivreg2`, `reghdfe`, `outreg2` | `stata_packages:` + `code/helpers/install_stata_deps.do` + `stata_deps_probe:` |
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
2. **Stata (SSC/GitHub)** — ado names for `stata_packages:`; full install lines go in `install_stata_deps.do`.
3. **Python (PyPI)** — distribution names (`scikit-learn`, not `sklearn`).

**Do not** put Stata ado names in `paper.dependencies` or R `dependencies:` — replicateEverything installs CRAN packages for R only.

### Step 3b — Construct `replication.yml`

Use the inventory from Step 3a. **Declare languages explicitly** so Shiny system compatibility knows what to probe.

**Minimal full study:**

```yaml
paper:
  doi: https://doi.org/10.1177/00491241211036161
  title: "..."
  journal: "..."
  year: 2022
  authors: "..."
  dependencies:          # all CRAN packages from Step 3a (R scripts + format helpers)
    - ggplot2
    - haven

repo: replicate-anything/rep-10.1177-00491241211036161

languages:               # every engine used anywhere (prep + replications)
  - r
  - stata

python_dependencies:     # omit if no Python; study-wide PyPI list from Step 3a
  - pandas
  - scikit-learn

stata_packages:          # ado names from Step 3a (probe fallback)
  - reghdfe
  - estout

stata_deps_probe: code/helpers/probe_stata_deps.do
stata_dependencies:
  - code/helpers/install_stata_deps.do

prep:                    # optional pipeline steps (same engine/dependency rules)
  - id: build_data
    type: step
    engine: stata
    code: code/steps/build_data.do
    output: data/processed/analysis.dta

replications:
  - id: fig_1
    type: figure
    label: Figure 1
    description: Short caption for Shiny
    engine: r
    code: code/fig_1.R
    format: format_fig_1
    artifact: artifacts/fig_1.png

  - id: tab_1
    type: table
    label: Table 1
    engine: stata
    code: code/tables/tab_1.do
    format: code/helpers/format_stata.R
    artifact: artifacts/tab_1.html
    data: data/processed/analysis.dta
```

**Construction rules:**

| Yaml field | Source (Step 3a) |
|------------|------------------|
| `languages:` | Union of engines in prep + replications (or infer from `.R` / `.do` / `.py` / `.ipynb` paths) |
| `paper.dependencies` | All unique CRAN packages from R scripts and `format_*.R` helpers |
| `python_dependencies:` | All unique PyPI names from Python scripts/notebooks |
| `stata_packages:` | User-written ado names used in `.do` files |
| `stata_dependencies:` | Path to idempotent `install_stata_deps.do` (SSC/GitHub installs from Step 3a) |
| `stata_deps_probe:` | Check-only `.do` that exits 0 when packages load (`help` / `which`, no network) |
| `replications[].engine` | `r`, `stata`, or `python` — must match `code:` extension |
| `replications[].artifact` | Precomputed display file under `artifacts/` |
| `replications[].dependencies` | **R only** — extra CRAN packages for that entry; prefer study-wide lists when shared |

**Tables with external data:** add `data: data/myfile.dta` on the replication row.

**Tables without format step:** omit `format:`; artifact is usually `.html` from analysis output.

**Validate yaml before moving on:**

```r
yaml::read_yaml("replication.yml")
replicateEverything::study_system_compatibility("<doi>")  # after study repo exists locally
```

### Step 3c — replicateEverything conventions (no package hardcoding)

The **replicateEverything** package reads study metadata only — it does not embed study-specific package names or install commands. Every folder-backed study must declare what the package needs in **replication.yml** and helper scripts under **code/helpers/**.

### Required for all folder-backed studies

| Item | Location | Purpose |
|------|----------|---------|
| Full `replication.yml` | repo root | `paper:`, `replications:` list, `repo:` slug |
| `languages:` | top-level (recommended) | `r`, `stata`, `python` — used by system compatibility check |
| `code:` per replication | `code/<id>.R` or `.do` | Live Run executes this |
| `artifact:` per replication | `artifacts/<id>.{html,png,...}` | Shiny Display tab |
| Registry stub | `registry/studies/<folder>.yml` | Points to study repo; not the full yaml |

**System compatibility** (Shiny button or `study_system_compatibility()`) reads only yaml declarations and probes this machine — no installs. Declare everything explicitly:

```yaml
languages:
  - r
  - stata
  - python

paper:
  dependencies:          # R CRAN packages
    - ggplot2
    - haven

python_dependencies:     # pip imports (study-wide list)
  - pandas
  - scikit-learn

stata_packages:          # fallback when no custom probe script
  - reghdfe
  - estout

stata_deps_probe: code/helpers/probe_stata_deps.do
stata_dependencies:
  - code/helpers/install_stata_deps.do
```

If `languages:` is omitted, engines are inferred from `engine:` / `code:` extensions on prep and replication entries.

### Stata studies — declare dependencies in the study repo

| Field | Example | When to use |
|-------|---------|-------------|
| `stata_dependencies:` | `code/helpers/install_stata_deps.do` | Maintainer-only SSC/GitHub install script (not run on live Shiny Run) |
| `stata_deps_probe:` | `code/helpers/probe_stata_deps.do` | Check-only `.do` that exits 0 when packages load (no network) |
| `stata_packages:` | `[estout, reghdfe]` | Fallback probe via `which <pkg>` when no custom probe script |
| Default install path | `code/helpers/install_stata_deps.do` | Used even without yaml entry if file exists |

**Probe script contract:** exit 0 when satisfied, non-zero otherwise. Use `help <pkg>` or `which <pkg>` — not bare commands that fail with no data (e.g. prefer `cap help reghdfe` over bare `reghdfe`).

**Install script contract:** idempotent SSC/GitHub installs for this study only — run **once** by maintainers (`build_study_artifacts(install_deps = TRUE)` or manually). **Never** call `install_stata_deps.do` from table/prep runners or `init_study_paths.do`; live Run probes only.

### R / Python replications

| Field | Example | Purpose |
|-------|---------|-------------|
| `languages:` | `[r, python]` | Engines for system compatibility check |
| `dependencies:` (paper) | `[ggplot2]` | R CRAN packages |
| `python_dependencies:` | `[pandas]` | Pip packages (study-wide; preferred over per-entry lists) |
| `code:` ending in `.py` / `.ipynb` | `code/fig_1.py` | Python engine |
| `format:` | `format_fig_1` or `code/helpers/format_stata.R` | Display step when artifact is HTML/PNG |

### Artifacts and data (summary)

- **`artifact:`** — single source of truth for Display and audit paths (relative to study root).
- **Data ≤ 50 MB** — commit under `data/` so clones work for live Run.
- **Data > 50 MB** — gitignore by explicit filename; stage under `registry/data/<folder>/`; rely on precomputed `artifacts/` for Display when absent locally.

### Checklist before opening a PR

```
- [ ] Step 3a: dependency search re-run after final code layout
- [ ] replication.yml: languages + paper.dependencies + python_dependencies + stata_* fields complete
- [ ] replication.yml parses; each code:/data:/artifact: path exists
- [ ] Stata: install_stata_deps.do + probe_stata_deps.do (or stata_packages:)
- [ ] study_system_compatibility() or Shiny “Check system compatibility” passes (or documents expected gaps)
- [ ] Artifacts committed; manifest if used
- [ ] Registry stub + index.csv repo column updated
- [ ] study tests: testthat::test_dir("tests/testthat")
- [ ] Package tests pass with fixture study (rep-10.9999_* pattern in replicateEverything)
```

## Step 3.5 — Data files (git vs. large files)

Live replication (the Shiny **Run** button, and any fresh clone) works from a
**clone of the study repo**. If an input file is not committed, the clone lacks
it and Stata/R/Python steps fail with "file not found". So **commit data by
default** — do not blanket-gitignore `data/`.

Rule, keyed to GitHub's limits (soft warning at 50 MB, hard reject at 100 MB):

| File size | Handling |
|-----------|----------|
| **≤ 50 MB** | Commit it in the study repo under `data/`. Live runs work from any clone. |
| **> 50 MB** | Do **not** put it in git. Stage it under the registry data area (`registry/data/<folder>/`) for manual deploy to the server, and document its source (URL/DOI/Dataverse) in `data/raw/README.md`. Live runs from a bare clone won't have it; rely on the precomputed `artifacts/` instead. |

Recommended `.gitignore` (keep data; exclude only logs, staging, and oversized inputs which you list explicitly):

```gitignore
.Rproj.user/
*.log
artifacts/staging/

# Commit data so live replication works from a clone. Only exclude inputs
# too large for git (>50 MB): keep those out, stage under registry/data/<folder>/,
# and deploy to the server manually. List any such files explicitly below.
```

Do **not** use blanket patterns like `data/raw/*.dta` — that silently drops all
inputs and breaks live replication.

## Step 4 — Code scripts (`code/<id>.R`)

Each script must be **self-contained**:

1. Header comment with study repo URL
2. `library(...)` for dependencies
3. `make_<id>(data)` — analysis; returns model, data.frame, ggplot, etc.
4. `format_<id>(object)` — display step when yaml lists `format: format_<id>`
5. Footer that runs locally: `make_<id>(...) |> format_<id>()` or load data from `../data/`

**Split rule:** if Shiny/registry stores **display** artifacts (HTML/PNG), analysis output should be the **object** passed to `format_*`, not the formatted HTML (unless no format step).

Reference: `rep-10.1017-S0003055403000534/code/tab_1.R`, `rep-10.1177-00491241211036161/code/fig_1.R`.

## Step 5 — Artifacts

Build from monorepo:

```r
options(
  replicateEverything.registry_root = "path/to/registry",
  replicateEverything.use_sibling_packages = TRUE
)
replicateEverything::replicate_paper("<doi>", install_deps = TRUE)
# Or save per replication after render_replication + save_artifact
```

Commit under `artifacts/`:

- Figures → `.png`
- Formatted tables → `.html` (when `format:` is set, registry convention often used `.rds` for analysis-only; follow existing `artifact:` in yaml)
- `artifacts/manifest.json` — copy from registry build or hand-write

`registry/scripts/build_artifacts.R` **skips** folder-backed papers.

## Step 6 — Registry stub

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

Delete `code/`, `data/`, `artifacts/` under the registry paper folder.

## Step 7 — Tests (`tests/testthat/`)

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

# Compare to artifact: HTML normalize or PNG md5 after ggsave(8,6,150)
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

## Step 8 — Verification checks

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

## Step 9 — Commit and push

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

1. Copy `replication.yml`, `code/`, `data/`, `artifacts/` from legacy `registry/papers/<folder>/` (or a materialized study folder) to new study repo
2. Ensure study `replication.yml` is the **full** copy (replications list), not the stub
3. Download any gitignored/large data from GitHub raw if missing locally
4. Follow steps 6–9 above

**Examples:** `rep-10.1017-S0003055403000534` (Fearon & Laitin), `rep-10.1177-00491241211036161` (Bounding Causes).

## replicateEverything routing (for debugging)

- `paper.materials: folder` or `index.csv` `repo` ≠ `replicate-anything/registry` → folder-backed
- Materials resolve from sibling `rep-*` folder or `raw.githubusercontent.com/<study-repo>/main/`
- Registry stub always under `registry/studies/<folder>.yml`

See `registry/guides/folder-replication.md` in the monorepo.

## Common pitfalls

- **Skipping Step 3a** — yaml missing `reghdfe`, `haven`, or `pandas` because only the main script was read
- **Stata names in `paper.dependencies`** — use `stata_packages:` / install script instead
- Putting the **stub** yaml in the study repo (must be **full** yaml with `replications:`)
- Forgetting to update `index.csv` `repo` column
- `label` duplicating Shiny sidebar (use `description` for captions; labels like "Table 1" are optional)
- Missing `format_*` when artifact is HTML/PNG but analysis returns raw models
- Tests without `replicateEverything.index` override for the new `repo` slug
