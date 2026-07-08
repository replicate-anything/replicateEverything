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
- [ ] 3. Structure repo: code/, data/, artifacts/, replication.yml
- [ ] 4. Refactor code into make_<id>() + format_<id>() per replication
- [ ] 5. Build artifacts; write artifacts/manifest.json
- [ ] 6. Add testthat tests (run_replication + artifact match)
- [ ] 7. Slim registry stub; update index.csv repo column
- [ ] 8. Remove code/data/artifacts from registry study folder (if migrating)
- [ ] 9. Verify replicateEverything + Shiny locally
- [ ] 10. Commit and push study repo + registry
```

## Step 1 — Inventory

For each table/figure identify:

- **id** (`tab_1`, `fig_1`)
- **type** (`table` | `figure`)
- **data** paths (or none if generated in code)
- **analysis** logic → `make_<id>(data)`
- **display** logic → `format_<id>(object)` (HTML table, ggplot, etc.)
- **dependencies** (CRAN packages)

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

## Step 3 — replication.yml (study repo)

Full file at study repo root. Minimal pattern:

```yaml
paper:
  doi: https://doi.org/10.1177/00491241211036161
  title: "..."
  journal: "..."
  year: 2022
  authors: "..."
  dependencies:
    - ggplot2

replications:
  - id: fig_1
    type: figure
    label: Figure 1
    description: Short caption for Shiny (optional; stub uses Fig 1 if omitted)
    code: code/fig_1.R
    format: format_fig_1
    artifact: artifacts/fig_1.png
    dependencies:
      - ggplot2
```

**Tables with external data:**

```yaml
    data: data/myfile.dta
```

**Tables without separate format step:** omit `format:`; artifact is usually `.html` from analysis output.

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

- Putting the **stub** yaml in the study repo (must be **full** yaml with `replications:`)
- Forgetting to update `index.csv` `repo` column
- `label` duplicating Shiny sidebar (use `description` for captions; labels like "Table 1" are optional)
- Missing `format_*` when artifact is HTML/PNG but analysis returns raw models
- Tests without `replicateEverything.index` override for the new `repo` slug
