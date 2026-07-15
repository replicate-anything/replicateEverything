# Shiny demo app

The **replicateEverything** package includes a Shiny demo in
`inst/shiny/` (`app.R` plus `www/` assets). A live instance runs at
<https://shiny2.wzb.eu/ipi/replicate/>. You can also run the app from an
installed package, or copy it into a Shiny Server directory.

## Install

``` r

# install.packages("remotes")
remotes::install_github("replicate-anything/replicateEverything")
```

Suggested packages for the app: `shiny`, `bslib`, and optionally
`shinyWidgets`.

``` r

install.packages(c("shiny", "bslib", "shinyWidgets"))
```

## Option 1: Run from the package

``` r

library(replicateEverything)
run_shiny_app()
```

This launches `inst/shiny` inside the installed package. The app uses
the installed `replicateEverything` version and does not try to
reinstall itself from GitHub.

For local monorepo development (sibling `registry/` and study packages),
copy `inst/shiny/local.R.example` to `local.R` in your working directory
before calling
[`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md),
or set options manually:

``` r

options(
  replicateEverything.registry_root = "/path/to/registry",
  replicate_shiny.auto_update_replicate_everything = FALSE
)
```

## Option 2: Copy for Shiny Server

Many servers expect a directory with `app.R` (for example
`shiny/replicate/`). After installing or updating the package,
materialize the bundled app:

``` r

library(replicateEverything)
save_local_shiny("/srv/shiny/replicate")
```

This writes:

- `app.R`
- `www/` (logo and favicons)
- `local.R.example` (template only)
- `deploy-options.R` (display-only vs live run; always overwritten on
  deploy)
- `BUNDLE_SHA` (package build stamp)

**`local.R` is never overwritten**, so server-specific settings survive
updates.

### Display-only vs Live Run

By default, deployed apps allow **Live Run** (same as local
[`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)).
For a public demo that should only show precomputed artifacts, deploy in
display-only mode:

``` r

save_local_shiny("/srv/shiny/replicate", live_run = FALSE)
```

This writes `deploy-options.R` with
`options(replicate_shiny.live_run = FALSE)`. The app hides Run buttons
and shows a subtle banner. Use `live_run = TRUE` (the default) when the
server should execute replications on demand.

For local development, set `options(replicate_shiny.live_run = TRUE)` in
`local.R` if you copied a display-only deploy bundle but want Live Run
while developing (see `local.R.example`).

### Server update workflow

On the **Shiny host**, use the same R library that Shiny Server /
Connect loads (not necessarily your interactive SSH session). Typical
causes of “old code” after `install_github()`:

1.  **Two-part deploy** — `app.R` is copied to the deploy directory by
    [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md),
    but `replicate_fn()` calls the **installed** package namespace. You
    must update **both** the library install and the deploy bundle.
2.  **Different [`.libPaths()`](https://rdrr.io/r/base/libPaths.html)**
    — interactive R may install to `~/R/...` while Shiny runs as `shiny`
    or `rstudio-connect` with site library only.
3.  **Shiny workers not restarted** — long-lived R processes keep the
    old namespace loaded until the service is restarted.
4.  **`local.R` devtools::load_all** — if a sibling monorepo checkout
    exists, `local.R` or auto-detection can shadow the installed
    package.
5.  **Stale GitHub cache** — use
    `remotes::install_github(..., force = TRUE)` or `upgrade = "always"`
    when in doubt.

**Checklist** (run on the Shiny server as the Shiny service user when
possible):

``` r

# 1. Install into the library Shiny actually uses
.libPaths()
remotes::install_github(
  "replicate-anything/replicateEverything",
  upgrade = "always",
  force = TRUE
)
library(replicateEverything)

# 2. Verify the installed build before copying app.R
package_deploy_diagnostics()  # or pass your deploy path explicitly

# 3. Materialize app.R + www/ + BUNDLE_SHA + deploy-options.R
save_local_shiny("/srv/shiny/replicate")

# 4. Confirm bundle matches package
package_deploy_diagnostics("/srv/shiny/replicate")
```

**Restart ALL Shiny processes** after step 3 (systemd unit,
`shiny-server`, Posit Connect publisher restart, etc.). Reloading the
browser is not enough.

**Verify in the browser footer:**

- `pkg` SHA — installed package (`RemoteSha` or bundled stamp)
- `app` SHA — `BUNDLE_SHA` written beside deployed `app.R` (must match
  `pkg`)
- `lib` — path from `system.file(package = "replicateEverything")`; if
  this differs from the path in `deploy-options.R`, the app was deployed
  from a different R session/library than the one serving requests

A yellow banner appears when `app` and `pkg` SHAs differ.

### Diagnose from R

``` r

replicateEverything::package_deploy_diagnostics("/srv/shiny/replicate")
```

This prints package version, library path,
[`.libPaths()`](https://rdrr.io/r/base/libPaths.html), deploy directory,
`BUNDLE_SHA`, whether key functions exist
(e.g. `shiny_feedback_github_category_url`), Live Run / feedback
settings, and missing-function hints.

### Display artifacts

Shiny **Display** mode serves precomputed files from each study’s
`outputs/` (folder-backed) or the study package’s report outputs.
Maintainers can verify those files exist with \[validate_outputs()\] —
per study (`location =` or `doi` + `what = "everything"`) or
registry-wide (`doi = "everywhere"`, `what = "everything"`). See
[`vignette("maintainer-setup")`](https://replicate-anything.github.io/replicateEverything/articles/maintainer-setup.md).

### Server configuration

On a shared server, create `local.R` once (from `local.R.example`):

``` r

options(
  replicateEverything.registry_root = "/path/to/registry",
  replicate_shiny.auto_update_replicate_everything = FALSE,
  replicate_shiny.auto_install_study_packages = FALSE
)
```

If you rely on the public GitHub registry, you do not need a local
`registry/` checkout; omit `replicateEverything.registry_root`.

### Deploy checklist (shiny2.wzb.eu / subpath hosts)

After
[`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)
and `remotes::install_github(...)`:

1.  **Restart Shiny workers** so the installed package and `app.R`
    reload together.
2.  **Set the public mount URL** in `local.R` (once):
    `Sys.setenv(REPLICATE_SHINY_BASE_URL = "https://shiny2.wzb.eu/ipi/replicate")`
    Share links and docs use this base; query params (`?doi=...`) are
    appended by the app.
3.  **Preserve query strings on redirects.** If
    `https://host/ipi/replicate?doi=...` redirects to `/ipi/replicate/`
    without `?doi=...`, fix the reverse proxy (nginx: use
    `$is_args$args` on trailing-slash redirects).
4.  **Clear stale study cache** when code-link fixes ship:
    `unlink(list.files(tools::R_user_dir("replicateEverything", "cache"), "study-repos", full.names = TRUE), recursive = TRUE)`
    Browser sessions materialize folder-backed studies under
    `.../study-repos/<org_repo>/<ref>/`; sibling monorepo checkouts
    (from `local.R`) take precedence when present.
5.  **Optional code-viewer diagnostics:**
    `options(replicate_shiny.debug_code_viewer = TRUE)` in `local.R`
    shows the study root used on the Code tab.
6.  **Verify footer SHAs:** `pkg` and `app` should match after deploy;
    mismatch means
    [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)
    was not re-run after `install_github()`.
7.  **Verify footer `lib` path** matches
    [`package_deploy_diagnostics()`](https://replicate-anything.github.io/replicateEverything/reference/package_deploy_diagnostics.md)
    on the server; if not, you updated a different R library than Shiny
    uses.
8.  **Run diagnostics before and after deploy:**
    `replicateEverything::package_deploy_diagnostics("<deploy-dir>")`.

## Code tab: inspect sourced files

On the **Code** tab, Stata runners are shown as authored (not inlined).
Lines such as `do "${maindir}/code/tables/mk_tab_1.do"` are clickable
when the target file exists under the study root. Breadcrumb navigation
and **Back** let you walk nested `do` /
[`source()`](https://rdrr.io/r/base/source.html) calls without stacking
modals.

**Path globals:** folder-backed Stata studies set `global maindir` in
`code/helpers/init_study_paths.do` to the directory containing
`replication.yml` (walked up from the working directory at run time).
The Shiny viewer uses the same mapping via
`default_stata_globals(study_root)` (`maindir`, `rawdir`, `processed`,
`result`). Live runs may override `result` with
`REPLICATE_STATA_RESULT`.

Implementation lives in `R/code_links.R`
([`build_code_file_graph()`](https://replicate-anything.github.io/replicateEverything/reference/build_code_file_graph.md),
[`render_code_html_with_links()`](https://replicate-anything.github.io/replicateEverything/reference/render_code_html_with_links.md)).
A future `code_manifest:` block in `replication.yml` may point at
Dataverse-hosted scripts (similar to the data manifest pattern).

**Not yet parsed:** unquoted `do` paths with embedded spaces,
`` `local' `` / compound double quotes, `source(file.path(...))`, and
Python `exec`/`runpy`.

## Former standalone repository

The app previously lived in a separate **replicate-shiny** repository
beside **replicateEverything**. That repository is deprecated; use the
functions above.
