# replicateEverything

<!-- badges: start -->
<!-- badges: end -->

<img src="man/figures/logo.png" align="right" height="139" alt="replicateEverything logo" />

**Tools to discover, run, and contribute computational replications of empirical research papers.**

`replicateEverything` connects to a public [replication registry](https://github.com/replicate-anything/registry), retrieves replication materials (metadata, processed data, and analysis code), and reproduces figures and tables from published studies in a standardized workflow. The goal is to make research **transparent, modular, and easily reproducible**.

## Key features

- **Discovery** — search the registry, look up papers by DOI, and inspect available replications
- **One-line replication** — run a single figure or table, or reproduce an entire paper with `replicate_paper()`
- **Registry-backed materials** — fetch data and code from GitHub without manual downloads
- **Package-backed studies** — link standalone R packages as replication backends (local monorepo or GitHub install)
- **Artifacts** — load, validate, and save precomputed outputs (PNG, HTML, RDS) for fast display
- **Display pipeline** — optional `format_*` steps turn analysis objects into HTML tables and ggplot figures
- **Contributor tooling** — scaffold a new replication folder with `create_replication_template()`

## Project status

The inspiration for this package came from an idea by [Macartan Humphreys](https://macartan.github.io), Director of the [Institutions and Political Inequality](https://wzb-ipi.github.io/) Research Group at [WZB](https://www.wzb.eu/de), in a [2024 talk](https://macartan.github.io/slides/2024_standards.html#/reproduction-out-of-the-box-2) to a Lab² audience. The project is under active development. Feedback is welcome — contact [Vermon Washington](mailto:vermon.washington@wzb.eu) or [Macartan Humphreys](mailto:macartan.humphreys@wzb.eu).

## Installation

Once accepted on CRAN, install with `install.packages("replicateEverything")`. Until then, install from GitHub with `remotes` or `devtools`:

```r
remotes::install_github("replicate-anything/replicateEverything")
# or
devtools::install_github("replicate-anything/replicateEverything")
```

Requires R (>= 4.1.0).

## Quick start

```r
library(replicateEverything)

# Look up bibliographic metadata
get_doi_metadata("10.1177/00491241211036161")

# Search the registry by title keyword
search_papers("causes")

# See what can be replicated for a paper
list_replications("10.1177/00491241211036161")

# Run one figure or table
run_replication("10.1177/00491241211036161", "fig_1")

# Reproduce every registered result
replicate_paper("10.1177/00491241211036161")
```

For a worked example with output, see the [replication vignette](https://replicate-anything.github.io/replicateEverything/articles/replication-example.html).

## How it works

Replication materials live in the [registry](https://github.com/replicate-anything/registry). Each paper has a folder under `papers/` with a `replication.yml` manifest, plus `data/`, `code/`, and optionally `artifacts/`.

```
Registry
  └── papers/<folder>/
        replication.yml
        data/
        code/
        artifacts/   (optional precomputed outputs)
              ↓
      replicateEverything
              ↓
      figures & tables in your R session
```

The package reads `replication.yml`, downloads the listed data and scripts, sources the analysis functions, and returns typed result objects suitable for printing, saving, or display in a Shiny app.

### Registry layout

Every replication repository follows a standard structure:

```
papers/
  <folder>/
    replication.yml
    data/
      fig_1.csv
      tab_1.csv
    code/
      fig_1.R
      tab_1.R
    artifacts/          # optional
      fig_1.png
      tab_1.html
      manifest.json
```

The `<folder>` name comes from the registry `index.csv` (for example `10.1177_00491241211036161` or `10.1017S0003055403000534`).

### Example `replication.yml`

```yaml
paper:
  title: Market Design and Moral Behavior
  authors:
    - Bartling, Björn
    - Fehr, Ernst
  year: 2024
  doi: 10.1257/aer.20221688
  journal: American Economic Review

replications:
  - id: fig_1
    type: figure
    label: Figure 1
    description: Example figure
    data: data/fig_1.csv
    code: code/fig_1.R
    artifact: artifacts/fig_1.png
    dependencies:
      - ggplot2

  - id: tab_1
    type: table
    label: Table 1
    description: Example table
    data: data/tab_1.csv
    code: code/tab_1.R
    format: format_tab_1
    artifact: artifacts/tab_1.html
    dependencies:
      - dplyr
      - gt
```

## Writing replication scripts

Replication scripts define an analysis function named `make_<id>()` (for example `make_fig_1()`). The legacy names `generate_figure()` and `generate_table()` are still supported.

### Figures

```r
make_fig_1 <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(group, value)) +
    ggplot2::geom_col()
}
```

### Tables

```r
make_tab_1 <- function(data) {
  dplyr::summarise(data, mean_value = mean(value))
}

format_tab_1 <- function(object) {
  # optional: convert the analysis object to HTML for display
  as.character(object)
}
```

When `replication.yml` lists a `format` field, the package passes the analysis output through the corresponding `format_*` function before display or artifact export.

### Self-contained scripts

Scripts can also be run directly from the paper folder. Use `self_run()` at the bottom of a script so the package can source only the function definitions:

```r
if (sys.nframe() == 0) {
  self_run(make_fig_1, "data/fig_1.csv")
} else {
  generate_figure <- make_fig_1
}
```

## Package-backed replications

Studies maintained as standalone R packages can be linked from the registry. Keep a paper folder in the registry with a `replication.yml` that points to the package:

```yaml
paper:
  doi: https://doi.org/10.1371/journal.pone.0278337
  title: "Public support for global vaccine sharing in the COVID-19 pandemic"
  package: rep1371journalpone0278337
  package_folder: rep_10.1371_journal.pone.0278337
  package_repo: replicate-anything/rep_10.1371_journal.pone.0278337
  package_ref: main
repo: replicate-anything/rep_10.1371_journal.pone.0278337
```

**Local development (monorepo):** place the study package as a sibling folder next to `registry/`. Enable sibling resolution with:

```r
options(replicateEverything.use_sibling_packages = TRUE)
options(replicateEverything.replication_packages_root = "/path/to/monorepo")
```

**Published packages:** set `package_repo` (and top-level `repo`) to the GitHub slug. The package installs via `remotes::install_github()` when no local sibling is found.

Optional overrides:

- `paper.package_path` — absolute or relative path to the package root
- `options(replicateEverything.replication_packages = list(pkgname = "/path"))`

Linked study packages should export: `list_replications()`, `run_replication(id, install_deps = FALSE)`, and `load_artifact(id)`.

## API overview

| Task | Function |
|------|----------|
| Search registry | `search_papers()`, `load_index()` |
| DOI metadata | `get_doi_metadata()`, `normalize_doi()` |
| Find repository | `find_repo()` |
| List replications | `list_replications()` |
| View source code | `get_code()` |
| Run one replication | `run_replication()`, `render_replication()` |
| Replicate full paper | `replicate_paper()` |
| Format for display | `format_for_display()`, `render_for_display()` |
| Precomputed outputs | `load_artifact()`, `save_artifact()`, `artifact_available()` |
| Validate | `validate_replication()`, `validate_artifact()` |
| Contribute | `create_replication_template()` |

Set `install_deps = TRUE` on run functions to install missing CRAN dependencies automatically.

### Local registry development

Point the package at a local clone of the registry:

```r
options(replicateEverything.registry_root = "/path/to/registry")
options(replicateEverything.index = read.csv("/path/to/registry/index.csv"))
```

## Contributor workflow

1. **Fetch metadata** — `get_doi_metadata("10.1177/00491241211036161")`
2. **Scaffold a folder** — `create_replication_template("10.1177/00491241211036161")`
3. **Add your data and code** — place processed data in `data/` and scripts in `code/`
4. **Test locally** — run scripts in the R console or with `run_replication()`
5. **Submit to the registry** — clone [replicate-anything/registry](https://github.com/replicate-anything/registry), move your paper folder into `papers/`, and open a pull request

```bash
git clone https://github.com/replicate-anything/registry
mv 10.1177_00491241211036161 registry/papers/
cd registry
git add .
git commit -m "Add replication for 10.1177/00491241211036161"
git push
```

## Developer workflow

```bash
git clone https://github.com/replicate-anything/replicateEverything
cd replicateEverything
```

```r
devtools::install()
devtools::test()
devtools::check()
```

Documentation site: [replicate-anything.github.io/replicateEverything](https://replicate-anything.github.io/replicateEverything/)

## Links

- **Package:** [github.com/replicate-anything/replicateEverything](https://github.com/replicate-anything/replicateEverything)
- **Registry:** [github.com/replicate-anything/registry](https://github.com/replicate-anything/registry)
- **Documentation:** [replicate-anything.github.io/replicateEverything](https://replicate-anything.github.io/replicateEverything/)

## Report bugs

Open an issue at [github.com/replicate-anything/replicateEverything/issues](https://github.com/replicate-anything/replicateEverything/issues).

## License

MIT
