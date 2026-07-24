# replicateEverything

![replicateEverything logo](reference/figures/logo.png)

**Tools to discover, run, and contribute computational replications of
empirical research papers.**

`replicateEverything` connects to a public [replication
registry](https://github.com/replicate-anything/registry), retrieves
replication materials (metadata, processed data, and analysis code), and
reproduces figures and tables from published studies in a standardized
workflow. The package also bundles a **Shiny demo app** for browsing
studies and running replications interactively — try the [live
demo](https://shiny2.wzb.eu/ipi/replicate/).

**Start here:** [Why
replicateEverything?](https://replicate-anything.github.io/replicateEverything/articles/why-replicateEverything.html)
— the best high-level overview of motivation, the registry, and how to
run replications.

## Key features

- **Discovery** — search the registry, look up papers by DOI, and
  inspect available replications
- **A DAG, not a file list** — `replication.yml` declares a `steps:`
  graph (`parents:` / `outputs:`); yaml is the sole authority for
  execution order, nothing is inferred
- **One-line replication** — run a single figure or table, or reproduce
  an entire paper with `run_replication(doi, "everything")`
- **Registry-backed materials** — fetch data and code from GitHub
  without manual downloads
- **Folder-backed studies** — dedicated study repositories with `code/`,
  `data/`, and `outputs/`
- **Package-backed studies** — standalone R packages linked from
  lightweight registry stubs; same `steps:` yaml and build API as folder
  studies
- **Artifacts** — load, validate, and save precomputed outputs (PNG,
  HTML, RDS) for fast display
- **Display pipeline** — optional `format_*` steps turn analysis objects
  into HTML tables and ggplot figures
- **Shiny demo** — [live app](https://shiny2.wzb.eu/ipi/replicate/);
  [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)
  locally;
  [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)
  to deploy on Shiny Server
- **Contributor tooling** — validate with
  [`check_and_bake_study()`](https://replicate-anything.github.io/replicateEverything/reference/check_and_bake_study.md),
  then a maintainer registers with
  [`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
  /
  [`register_study()`](https://replicate-anything.github.io/replicateEverything/reference/register_study.md)
  — no study-local registry handoff
- **Checks** —
  [`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md)
  and
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  cover structure, precomputed outputs, and optional published-value
  substantive benchmarks
- **Bundled AI skills** — markdown workflow guides for assistants
  ([`ai_skills()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skills.md),
  [`ai_skill()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skill.md))

## Project status

The project is under active development. Feedback is welcome — contact
[Vermon Washington](mailto:vermon.washington@wzb.eu) or [Macartan
Humphreys](mailto:macartan.humphreys@wzb.eu).

## Installation

Install from GitHub with `remotes` or `devtools`:

``` r

remotes::install_github("replicate-anything/replicateEverything")
# or
devtools::install_github("replicate-anything/replicateEverything")
```

Requires R (\>= 4.1.0).

## Quick start

``` r

library(replicateEverything)

# Browse the registry index
head(load_index()[, c("doi", "title", "year")])

# Search the registry by title keyword
search_papers("causes")

# See what can be replicated for a paper
list_replications("10.1177/00491241211036161")

# Run one figure or table
run_replication("10.1177/00491241211036161", "fig_1")

# Reproduce every registered result
run_replication("10.1177/00491241211036161", "everything")
```

For a tour of every main function, see [Meet the
functions](https://replicate-anything.github.io/replicateEverything/articles/meet-the-functions.html).
For a worked example with output, see the [replication
vignette](https://replicate-anything.github.io/replicateEverything/articles/replication-example.html).

## How it works

The [registry](https://github.com/replicate-anything/registry) indexes
studies via lightweight stub files in `studies/<folder>.yml`.
**Folder-backed** studies keep code, data, and display outputs in a
dedicated study repository; **package-backed** studies keep them in an R
package. `replicateEverything` reads the stub, loads the full
`replication.yml` from the study repo or package, and runs the
registered scripts.

    Registry                         Study repo or package
      studies/<folder>.yml  ───────►  replication.yml
      index.csv                      data/  code/  outputs/
                  ↓
          replicateEverything
                  ↓
          figures & tables in your R session

### Registry layout

Each indexed paper has one stub file:

    studies/
      10.1177_00491241211036161.yml
      10.1371_journal.pone.0278337.yml

Folder-backed study repositories follow:

    replication.yml
    data/
    code/
    outputs/
    tests/testthat/

Package-backed study packages follow the layout in [Package-backed
replications](#package-backed-replications) below.

The `<folder>` name comes from the registry `index.csv` (for example
`10.1177_00491241211036161` or `10.1017S0003055403000534`).

### Example `replication.yml`

`replication.yml` is a **DAG**: each entry is a node with `id`, `type`,
`code`, its data/inputs, its `outputs`, and (for anything downstream of
another step) `parents`. Yaml is the sole authority for what runs and in
what order — nothing about the pipeline is inferred or guessed.

``` yaml
paper:
  title: My wonderful paper
  authors:
    - replicateEverything, Team
  year: 2024
  doi: 1.2.3.4
  journal: Sample journal

maintainer:
  name: Jane Maintainer
  email: maintainer@example.org

collections:
  - PED

languages:
  - r

steps:
  - id: fig_1
    type: figure
    label: Figure 1
    description: Example figure
    data: data/fig_1.csv
    code: code/fig_1.R
    outputs:
      - outputs/fig_1.png

  - id: tab_1
    type: table
    label: Table 1
    description: Example table
    data: data/tab_1.csv
    code: code/tab_1.R
    outputs:
      - outputs/tab_1.html

  - id: tab_1_format
    type: format
    parent: tab_1
    code: code/format_tab_1.R
```

Root steps (nothing in-repo produces their inputs) omit `parents:`
entirely — never write `parents: []`. A step that reads another step’s
`outputs:` declares `parents: [<upstream id>]`. See
`rep-template/replication.yml` for a fully commented gold example.

## Writing replication scripts

Replication scripts define an analysis function named `make_<id>()` (for
example `make_fig_1()`) and, optionally, a `format_<id>()` for display.
Scripts are pure definitions — no interactive footer, no
[`sys.nframe()`](https://rdrr.io/r/base/sys.parent.html) guard. Yaml
(`steps:`) is what decides when and with what inputs each function runs.

### Figures

``` r

make_fig_1 <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(group, value)) +
    ggplot2::geom_col()
}
```

### Tables

``` r

make_tab_1 <- function(data) {
  dplyr::summarise(data, mean_value = mean(value))
}

format_tab_1 <- function(object) {
  # optional: convert the analysis object to HTML for display
  as.character(object)
}
```

When `replication.yml` lists a `format` field, the package passes the
analysis output through the corresponding `format_*` function before
display or artifact export.

### Pure definitions; yaml executes

Authors write `make_*` / `format_*` only. \[run_replication()\] loads
data from yaml `data:` / `inputs:`, calls `make_*`, and applies
`format_*` when requested. No interactive footer is required. For a
copy-pasteable recipe, use `get_code(doi, what, mode = "run")` (appends
the yaml-implied call) or prefer `run_replication(doi, what)` directly.

## Folder-backed replications

Studies maintained as a **simple Git repository** (`code/`, `data/`,
`outputs/`) can be linked from the registry. Keep a stub in
`studies/<folder>.yml` only:

``` yaml
paper:
  doi: https://doi.org/10.1177/00491241211036161
  title: Bounding Causes of Effects With Mediators
  materials: folder
  study_repo: replicate-anything/rep-10.1177-00491241211036161
  study_folder: rep-10.1177-00491241211036161
  study_ref: main
repo: replicate-anything/rep-10.1177-00491241211036161
```

The full `steps:` pipeline lives in the study repo’s `replication.yml`.
Display outputs live in `outputs/` (from
[`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md)).
There is **no study-local `registry/` folder** — a maintainer writes the
stub above directly from this yaml.

**From the study repository root:**

``` r

library(replicateEverything)

options(
  replicateEverything.registry_root = "../registry",
  replicateEverything.use_sibling_packages = TRUE
)

# 1. Build outputs/manifest.json
build_study_outputs(location = ".", install_deps = TRUE)

# 2. Run tests
testthat::test_dir("tests/testthat")

# 3. Contributor: validate (checklist only — writes nothing)
check_and_bake_study(".", build_artifacts = FALSE, registry_root = "../registry")

# 4. Maintainer: write the stub into a local registry checkout
sync_study_to_registry(".", registry_root = "../registry")

# One-call alternative for a maintainer (check + sync):
# register_study(".", registry_root = "../registry")
```

See
[`vignette("folder-replication-checklist", package = "replicateEverything")`](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md)
for the full workflow.

## Package-backed replications

Studies maintained as standalone R packages can be linked from the
registry. Keep a stub file `studies/<folder>.yml` that points to the
package (no materials in the registry):

``` yaml
paper:
  doi: https://doi.org/10.1371/journal.pone.0278337
  title: "Public support for global vaccine sharing in the COVID-19 pandemic"
  package: rep1371journalpone0278337
  package_folder: rep-10.1371-journal.pone.0278337
  package_repo: replicate-anything/rep-10.1371-journal.pone.0278337
  package_ref: main
repo: replicate-anything/rep-10.1371-journal.pone.0278337
```

`replicateEverything` merges the full `steps:` DAG from the study
package `replication.yml` when the registry stub omits it. Display
artifacts live in the study package at `inst/report/artifacts/`, built
with the same
[`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md)
entrypoint used for folder-backed studies.

Validate, then register a package-backed study (same APIs as
folder-backed; no study-local registry handoff):

``` r

options(replicateEverything.registry_root = "/path/to/registry")

check_and_bake_study("/path/to/rep_package", full_replication = FALSE)
sync_study_to_registry("/path/to/rep_package")
# or in one call: register_study("/path/to/rep_package")
```

See
[`vignette("package-replication-checklist", package = "replicateEverything")`](https://replicate-anything.github.io/replicateEverything/articles/package-replication-checklist.md)
for requirements.

**Local development (monorepo):** place the study package as a sibling
folder next to `registry/`. Enable sibling resolution with:

``` r

options(replicateEverything.use_sibling_packages = TRUE)
options(replicateEverything.replication_packages_root = "/path/to/monorepo")
```

**Published packages:** set `package_repo` (and top-level `repo`) to the
GitHub slug. The package installs via
[`remotes::install_github()`](https://remotes.r-lib.org/reference/install_github.html)
when no local sibling is found.

Optional overrides:

- `paper.package_path` — absolute or relative path to the package root
- `options(replicateEverything.replication_packages = list(pkgname = "/path"))`

Linked study packages export only pure `make_*()` / `format_*()`
analysis helpers named in yaml (plus any true study helpers and packaged
data). They must **not** define or ship
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md),
[`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md),
[`load_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/load_artifact.md),
or
[`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
— those verbs live only in **replicateEverything**, which calls them
against the study.

## API overview

| Task | Function |
|----|----|
| Browse registry | [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md), [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md) |
| List replications | [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md), `list_replications(..., grouped = TRUE)` |
| View source code | [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md) |
| Run one replication | [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md) |
| Replicate full paper | `run_replication(doi, "everything")` |
| Build study outputs (folder or package) | [`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md) |
| Validate a study (+ optional bake) | [`check_and_bake_study()`](https://replicate-anything.github.io/replicateEverything/reference/check_and_bake_study.md) |
| Validate study layout + tests | [`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md) |
| Sync a study into the registry (maintainer) | [`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md) |
| Validate then sync in one call (maintainer) | [`register_study()`](https://replicate-anything.github.io/replicateEverything/reference/register_study.md) |
| Check precomputed outputs exist | [`validate_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/validate_outputs.md) |
| Registry-wide output check | `validate_outputs(doi = "everywhere", what = "everything")` |
| List bundled AI skills | [`ai_skills()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skills.md), [`ai_skill()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skill.md) |
| Registry health check | [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md) |
| Shiny demo | [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md), [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md) |

Set `install_deps = TRUE` on run functions to install missing CRAN
dependencies automatically.

### AI skills

This package ships AI-readable workflow guides under `inst/ai/skills/`.
Use them with ChatGPT, Claude, Cursor, Copilot, or other assistants.

``` r

ai_skills()
# [1] "dataverse_to_replicateEverything" "folder_replication"
# [3] "include_study_in_registry"

cat(ai_skill("dataverse_to_replicateEverything"))
```

Installed path:

``` r

system.file("ai", "skills", "dataverse_to_replicateEverything.md", package = "replicateEverything")
```

### Local registry development

Point the package at a local clone of the registry:

``` r

options(replicateEverything.registry_root = "/path/to/registry")
options(replicateEverything.index = read.csv("/path/to/registry/index.csv"))
```

## Contributor workflow

1.  **Browse the registry** —
    [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)
    or `search_papers("keyword")`
2.  **Set up a study repo (or package)** — follow
    [`vignette("folder-replication-checklist")`](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md)
    or
    [`vignette("package-replication-checklist")`](https://replicate-anything.github.io/replicateEverything/articles/package-replication-checklist.md);
    write `steps:` as a DAG, tracing real author I/O
3.  **Add your data and code** — place processed data in `data/` and
    scripts in `code/` (or in the package’s `R/` + `data/` for
    package-backed studies)
4.  **Bake and test locally** — `build_study_outputs(".")`, then
    `testthat::test_dir("tests/testthat")`
5.  **Validate** — `check_and_bake_study(".")`; this checks structure,
    yaml, outputs, and tests. It never writes into the study repo or a
    registry — it only reports pass/fail
6.  **Hand off to a maintainer** — send the study repo (or package)
    address; a maintainer with a local
    [registry](https://github.com/replicate-anything/registry) checkout
    runs `sync_study_to_registry(path)` (or `register_study(path)` to
    validate + sync in one call), which writes `studies/<folder>.yml`
    and rebuilds `index.csv` directly from your `replication.yml` — **no
    study-local `registry/` handoff, ever**

There is exactly **one** registry entrypoint for both layouts:
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
/
[`register_study()`](https://replicate-anything.github.io/replicateEverything/reference/register_study.md).
Full study materials (`code/`, `data/`, `outputs/`, package source) are
never copied into the registry repository — only the lightweight stub
and `index.csv` row live there.

## Developer workflow

``` bash
git clone https://github.com/replicate-anything/replicateEverything
cd replicateEverything
```

``` r

devtools::install()
devtools::test()
devtools::check()
```

Documentation site:
[replicate-anything.github.io/replicateEverything](https://replicate-anything.github.io/replicateEverything/)

## Shiny demo app

Try the [live demo](https://shiny2.wzb.eu/ipi/replicate/) at WZB, or run
the bundled app from an installed package:

``` r

library(replicateEverything)
run_shiny_app()                              # run from installed package
save_local_shiny("/path/to/shiny/replicate") # materialize app.R + www/ for serving
```

See
[`vignette("shiny-app", package = "replicateEverything")`](https://replicate-anything.github.io/replicateEverything/articles/shiny-app.md)
for server update workflows and `local.R` configuration.

## Links

- **Package:**
  [github.com/replicate-anything/replicateEverything](https://github.com/replicate-anything/replicateEverything)
- **Registry:**
  [github.com/replicate-anything/registry](https://github.com/replicate-anything/registry)
- **Documentation:**
  [replicate-anything.github.io/replicateEverything](https://replicate-anything.github.io/replicateEverything/)

## Report bugs

Open an issue at
[github.com/replicate-anything/replicateEverything/issues](https://github.com/replicate-anything/replicateEverything/issues).

## License

MIT
