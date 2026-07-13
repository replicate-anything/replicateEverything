---
name: dataverse-to-replicate-everything
description: >-
  Convert a Harvard Dataverse replication deposit into a folder-backed
  replicateEverything study repo (discover via get_dataset, download author README,
  infer step DAG, Stata/R/Python engines, replication.yml with steps:, registry stub,
  outputs/, tests, Shiny). Use when onboarding Dataverse deliveries (doi:10.7910/DVN/…),
  Cambridge Core archives, rep-* study repos, or when the user mentions
  dataverse_to_replicateEverything.
---

# Harvard Dataverse → replicateEverything

Turn a **flat Dataverse replication deposit** (`ReadMe.txt` / `README.txt` / `readme.rtf`,
`Codebook.pdf`, monolithic `.do` / `.Rmd` files, mixed Stata/R/Python) into a
**folder-backed study repo** wired to [replicateEverything](https://github.com/replicate-anything/replicateEverything) and the [registry](https://github.com/replicate-anything/registry).

**Companion skills:** `folder-replication` (generic layout + **Step 1b DAG discovery** + Step 4 yaml), `update-my-skills` (sync this folder to Cursor).

**Canonical examples:** `rep-10.1017-s0003055426101749` (Jiang & Yang, multi-engine); [`rep-10.1017-s0003055422000284`](https://github.com/replicate-anything/rep-10.1017-s0003055422000284) (Blair et al., Dataverse fetch + Stata).

## When to use

- User gives a **Dataverse dataset DOI** (`doi:10.7910/DVN/…`) or a downloaded zip/folder
- Deposit includes author readme + replication code (Stata `.do`, R `.R` / `.Rmd`, Python `.ipynb`)
- Common sources: APSR / Cambridge Core (`10.1017/S…`), but any journal on Harvard Dataverse
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

Every study needs **`maintainer:`** (name + email) and **`collections:`** in root
`replication.yml`. Set **`collections: [APSR]` only when the deposit metadata cites
*American Political Science Review*** (journal block or `publicationCitation`); otherwise
use the appropriate tag (`PED`, `World Bank`, `IPI`, …) or omit until known. Sync to
registry `index.csv` with **`build_registry_index()`** after copying the stub — see
folder-replication Step 4b.

```
- [ ] 1. **Read author README** (download from Dataverse if no local zip) + Codebook; list main-text tables/figures
- [ ] 2. **Reconstruct step DAG** from README order + script file I/O (folder-replication Step 1b)
- [ ] 3. Inventory engines (Stata / R / Python) and pipeline order
- [ ] 4. Create study repo layout (see Target layout)
- [ ] 5. **Data:** commit `data/raw/` (≤50MB) **or** wire `access_data` from Dataverse (preferred when deposit is public)
- [ ] 6. **Search all code for dependencies** — folder-replication Step 4a + Dataverse delivery patterns below
- [ ] 7. Add dependency automation (Stata install script, R CRAN, Python pip)
- [ ] 8. Extract pipeline → code/steps/ + transform steps in replication.yml
- [ ] 9. Split monolithic .do → code/tables/tab_N.do + mk_tab_N.do
- [ ] 10. Port figures → code/figures/fig_N.{R,py}; helpers → code/helpers/
- [ ] 11. **Write replication.yml** — `steps:` DAG + deps (folder-replication Step 4b)
- [ ] 12. Registry stub + run **`build_registry_index()`**
- [ ] 13. testthat smoke tests
- [ ] 14. Build outputs/ + manifest.json (`build_study_outputs(..., install_deps = TRUE)`)
- [ ] 15. Validate engines + Shiny (Display + Run + Check system compatibility)
- [ ] 16. Push standalone study repo to `github.com/replicate-anything/rep-<doi-slug>` (no `data.dta` when using Pattern A)
```

## Step 1 — Read the delivery

| File | Use |
|------|-----|
| `ReadMe.txt`, `README.txt`, or `readme.rtf` | **Author pipeline order** (numbered steps 0–n); always present in well-formed deposits |
| `Codebook.pdf` | Variables, units, sample restrictions |
| `DO*.do` | Stata — often one file for many tables |
| `(RCODE)_*.R` | R figures / post-processing |
| `(Python)_*.ipynb` | RF, correlation plots, ML outputs |
| `*.dta` | Analysis datasets (commit if ≤50MB; gitignore only if >50MB) |
| `*.csv` | Exported results / conjoint / RF outputs |

**Main text first.** Keep the raw author delivery in a monorepo source folder (e.g. `10.1017-S0003055426101749/`) — **not** inside the study repo.

**Scope the delivery.** Dataverse archives often bundle folders you do **not** need for table/figure replication: `ethics/`, `instruments/`, `secondary_si/`, map assets (`maps.qgz`, screenshots). Use only replication code + analysis data (or Dataverse tab/CSV/RDS) unless a figure step needs more.

**Find the data.** A partial zip may contain only `analysis/do/`; check `analysis/data/` for `data.dta` or `data-1.dta` before downloading from Dataverse. Harvard Dataverse may ship `data-1.tab` instead of `.dta` (same content).

**RTF readme.** Newer deliveries use `readme.rtf` instead of `README.txt` — extract the numbered pipeline list from RTF (or open in Word) and convert contributor notes to `README.md`.

Mark **artifact-only** outputs (schematics, morphs) with `artifact:` + `note:` and no `code:`.

## Step 2 — Target layout

```
rep-<doi-hyphenated>/
  replication.yml
  README.md
  .gitignore                 # logs + staging; only >50MB inputs (by name)
  data/
    raw/                     # .dta + shipped CSVs (committed if ≤50MB)
    raw/README.md
    processed/               # step outputs (committed if ≤50MB)
  code/
    steps/                   # pipeline: dataset construction, notebooks
    tables/                  # tab_N.do runners + mk_tab_N.do
    figures/                 # fig_N.R / fig_N.py
    helpers/                 # setup_analysis.do, format_stata.R
  outputs/
    manifest.json
    fig_*.png                # display outputs (commit)
    tab_*.html               # display outputs (commit after format)
    <step_id>/               # intermediate step products
    staging/                 # Stata logs (gitignore)
  tests/testthat/
```

**No** `code/original/`, `code/stata/`, `code/prep/` — use `steps/`, `helpers/`, engine-agnostic names.

## Step 2b — Map author README to a step DAG

Dataverse deposits almost always document pipeline order in the **author readme**
(`ReadMe.txt`, `README.txt`, or `readme.rtf`). That numbered list is the primary
source for `steps:` — not a guess from table ids alone.

| README pattern | Step yaml |
|----------------|-----------|
| Dataverse / external deposit | `access_data` transform (`parents: []`, `outputs: outputs/data.dta`) |
| Step 0: merge / construct dataset | `type: transform`, `parents: []`, raw `inputs:` from `data/raw/` |
| Step 1: main tables | One `type: table` per table, `parents: [access_data]` or `[construct_…]` |
| Later: figures / ML / conjoint | `type: figure` or extra transforms as needed |
| Shared `.dta` used by many scripts | **One** transform step; tables point to `outputs/<step_id>/…` |

Trace **`use` / `merge` / `save`** in monolithic `.do` files to confirm edges. See
**folder-replication Step 1b** for the full agent workflow and Fearon/Jiang examples.

## Step 1b — Discover deposit from Dataverse (no local zip required)

Start from the **Dataverse dataset DOI** (`doi:10.7910/DVN/…`) or resolve it from
the paper DOI / Cambridge supplementary link. Use the R `dataverse` package — a full
zip download is **not** required to begin onboarding.

```r
library(dataverse)
Sys.setenv("DATAVERSE_SERVER" = "dataverse.harvard.edu")
ds <- get_dataset("doi:10.7910/DVN/OXSQMU")   # example: Blair et al.
# ds <- get_dataset("doi:10.7910/DVN/BZOCDJ")  # example: Velez et al. (R / Rmd driver)
```

### Always download the author README first

Well-formed replication deposits **include an author readme** — `ReadMe.txt`,
`README.txt`, or `readme.rtf`. When starting from the API (no local zip), treat this
as the mandatory first download:

1. `get_dataset()` — citation metadata (paper DOI, title, authors, journal) + file inventory
2. Find readme in `ds$files$filename` (case-insensitive `readme.(txt|rtf)`)
3. **Download readme** to a scratch folder (e.g. `original_studies/<paper-doi>/`) before writing yaml
4. Read numbered pipeline steps from the readme — same workflow as Step 1
5. Download the main driver next (`Replication.Rmd`, `analysis.do`, monolithic `.do`, …) as needed

```r
files <- ds$files
readme_row <- files[grepl("^readme\\.(txt|rtf)$", files$filename, ignore.case = TRUE), ]
stopifnot(nrow(readme_row) >= 1L)   # readme should always be present

# Download by file id (dataverse API) into scratch — then open locally
# dataverse::get_dataframe_by_name() works for .tab; for plain text use file download API
```

If readme is missing, stop and inspect the deposit — it may be incomplete or mislabeled.

Use `ds$files` (or the Dataverse web UI) to inventory:

| Keep for replication | Usually skip |
|---------------------|--------------|
| Author readme (`ReadMe.txt` / `README.txt` / `readme.rtf`) | — (always download first) |
| `analysis/do/*.do`, helper `.do`, `Replication.Rmd`, `*.R` | `ethics/`, `instruments/`, `secondary_si/` |
| `data-1.tab` / `*.tab` / `data.dta` (via fetch step) | IRB PDFs, survey instruments, map assets |

`get_dataset()` returns enough to name the study repo (`paper.doi` from citation
metadata), infer **`collections:`** (APSR only when journal metadata cites *American
Political Science Review*), and plan `access_data` fetches — without committing
large binaries to git.

Map paper DOI ↔ Dataverse DOI via readme, Cambridge SI link, or
[Harvard Dataverse search](https://dataverse.harvard.edu/). Harvard deposits use
`10.7910/DVN/…` persistent ids.

## Step 3 — Data staging

Two patterns — pick one per study.

### Pattern A — Dataverse fetch (preferred for public deposits)

**Do not commit** the analysis `.dta`. Add a root R transform:

| yaml | Value |
|------|-------|
| `id` | `access_data` |
| `label` | Access data from Dataverse |
| `type` | `transform` |
| `parents` | `[]` |
| `engine` | `r` |
| `code` | `code/steps/access_data.R` |
| `outputs` | `outputs/data.dta` |

Study-level `dataverse:` block in `replication.yml`:

```yaml
dataverse:
  server: dataverse.harvard.edu
  dataset: "10.7910/DVN/OXSQMU"
  file: data-1.tab

paper:
  dependencies:
    - dataverse
    - haven
    - yaml
```

`code/steps/access_data.R` — `make_access_data()`:

```r
make_access_data <- function() {
  dat <- dataverse::get_dataframe_by_name(
    filename = "data-1.tab",
    dataset = "10.7910/DVN/OXSQMU",
    original = TRUE,
    .f = haven::read_dta,
    server = "dataverse.harvard.edu"
  )
  root <- Sys.getenv("REPLICATE_STUDY_ROOT", ".")
  out <- file.path(root, "outputs", "data.dta")
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  haven::write_dta(dat, out)
  dat
}
```

Downstream Stata tables: `parents: [access_data]`, `data: outputs/data.dta`, and
`use "${processed}/data.dta"` in `mk_tab_N.do` (`processed` → `outputs/`).

`.gitignore`:

```gitignore
outputs/data.dta
```

`data/raw/README.md` documents the Dataverse DOI and filename — **no binary in git**.

**Run semantics:**

| Call | Fetches when `outputs/data.dta` missing? |
|------|------------------------------------------|
| `build_study_outputs()` | Yes (`ensure_study_ancestor_steps`) |
| `run_replication(doi, "tab_1", given = "nothing")` | Yes |
| `run_replication(doi, "tab_1")` default `given = "parents"` | No — expects file already there |

On a fresh clone use `given = "nothing"` or run `access_data` first. Display
artifacts (`outputs/tab_1.html`) stay committed; intermediate `.dta` is local cache.

**Publish:** init git in the study folder, `.gitignore` `outputs/data.dta`, commit
code + yaml + display artifacts, push to `replicate-anything/rep-<doi-slug>` on
GitHub. Registry stub sync stays in the monorepo via `sync_study_to_registry()`.

### Pattern B — Commit data in `data/raw/` (legacy / offline / private data)

Live replication (Shiny **Run**, and any fresh clone) runs from a **clone of the
study repo**. Uncommitted inputs are missing from the clone and steps fail with
"file not found". So **commit data by default** when not using Pattern A; only exclude files too large for git.

1. Copy `.dta` from delivery → `data/raw/`.
2. Copy shipped `.csv` → `data/raw/`.
3. Decide per file by size (GitHub warns at 50 MB, hard-rejects at 100 MB):

| File size | Handling |
|-----------|----------|
| **≤ 50 MB** | Commit under `data/` — live runs work from any clone. |
| **> 50 MB** | Keep out of git. Stage under `registry/data/<folder>/` for manual deploy to the server, document the source in `data/raw/README.md`, rely on precomputed `outputs/`, and list the file explicitly in `.gitignore`. |

4. `.gitignore` (keep data; exclude only logs, staging, and oversized files by name):

```gitignore
.Rproj.user/
*.log
outputs/staging/

# Commit data so live replication works from a clone. Only exclude inputs
# too large for git (>50 MB): keep those out, stage under registry/data/<folder>/,
# deploy to the server manually, and list each such file explicitly below.
```

**Do not** blanket-ignore `data/raw/*.dta` / `data/processed/*.dta` — it silently
drops all inputs and breaks live replication (the app then reports "file not
found" or falls back to a stale artifact).

5. Document any downloads / oversized files in `data/raw/README.md`.

Prep outputs → `data/processed/` (e.g. `all_asperson_fulldata.dta`); commit them
too when ≤ 50 MB so tables run without re-running heavy prep.

## Step 3a — Search for all dependencies (before yaml)

**Follow folder-replication Step 4a** for the generic workflow. Dataverse deliveries often need extra passes because dependencies are scattered across monolithic `.do` / `.Rmd` files, `(RCODE)_*.R`, and `(Python)_*.ipynb`.

**Search the source delivery folder and refactored `code/`:**

| What to search | Where | Maps to yaml |
|----------------|-------|--------------|
| `library(`, `require(` | `(RCODE)_*.R`, `code/figures/*.R`, `code/helpers/format_stata.R` | `paper.dependencies` |
| `ssc install`, `net install`, `ado install` | `DO*.do`, `code/**/*.do` | `install_stata_deps.do` |
| `esttab`, `eststo`, `reghdfe`, `ftools`, `ivreg2`, `outreg2`, `asdoc` | all `.do` | `stata_packages:` + install script |
| `import`, `from`, `pip install` | `.py`, `.ipynb` | `python_dependencies:` |
| README.txt numbered steps | “install”, “ssc”, “require” | Cross-check — authors often list SSC stack here |

```bash
# From monorepo root or study repo
rg -n "library\\(|require\\(" --glob "*.{R,r}" code/ ../10.1017-S*/
rg -n "ssc install|net install|ado install" --glob "*.do" code/ ../10.1017-S*/
rg -n "\\b(esttab|eststo|reghdfe|ftools|ivreg2)\\b" --glob "*.do" code/
rg -n "^(import |from )|pip install" --glob "*.{py,ipynb}" code/
```

**Dedupe** into R / Stata / Python lists before writing yaml. Re-run after splitting `DO18_main_analyses.do` into per-table scripts — hidden `esttab` calls often surface only then.

## Step 3b — Zero-touch dependencies (required)

Goal: a fresh machine or Shiny server should run prep + tables + figures **without manual `ssc install`, `install.packages()`, or `pip install`**. Wire three layers:

| Engine | Where to declare | How it installs |
|--------|------------------|-----------------|
| **Stata** | `stata_packages:` (SSC ado names) | Maintainers: `install_study_dependencies(doi)` — package auto-installs from SSC and probes before live Run |
| **R** | `paper.dependencies:` (CRAN only) | `install_study_dependencies(doi)` or `build_study_outputs(install_deps=TRUE)` |
| **Python** | `python_dependencies:` (study-wide) **or** entry-level `dependencies:` on `engine: python` rows | Same maintainer install API → `pip install` |

**Do not** put Stata SSC package names (`reghdfe`, `estout`, `ftools`) in R `dependencies` — replicateEverything only installs CRAN packages for `engine: r` entries and paper-level R deps.

### Stata: `stata_packages:` (default — no custom `.do` files)

List SSC ado command names from your `.do` files. replicateEverything auto-generates install + probe (including `reghdfe` / GitHub 6.x conflict handling on shared servers):

```yaml
languages:
  - stata

stata_packages:
  - ftools
  - reghdfe
  - require
  - estout
```

Maintainers run once: `install_study_dependencies("<doi>")`. Live Run and Shiny probe only.

When **`reghdfe` is in table code**, **`require` must be in this list** — SSC 6.x depends on it. Probes that only run `help reghdfe` can pass while live Run fails with `r(9)`.

Optional **custom** `stata_dependencies:` / `stata_deps_probe:` `.do` files only for exotic GitHub-only stacks or non-SSC packages (rare).

### Stata: `init_study_paths.do`

Create `code/helpers/init_study_paths.do` — walk up to `replication.yml`, set `global maindir/rawdir/processed/result`, mkdir. **Do not** install SSC packages from runners — replicateEverything probes before Run; maintainers use `install_study_dependencies(doi)`.

**Every** Stata runner (tables **and** prep steps) should start with:

```stata
do "code/helpers/init_study_paths.do"
```

Do **not** rely on authors running `ssc install` by hand, and **do not** install inside table/prep scripts.

### replication.yml dependency block

Use the **Step 3a inventory** — do not hand-write a partial list. See **folder-replication Step 4b** for the full yaml template.

```yaml
languages:
  - r
  - stata
  - python

paper:
  dependencies:
    - ggplot2
    - dplyr
    - readr

python_dependencies:
  - pandas
  - matplotlib
  - seaborn
  - scikit-learn
  - jupyter
  - nbconvert

stata_packages:
  - ftools
  - reghdfe
  - require
  - estout

replications:
  - id: fig_2
    engine: python
    code: code/figures/fig_2.py
    # Prefer study-wide python_dependencies:; per-entry dependencies only if unique to one figure
```

### Build command (CI / server / local)

```r
devtools::load_all("<monorepo>/replicateEverything")
options(
  replicateEverything.registry_root = "<monorepo>/registry",
  replicateEverything.study_folders_root = "<monorepo>"
)
build_study_outputs("rep-10.1017-s0003055426101749", install_deps = TRUE)
```

`install_deps = TRUE` is the default for `build_study_outputs()`. It runs prep steps first, then tables/figures, installing Stata SSC + CRAN + pip as needed.

**Prerequisites on the machine:** Stata (batch), R 4.x, Python 3.10+ on PATH (or `Sys.setenv(PYTHON=...)`). Internet on first run for SSC/CRAN/pip.

## Step 4 — Transform steps (`steps:` block)

Map README step 0 (and similar) to `type: transform` entries with explicit `parents:` and `outputs:`:

```yaml
steps:
  - id: construct_analysis_dataset
    type: transform
    label: Construct analysis dataset
    parents: []
    inputs:
      - data/raw/all_asperson_original.dta
      - data/raw/CPED_2022.dta
    outputs:
      - outputs/construct_analysis_dataset/all_asperson_fulldata.dta
    engine: stata
    code: code/steps/construct_analysis_dataset.do

  - id: run_random_forest
    type: transform
    label: Random forest prep
    parents:
      - construct_analysis_dataset
    inputs:
      - outputs/construct_analysis_dataset/all_asperson_fulldata.dta
    outputs:
      - outputs/run_random_forest/promotion_results.csv
    engine: python
    code: code/steps/run_random_forest.ipynb
    dependencies:
      - pandas
      - scikit-learn
      - imbalanced-learn
      - jupyter
      - nbconvert
```

Downstream tables/figures set `parents: [construct_analysis_dataset]` (and other
transforms as needed).

`run_replication(..., "tab_1", given = "nothing")` runs upstream transforms first
(skip if `outputs/` exist unless `force = TRUE`).

**Audit:** `audit_everything()` walks all non-format steps — verify after onboarding.

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

**Do not document manual `ssc install` as the primary path.** List SSC ado names under `stata_packages:` (Step 3b). replicateEverything auto-generates install + probe scripts.

When **`reghdfe` appears in table code**, also list **`require`** — SSC now ships `reghdfe` 6.x, which depends on `require`. A server can pass `help reghdfe` in the probe yet fail live Run on the first `reghdfe` call if `require` is missing (`r(9)`).

```yaml
stata_packages:
  - ftools
  - reghdfe
  - require
  - estout
```

Custom `install_stata_deps.do` / `stata_deps_probe:` are **rare** — only for GitHub-only stacks or exotic version pins.

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
- `ggsave` → `outputs/fig_N.png` when run via replicateEverything
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

**Construct from Step 4a dependency inventory and Step 2b DAG** using folder-replication Step 4b. Minimum main-text block:

```yaml
languages:
  - r
  - stata
  - python

paper:
  doi: https://doi.org/10.1017/S0003055426101749
  title: "..."
  # ...

collections:
  - APSR   # only when deposit metadata cites American Political Science Review

stata_packages:
  - ftools
  - reghdfe
  - require
  - estout

steps:
  - id: construct_analysis_dataset
    type: transform
    # ... see Step 4

  - id: tab_1
    type: table
    label: Table 1
    parents:
      - construct_analysis_dataset
    inputs:
      - outputs/construct_analysis_dataset/all_asperson_fulldata.dta
    engine: stata
    code: code/tables/tab_1.do
    format: code/helpers/format_stata.R
    outputs:
      - outputs/tab_1.html
    artifact: outputs/tab_1.html

  - id: fig_2
    type: figure
    label: Figure 2
    parents: []
    engine: python
    code: code/figures/fig_2.py
    inputs:
      - data/raw/10fold_training_results.csv
    outputs:
      - outputs/fig_2.png
    artifact: outputs/fig_2.png
```

**Display paths:** `artifact:` (and primary `outputs:` entry) is the **only** path Shiny uses. Stata tables: export with `esttab ... using "${result}/tab_N_table.html", html replace` in `mk_tab_N.do`; `format_stata.R` reads that file, not the full log.

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

**Do not** put the full `steps:` list in the registry — only in the study repo.

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

## Step 11 — Build outputs

Use `build_study_outputs()` with `install_deps = TRUE` (default) so transforms, Stata SSC, CRAN, and pip all install on a fresh machine:

```r
build_study_outputs("rep-10.1017-s0003055426101749", install_deps = TRUE)
```

This runs upstream steps, then every table/figure, writes `outputs/*` and `outputs/manifest.json`.

**Per-item debugging:**

```r
run_replication("10.1017/S0003055426101749", "tab_1", language = "stata", format = TRUE, install_deps = TRUE)
run_replication("10.1017/S0003055426101749", "fig_2", language = "python", install_deps = TRUE)
```

Update `outputs/manifest.json`:

```json
{
  "generated": "YYYY-MM-DD",
  "replications": {
    "fig_2": { "status": "ok", "artifact": "outputs/fig_2.png" },
    "tab_1": { "status": "ok", "artifact": "outputs/tab_1.html" }
  }
}
```

**If tables are missing from GitHub `outputs/`**, they were not built/formatted yet — staging logs alone are not display files.

## Step 12 — Validate

| Step | Command |
|------|---------|
| System deps | `check_study_compatibility(doi)` — probe only; same API for folder and package registry studies |
| Install deps | `install_study_dependencies(doi)` — maintainer setup; not run on Shiny live Run |
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
| Wrong pipeline order in yaml | Re-read README.txt; trace `use`/`save` in author scripts (folder-replication Step 1b) |
| Monolithic `DO18_main_analyses.do` | Split into `mk_tab_N.do`; shared setup in `code/helpers/setup_analysis.do` |
| Temp `.dta` in author cwd | Save under `${result}/` via `global result` |
| `version 18` on Stata 17 | Use `version 17` |
| `reghdfe` / `estout` not found | Step 3a/4a search → `stata_packages:` (include `require` when `reghdfe` is listed); call `init_study_paths.do` in every Stata runner |
| `reghdfe` fails at runtime (`r(9)`) but probe passed | SSC `reghdfe` 6.x needs `require` — add to `stata_packages:` and run `install_study_dependencies(doi)` |
| Shiny “not configured” for Stata deps | Add `languages:` and `stata_packages:` to study `replication.yml` (registry stub does not carry these) |
| Stata names in R `dependencies` | Only CRAN packages in `paper.dependencies` / R entry `dependencies` — not `reghdfe`, `estout` |
| `format_tab_N not found` for Stata tables | Use `format: code/helpers/format_stata.R` (shared formatter); replicateEverything falls back to `format_tab_N_stata` |
| Figure with `outputs:` only (no `artifact:`) | Add `artifact:` for display figures |
| Using `prep:`/`replications:` on new studies | Use unified `steps:` + `outputs/` (0.6+) |
| Python fig prints `[1] "…/fig_2.png"` during build | Fixed in replicateEverything ≥0.5: PNG paths must copy, not `print()` — deploy current package |
| Python fig shows as engine `r` in audit | Set `engine: python`; audit must pass `language` to `render_replication()` |
| Shiny "not available for language r" on `fig_2` | Resolve engine-specific id (`fig_2` + `python`) before Run/Display |
| Fig 2 Display fails but PNG on GitHub | Deploy latest `replicateEverything`; `infer_folder_study_stub()` for draft stubs |
| Table Display shows full Stata log (setup, reghdfe, SSC install) | Add `esttab ... using "${result}/tab_N_table.html", html replace` to `mk_tab_N.do` (from author's `using *_out_*.txt`); point `format_stata.R` at esttab HTML, not raw log |
| `esttab` r(198) on HTML export | Do not combine `booktabs` / `br` (LaTeX options) with `html` — use `html replace` with `label b() se()` only |
| Substantive check gets formatted HTML not Stata envelope | Export `${result}/tab_N_benchmarks.csv` from Stata; substantive script parses HTML or reads CSV from `outputs/staging/` |
| Missing Python packages on server | List PyPI names under entry `dependencies:`; run with `install_deps=TRUE` |
| Notebook prep fails | Add `jupyter`, `nbconvert` to prep step `dependencies` |
| Live Run "file not found" for a `.dta` | Input was gitignored without a Dataverse `access_data` step, or `given = "parents"` on fresh clone — use `given = "nothing"` or run `access_data` first |
| `outputs/data.dta` missing after clone | Expected with Pattern A — run `build_study_outputs()` or `run_replication(..., given = "nothing")` |
| `.dta` >50MB not in git | Expected — stage under `registry/data/<folder>/`, deploy to server, document in `data/raw/README.md` |
| Server missing processed data | `build_study_outputs()` runs prep first; or ship `data/processed/` |
| Dropbox spaces in paths | replicateEverything uses `Sys.setenv()` + `shQuote()` for Python/Stata — test batch runs early |
| `reghdfe` split across lines with blank line | Stata treats blank line as command end — use one line or `///` without blank lines |

## Deployed Shiny server

1. Install/update `replicateEverything` from GitHub (not an old `win-library` copy).
2. Restart Shiny after package reinstall.
3. Check footer: `replicateEverything 0.5.0 · <sha> · installed` — confirms which build is live.
4. **Stata + Python on PATH**. Committed inputs (≤50MB) arrive with the clone; only >50MB files must be deployed manually or rebuilt by prep.
5. First replication run: `install_deps=TRUE` (default in Shiny live display) installs SSC/CRAN/pip automatically when study has `stata_packages:`, `paper.dependencies`, and Python entry `dependencies` wired correctly.
6. Stata first run needs **internet once** for SSC; document offline fallback in study README if needed.

## Additional references

- Generic folder workflow + DAG rules: skill `folder-replication` (Step 1b)
- Package design notes: `inst/docs/step-dag-design.md`, `inst/docs/step-inheritance.md`
- Stata table template: `rep-10.1017-S0003055403000534` (Fearon)
- Multi-engine Dataverse example: `rep-10.1017-s0003055426101749` (Jiang & Yang)
- replicateEverything Shiny: `inst/shiny/app.R`
