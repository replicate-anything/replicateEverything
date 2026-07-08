---
name: apsr-to-replicate-everything
description: >-
  Convert an APSR Cambridge Dataverse replication package into a folder-backed
  replicateEverything study repo (prep steps, Stata/R/Python engines,
  replication.yml, registry stub, artifacts, tests, Shiny). Use when onboarding
  APSR Dataverse deliveries, Cambridge Core archives, rep-10.1017-* study repos,
  or when the user mentions APSR_to_replicateEverything.
---

# APSR Dataverse → replicateEverything

Turn a **flat APSR Dataverse delivery** (`README.txt`, `Codebook.pdf`, monolithic `.do` files, mixed Stata/R/Python) into a **folder-backed study repo** wired to [replicateEverything](https://github.com/replicate-anything/replicateEverything) and the [registry](https://github.com/replicate-anything/registry).

**Companion skills:** `folder-replication` (generic layout), `update-my-skills` (sync this folder to Cursor).

**Canonical example:** `rep-10.1017-s0003055426101749` (Jiang & Yang, *Portraits of Power*).

## When to use

- User drops an APSR/Cambridge replication zip or folder
- Paper DOI starts with `10.1017/S` (APSR)
- Files look like `DO*.do`, `(RCODE)_*.R`, `(Python)_*.ipynb`, `README.txt`
- Goal is Shiny display + `run_replication()` / `run_prep_step()`, not an R package

## Naming

| Item | Rule | Example |
|------|------|---------|
| Source folder (monorepo) | DOI with `/` → `-` | `10.1017-S0003055426101749/` |
| Study repo | `rep-` + lowercase DOI slug | `rep-10.1017-s0003055426101749/` |
| Registry `folder` | DOI, `/` removed | `10.1017S0003055426101749` |
| Registry handle | short slug | `portraits-of-power` |
| Replication ids | `tab_1`, `fig_2`, … | Main text first; appendix later |

Study repo is a **sibling** of `registry/` and `replicateEverything/` in the monorepo.

## Workflow checklist

```
- [ ] 1. Read README.txt + Codebook.pdf; list main-text tables/figures
- [ ] 2. Inventory engines (Stata / R / Python) and pipeline order
- [ ] 3. Create study repo layout (see Target layout)
- [ ] 4. Stage data in data/raw/; gitignore large .dta
- [ ] 5. Add dependency automation (Stata install script, R CRAN, Python pip)
- [ ] 6. Extract pipeline → code/steps/ + prep: in replication.yml
- [ ] 7. Split monolithic .do → code/tables/tab_N.do + mk_tab_N.do
- [ ] 8. Port figures → code/figures/fig_N.{R,py}; helpers → code/helpers/
- [ ] 9. Write replication.yml (stata_dependencies + prep + replications)
- [ ] 10. Registry stub + index.csv row (or drafts/ while WIP)
- [ ] 11. testthat smoke tests
- [ ] 12. Build artifacts/ + manifest.json (`build_study_artifacts(..., install_deps = TRUE)`)
- [ ] 13. Validate engines + Shiny (Display + Run)
```

## Step 1 — Read the delivery

| File | Use |
|------|-----|
| `README.txt` | **Author pipeline order** (numbered steps 0–n) |
| `Codebook.pdf` | Variables, units, sample restrictions |
| `DO*.do` | Stata — often one file for many tables |
| `(RCODE)_*.R` | R figures / post-processing |
| `(Python)_*.ipynb` | RF, correlation plots, ML outputs |
| `*.dta` | Analysis datasets (large; gitignore) |
| `*.csv` | Exported results / conjoint / RF outputs |

**Main text first.** Keep the raw author delivery in a monorepo source folder (e.g. `10.1017-S0003055426101749/`) — **not** inside the study repo.

Mark **artifact-only** outputs (schematics, morphs) with `artifact:` + `note:` and no `code:`.

## Step 2 — Target layout

```
rep-<doi-hyphenated>/
  replication.yml
  README.md
  .gitignore                 # *.dta in raw/processed; staging logs
  data/
    raw/                     # downloaded .dta + shipped CSVs
    raw/README.md
    processed/               # step outputs (gitignored .dta)
  code/
    steps/                   # pipeline: dataset construction, notebooks
    tables/                  # tab_N.do runners + mk_tab_N.do
    figures/                 # fig_N.R / fig_N.py
    helpers/                 # setup_analysis.do, format_stata.R
  artifacts/
    manifest.json
    fig_*.png                # display artifacts (commit)
    tab_*.html               # display artifacts (commit after format)
    staging/                 # Stata logs (gitignore)
  tests/testthat/
```

**No** `code/original/`, `code/stata/`, `code/prep/` — use `steps/`, `helpers/`, engine-agnostic names.

## Step 3 — Data staging

1. Copy `.dta` from delivery → `data/raw/`.
2. Copy shipped `.csv` → `data/raw/`.
3. Gitignore large binaries:

```gitignore
data/raw/*.dta
data/processed/*.dta
artifacts/staging/
*.log
```

4. Document required downloads in `data/raw/README.md`.

Prep outputs → `data/processed/` (e.g. `all_asperson_fulldata.dta`).

## Step 3b — Zero-touch dependencies (required)

Goal: a fresh machine or Shiny server should run prep + tables + figures **without manual `ssc install`, `install.packages()`, or `pip install`**. Wire three layers:

| Engine | Where to declare | How it installs |
|--------|------------------|-----------------|
| **Stata** | Top-level `stata_dependencies:` + `code/helpers/install_stata_deps.do` | `install_deps=TRUE` runs the `.do` via batch Stata; every Stata runner also calls it via `init_study_paths.do` |
| **R** | `paper.dependencies:` (CRAN only) | `build_study_artifacts(install_deps=TRUE)` or `run_replication(..., install_deps=TRUE)` |
| **Python** | Entry-level `dependencies:` on `engine: python` rows (PyPI names) | Same `install_deps=TRUE` → `python -m pip install` before script/notebook |

**Do not** put Stata SSC package names (`reghdfe`, `estout`, `ftools`) in R `dependencies` — replicateEverything only installs CRAN packages for `engine: r` entries and paper-level R deps.

### Stata: `install_stata_deps.do`

Create `code/helpers/install_stata_deps.do` — idempotent, batch-safe, first run needs internet:

```stata
* Pin SSC reghdfe 5.x (author stack). Reghdfe 6.x from GitHub needs "require" — avoid.
version 17
cap which require
if !_rc {
    cap ado uninstall reghdfe
    cap ado uninstall ftools
}
cap which ftools
if _rc ssc install ftools, replace
cap noisily ftools, compile
cap which reghdfe
if _rc ssc install reghdfe, replace
cap which estout
if _rc ssc install estout, replace
```

Reference: `rep-10.1017-s0003055426101749/code/helpers/install_stata_deps.do`.

### Stata: `init_study_paths.do`

Create `code/helpers/init_study_paths.do` — walk up to `replication.yml`, set `global maindir/rawdir/processed/result`, mkdir, then `do install_stata_deps.do`.

**Every** Stata runner (tables **and** prep steps) must start with:

```stata
do "code/helpers/init_study_paths.do"
```

Do **not** rely on authors running `ssc install` by hand or on README instructions alone.

### replication.yml dependency block

```yaml
paper:
  dependencies:
    - ggplot2
    - dplyr
    - readr

stata_dependencies:
  - code/helpers/install_stata_deps.do

replications:
  - id: fig_2
    engine: python
    dependencies:
      - pandas
      - matplotlib
      - seaborn
      - scipy
```

Optional: `requirements: code/helpers/requirements.txt` on a Python entry instead of (or in addition to) `dependencies:`.

### Build command (CI / server / local)

```r
devtools::load_all("<monorepo>/replicateEverything")
options(
  replicateEverything.registry_root = "<monorepo>/registry",
  replicateEverything.study_folders_root = "<monorepo>"
)
build_study_artifacts("rep-10.1017-s0003055426101749", install_deps = TRUE)
```

`install_deps = TRUE` is the default for `build_study_artifacts()`. It runs prep steps first, then tables/figures, installing Stata SSC + CRAN + pip as needed.

**Prerequisites on the machine:** Stata (batch), R 4.x, Python 3.10+ on PATH (or `Sys.setenv(PYTHON=...)`). Internet on first run for SSC/CRAN/pip.

## Step 4 — Prep steps (`prep:` block)

Map README step 0 (and similar) to `type: step` entries:

```yaml
prep:
  - id: construct_analysis_dataset
    type: step
    label: Construct analysis dataset
    engine: stata
    code: code/steps/construct_analysis_dataset.do
    inputs:
      - data/raw/all_asperson_original.dta
      - data/raw/CPED_2022.dta
    output: data/processed/all_asperson_fulldata.dta

  - id: run_random_forest
    type: step
    engine: python
    code: code/steps/run_random_forest.ipynb
    inputs:
      - data/processed/all_asperson_fulldata.dta
    output: data/raw/promotion_results.csv
    dependencies:
      - pandas
      - numpy
      - scikit-learn
      - imbalanced-learn
      - jupyter
      - nbconvert
```

Downstream replications use `requires: [construct_analysis_dataset]`.

`run_replication(..., "everything")` runs prep first (skip if output exists unless forced).

**Audit:** `audit_everything()` should include prep steps and Python engines — verify after onboarding.

## Step 5 — Stata tables

### Runner (`tab_N.do`)

Every Stata runner must:

1. `do "code/helpers/init_study_paths.do"` (sets globals, mkdir, installs SSC deps)
2. `cd` to `${result}`, open log, `do` the mk file, close log

`init_study_paths.do` walks up to `replication.yml`, sets `global maindir`, `rawdir`, `processed`, `result` (honours `REPLICATE_STATA_RESULT`), and runs `install_stata_deps.do`.

Reference: `rep-10.1017-s0003055426101749/code/tables/tab_1.do`.

### Logic (`mk_tab_N.do`)

- `use "${processed}/..."` + `do "${maindir}/code/helpers/setup_analysis.do"`
- Temp files under `${result}/`, never cwd
- **Export publication table with `esttab ... using "${result}/tab_N_table.html", html replace`** (matches author `esttab ... using *_out_*.txt` in `DO18_main_analyses.do`)
- `code/helpers/format_stata.R` reads the esttab HTML for Shiny — **not** the full Stata log

Authors always ran two `esttab` calls: one to the console, one to a file (`1_out_main.txt`, `2_out_interaction_bystep.txt`, …) with `booktabs`. Our study repos use the file export (HTML variant) for display.

### Split monolithic `.do`

From `DO18_main_analyses.do`:

1. Find `**** Table N` markers
2. Extract block → `mk_tab_N.do`
3. Replace relative paths with `${processed}`, `${result}`, `${rawdir}`
4. Shared setup → `code/helpers/setup_analysis.do`

### Stata version

Authors often use `version 18`. If the machine has Stata 17, change to `version 17` in all study do-files.

### Stata packages

**Do not document manual `ssc install` as the primary path.** Use `stata_dependencies:` + `install_stata_deps.do` (Step 3b). Pin package versions when authors used older stacks (e.g. SSC `reghdfe` 5.x vs GitHub 6.x + `require`).

## Step 6 — R figures

Port `(RCODE)_*.R` → `code/figures/fig_N.R`:

```r
make_fig_N <- function(data = NULL) {
  root <- Sys.getenv("REPLICATE_STUDY_ROOT", unset = ".")
  raw <- file.path(root, "data", "raw")
  # ... ggplot ...
}

format_fig_N <- function(object) object

if (sys.nframe() == 0L) make_fig_N()
```

- Read paths from `data/raw/`
- `ggsave` → `artifacts/fig_N.png` when run via replicateEverything
- List all input CSVs under `data:` in yaml

## Step 7 — Python figures / prep

Prefer standalone `.py` for figures when notebooks are fragile on Windows:

```python
root = Path(os.environ.get("REPLICATE_STUDY_ROOT", Path(__file__).resolve().parents[2]))
out = Path(os.environ.get("REPLICATE_PYTHON_OUTPUT", root / "artifacts" / "fig_2.png"))
```

- Prep notebooks stay in `code/steps/`
- Figures: `code/figures/fig_N.py`
- Set `engine: python` in yaml — Shiny must route Display/Run to Python, not R

## Step 8 — replication.yml (main text)

```yaml
paper:
  doi: https://doi.org/10.1017/S0003055426101749
  title: "..."
  journal: American Political Science Review
  year: 2026
  authors: "..."
  dependencies:
    - ggplot2
    - dplyr

repo: replicate-anything/rep-10.1017-s0003055426101749

stata_dependencies:
  - code/helpers/install_stata_deps.do

prep: [ ... ]

replications:
  - id: tab_1
    type: table
    label: Table 1
    engine: stata
    requires: [construct_analysis_dataset]
    data: data/processed/all_asperson_fulldata.dta
    code: code/tables/tab_1.do
    format: code/helpers/format_stata.R
    output: artifacts/staging/tab_1_stata.log
    artifact: artifacts/tab_1.html   # sole display artifact path (Shiny reads this only)

  - id: fig_2
    type: figure
    label: Figure 2
    engine: python
    code: code/figures/fig_2.py
    data: data/raw/10fold_training_results.csv
    output: artifacts/fig_2.png
    artifact: artifacts/fig_2.png
    dependencies:
      - pandas
      - matplotlib
      - seaborn
      - scipy
```

**Figure vs prep routing:** Display figures need **both** `output:` and `artifact:`. Entries with `output:` but no `artifact:` are treated as prep/pipeline steps.

**Artifact wiring:** `artifact:` in `replication.yml` is the **only** path Shiny/`get_artifact_path()` uses (no extension guessing). Stata tables: export with `esttab ... using "${result}/tab_N_table.html", html replace` in `mk_tab_N.do`; `format_stata.R` reads that file, not the full log.

| Engine | yaml `engine` | `code` extension | `dependencies` installs |
|--------|---------------|------------------|-------------------------|
| Stata | `stata` | `.do` | (use `stata_dependencies:` — not entry `dependencies`) |
| R | `r` | `.R` | CRAN via `install_deps=TRUE` |
| Python | `python` | `.py` or `.ipynb` | pip via `install_deps=TRUE` |

## Step 9 — Registry stub

`registry/studies/10.1017S0003055426101749.yml` (or `registry/drafts/` while WIP):

```yaml
paper:
  doi: https://doi.org/10.1017/S0003055426101749
  title: "..."
  materials: folder
  study_repo: replicate-anything/rep-10.1017-s0003055426101749
  study_folder: rep-10.1017-s0003055426101749
  study_ref: main
repo: replicate-anything/rep-10.1017-s0003055426101749
```

Add row to `registry/index.csv` with `handle`, `doi`, `repo`.

**Do not** put the full `replications:` list in the registry — only in the study repo.

Move stub to `drafts/` and regenerate `index.csv` to hide from public Shiny dropdown until ready.

## Step 10 — Tests

`tests/testthat/test-replications.R`:

- `list_replications()` returns expected ids
- Prep inputs exist (`data/raw/*.dta`)
- R figure smoke: `source("code/figures/fig_5.R"); make_fig_5()`
- Optional full `run_replication()` when Stata/R available (`skip_on_cran()`)

```r
options(
  replicateEverything.registry_root = "<monorepo>/registry",
  replicateEverything.study_folders_root = "<monorepo>",
  replicateEverything.use_sibling_packages = TRUE
)
devtools::load_all("<monorepo>/replicateEverything")
```

## Step 11 — Build artifacts

Use `build_study_artifacts()` with `install_deps = TRUE` (default) so prep, Stata SSC, CRAN, and pip all install on a fresh machine:

```r
build_study_artifacts("rep-10.1017-s0003055426101749", install_deps = TRUE)
```

This runs prep steps, then every table/figure, writes `artifacts/*` and `artifacts/manifest.json`.

**Per-item debugging:**

```r
run_replication("10.1017/S0003055426101749", "tab_1", language = "stata", format = TRUE, install_deps = TRUE)
run_replication("10.1017/S0003055426101749", "fig_2", language = "python", install_deps = TRUE)
```

Update `artifacts/manifest.json`:

```json
{
  "generated": "YYYY-MM-DD",
  "replications": {
    "fig_2": { "status": "ok", "artifact": "artifacts/fig_2.png" },
    "tab_1": { "status": "ok", "artifact": "artifacts/tab_1.html" }
  }
}
```

**If tables are missing from GitHub `artifacts/`**, they were not built/formatted yet — staging logs alone are not display artifacts.

## Step 12 — Validate

| Step | Command |
|------|---------|
| Prep | `run_prep_step(doi, "construct_analysis_dataset")` |
| Table | `run_replication(doi, "tab_1", language = "stata", format = TRUE)` |
| Python fig | `run_replication(doi, "fig_2", language = "python")` |
| R fig | `run_replication(doi, "fig_5", format = TRUE)` |
| Artifacts | `get_artifact_path(doi, "fig_2", folder = "...")` |
| Shiny | `replicateEverything::run_shiny_app()` — footer shows version + commit |

Shiny UI order: **Tables → Figures → Pipeline steps** (steps below).

## Author README → replication ids (Portraits of Power)

| README step | Author file | Study id | Engine |
|-------------|-------------|----------|--------|
| 0 | `merge_cped_bio.do` | `construct_analysis_dataset` | Stata prep |
| 1 | `DO18_main_analyses.do` | `tab_1`, `tab_2`, `tab_3` | Stata |
| 5 | `(Python)_human_machine_corr.ipynb` | `fig_2` | Python |
| — | `(Python)_randomforest.ipynb` | `run_random_forest` | Python prep |
| 6 | `(RCODE)_rf_visulization.R` | `fig_4` | R |
| 7 | `(RCODE)_conjoint.R` | `fig_5` | R |
| — | (none) | `fig_1`, `fig_3` | artifact-only |

## Common pitfalls

| Issue | Fix |
|-------|-----|
| Monolithic `DO18_main_analyses.do` | Split into `mk_tab_N.do`; shared setup in `code/helpers/setup_analysis.do` |
| Temp `.dta` in author cwd | Save under `${result}/` via `global result` |
| `version 18` on Stata 17 | Use `version 17` |
| `reghdfe` / `estout` not found | Add `stata_dependencies:` + `install_stata_deps.do`; call `init_study_paths.do` in every Stata runner |
| `reghdfe` 6.x / `require` package conflict | Pin SSC `reghdfe` 5.x in `install_stata_deps.do`; uninstall GitHub 6.x stack |
| Stata names in R `dependencies` | Only CRAN packages in `paper.dependencies` / R entry `dependencies` — not `reghdfe`, `estout` |
| `format_tab_N not found` for Stata tables | Use `format: code/helpers/format_stata.R` (shared formatter); replicateEverything falls back to `format_tab_N_stata` |
| Figure with `output:` only (no `artifact:`) | Treated as prep — add `artifact:` for display figures |
| Python fig prints `[1] "…/fig_2.png"` during build | Fixed in replicateEverything ≥0.5: PNG paths must copy, not `print()` — deploy current package |
| Python fig shows as engine `r` in audit | Set `engine: python`; audit must pass `language` to `render_replication()` |
| Shiny "not available for language r" on `fig_2` | Resolve engine-specific id (`fig_2` + `python`) before Run/Display |
| Fig 2 Display fails but PNG on GitHub | Deploy latest `replicateEverything`; `infer_folder_study_stub()` for draft stubs |
| Table Display shows full Stata log (setup, reghdfe, SSC install) | Add `esttab ... using "${result}/tab_N_table.html", html replace` to `mk_tab_N.do` (from author's `using *_out_*.txt`); point `format_stata.R` at esttab HTML, not raw log |
| Missing Python packages on server | List PyPI names under entry `dependencies:`; run with `install_deps=TRUE` |
| Notebook prep fails | Add `jupyter`, `nbconvert` to prep step `dependencies` |
| `.dta` not in git | Expected — document in `data/raw/README.md`; run prep on server or cache processed data |
| Server missing processed data | `build_study_artifacts()` runs prep first; or ship `data/processed/` |
| Dropbox spaces in paths | replicateEverything uses `Sys.setenv()` + `shQuote()` for Python/Stata — test batch runs early |
| `reghdfe` split across lines with blank line | Stata treats blank line as command end — use one line or `///` without blank lines |

## Deployed Shiny server

1. Install/update `replicateEverything` from GitHub (not an old `win-library` copy).
2. Restart Shiny after package reinstall.
3. Check footer: `replicateEverything 0.5.0 · <sha> · installed` — confirms which build is live.
4. **Stata + Python on PATH**; large `.dta` under study cache or built by prep.
5. First replication run: `install_deps=TRUE` (default in Shiny live display) installs SSC/CRAN/pip automatically when study has `stata_dependencies`, `paper.dependencies`, and Python entry `dependencies` wired correctly.
6. Stata first run needs **internet once** for SSC; document offline fallback in study README if needed.

## Additional references

- Generic folder workflow: skill `folder-replication`
- Stata table template: `rep-10.1017-S0003055403000534` (Fearon)
- Multi-engine APSR example: `rep-10.1017-s0003055426101749`
- replicateEverything Shiny: `inst/shiny/app.R`
