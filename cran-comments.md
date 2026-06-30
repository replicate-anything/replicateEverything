## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* local macOS install, R 4.x
* R CMD check --as-cran

## Downstream dependencies

There are no downstream dependencies for this package.

## Comments for CRAN

This is the first CRAN submission of replicateEverything.

### Network access

The package is designed to fetch replication materials (metadata, data, code, and artifacts) from a public GitHub registry at runtime. Core functions such as `load_index()`, `list_replications()`, `run_replication()`, and `replicate_paper()` may access the network when users invoke them.

* Package examples that require network access are wrapped in `\dontrun{}`.
* The vignette sources live in `vignettes/`; pre-built HTML is shipped in `inst/doc/` for installs that skip vignette builds.
* Tests that require network access or GitHub API calls use `skip_on_cran()`.
* Tests that require a local registry fixture or sibling study packages also skip when those resources are unavailable.

### Optional dependency installation

Replication runs do not install CRAN packages unless the user explicitly passes `install_deps = TRUE` to run/render functions. This keeps default behavior conservative on CRAN check machines and for end users.

### Suggested packages

* `ggplot2` and `haven` are used optionally at runtime when saving ggplot artifacts or reading Stata `.dta` files.
* `remotes` and `devtools` are used optionally when loading package-backed study replications from GitHub or local paths.
* `DiagrammeR`, `knitr`, and `rmarkdown` support the package vignette.

We have run `R CMD check --as-cran` locally with 0 errors, 0 warnings, and 0 notes.
