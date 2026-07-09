# Replication Examples Using Code

``` r

library(replicateEverything)
```

See
[`vignette("meet-the-functions", package = "replicateEverything")`](https://replicate-anything.github.io/replicateEverything/articles/meet-the-functions.md)
for a tour of every main function.

## Quick start

``` r

# Browse the registry index
head(load_index()[, c("doi", "title", "year")])

# Search by title keyword
search_papers("causes")

# See what can be replicated for a paper
list_replications("10.1177/00491241211036161")

# Run one figure or table
run_replication("10.1177/00491241211036161", "fig_1")

# Reproduce every registered result
run_replication("10.1177/00491241211036161", "everything")
```

## How it works

The [registry](https://github.com/replicate-anything/registry) indexes
studies with lightweight stub files in `studies/<folder>.yml` and
`index.csv`. **Replication materials live in separate study
repositories**, not inside the registry.

`replicateEverything` reads the stub, fetches the full `replication.yml`
from the study repo or package, loads data, sources analysis scripts,
and returns typed result objects.

    Registry (index only)              Study repository
      studies/<folder>.yml  ───────►    replication.yml
      index.csv                        data/
                                       code/
                                       artifacts/   (folder-backed)
                  ↓
          replicateEverything
                  ↓
          figures & tables in your R session

### Two study layouts

**Folder-backed** studies use a simple Git repository:

    rep-<doi-slug>/
      replication.yml
      data/
      code/
      artifacts/
      tests/testthat/

**Package-backed** studies use a standalone R package:

    rep_<doi_slug>/
      DESCRIPTION
      R/
      data/
      replication.yml
      inst/report/artifacts/

In both cases the registry holds only a **stub**
(`studies/<folder>.yml`) pointing at the study repo. See the folder and
package replication checklists for contributor workflows.

### Shiny demo

A [live demo](https://shiny2.wzb.eu/ipi/replicate/) runs at WZB. The
package also bundles the app in `inst/shiny/`:

``` r

run_shiny_app()
save_local_shiny("/path/to/shiny/replicate")
```

See
[`vignette("shiny-app", package = "replicateEverything")`](https://replicate-anything.github.io/replicateEverything/articles/shiny-app.md)
for deployment on Shiny Server.

## System architecture

## Run a single replication

``` r

run_replication("10.1177/00491241211036161", "fig_1")
```

## Replicate an entire paper

``` r

run_replication("10.1177/00491241211036161", "everything")
```
