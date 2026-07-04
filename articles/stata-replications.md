# Stata replications

## Overview

**replicateEverything is an R package.** It orchestrates replications
from R: loading registry metadata, fetching study folders or packages,
and running code. Stata-backed entries are **first-class**: the package
calls Stata in batch mode, captures logs or images, and can format them
for display in R or Shiny.

You can also register **bilingual** studies with paired R and Stata
entries (same `group`, different `engine`). The [Acemoglu et
al.](https://doi.org/10.1257/aer.91.5.1369) study in the registry is an
example: each table has `tab_N` (R) and `tab_N_stata` (Stata).

## How Stata replications work in R

1.  **`replication.yml`** marks an entry with `engine: stata` (or a
    `.do` file path).
2.  **[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)**
    detects the engine and runs Stata in batch mode when
    `language = "stata"` (or when Stata is the only engine).
3.  R locates Stata via
    **[`find_stata_executable()`](https://replicate-anything.github.io/replicateEverything/reference/find_stata_executable.md)**,
    writes a small runner, and invokes Stata batch mode
    (`StataMP-64.exe /e do ...` on Windows).
4.  Output is returned as an R object of class
    **`stata_replication_result`** — a list with (at minimum)
    `output_path` (log or image), `study_root`, and `replication_id`.
5.  If the entry defines `format: code/format_stata.R`, R reads the
    Stata log and builds an HTML table for Shiny / `format = TRUE`.

The returned object is **not** a Stata dataset inside R; with
`format = FALSE` you get a handle to Stata output on disk (usually a
`.log` file). Use `format = TRUE` for an HTML table when a `format:`
step is registered.

## Finding Stata

``` r

library(replicateEverything)

find_stata_executable()
```

If this returns `NULL`, R will stop with a clear error when you run a
Stata replication:

> Replication tab_1_stata requires Stata. Install Stata or set
> options(replicateEverything.stata_executable = …).

**Point R at your installation:**

``` r

options(replicateEverything.stata_executable = "C:/Program Files/Stata18/StataMP-64.exe")
# macOS example:
# options(replicateEverything.stata_executable = "/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp")
```

[`find_stata_executable()`](https://replicate-anything.github.io/replicateEverything/reference/find_stata_executable.md)
checks, in order:

1.  `getOption("replicateEverything.stata_executable")`
2.  `PATH` (`stata-mp`, `stata-se`, …)
3.  Common install locations (Windows Program Files,
    `/Applications/Stata/…`, Linux `/usr/local/stata*`)

## Running from R

``` r

options(
  replicateEverything.registry_root = "/path/to/replicate_everything/registry",
  replicateEverything.study_folders_root = "/path/to/replicate_everything",
  replicateEverything.use_sibling_packages = TRUE
)

# Table 1 in R (default when both engines exist)
run_replication("10.1257/aer.91.5.1369", "tab_1")

# Same table in Stata
run_replication("10.1257/aer.91.5.1369", "tab_1", language = "stata", format = TRUE)

# Legacy suffixed ids still work
run_replication("10.1257/aer.91.5.1369", "tab_1_stata", format = TRUE)
```

List engines available for a study:

``` r

reps <- list_replications("10.1257/aer.91.5.1369")
table(vapply(reps, function(x) x$engine %||% "r", character(1)))
```

## Running the same code in Stata yourself

replicateEverything is for **orchestration from R**. To work in native
Stata (debugging, extending analysis), use the study repository
directly.

### 1. Clone the study repo

    git clone https://github.com/replicate-anything/rep-10.1257-aer.91.5.1369.git
    cd rep-10.1257-aer.91.5.1369

Data files live under `data/` (e.g. `maketable1.dta`). They are
referenced from `replication.yml` and must be present locally (download
from the study’s `source_url` if not in git).

### 2. Table 1 — runner vs analysis

The registry uses two layers:

| File | Role |
|----|----|
| `code/tab_1.do` | **Runner** — sets paths, opens a log, calls the analysis |
| `code/maketable1.do` | **Analysis** — MIT original code (`summ` blocks for Table 1) |

From the **study repo root** in Stata:

    do "code/tab_1.do"

The runner sets `global maindir` to the repo root, `global datadir` to
`data/`, and writes `artifacts/staging/tab_1_stata.log`. That matches
what R runs via
[`run_stata_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_stata_replication.md).

### 3. View code from R before opening Stata

``` r

cat(get_code("10.1257/aer.91.5.1369", "tab_1_stata"), sep = "\n")
```

[`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
merges the runner with `stata_source` (`code/maketable1.do`) so you see
the full script Shiny’s Code tab would show.

### 4. Minimal manual setup (without the runner)

If you already have the repo open in Stata:

    global maindir "C:/path/to/rep-10.1257-aer.91.5.1369"
    global datadir "${maindir}/data"
    do "${maindir}/code/maketable1.do"

Use forward slashes or Stata’s path conventions on your OS.

## Bilingual entries in `replication.yml`

Acemoglu Table 1 is declared twice:

``` yaml
  - id: tab_1
    group: tab_1
    engine: r
    code: code/tab_1.R
    ...

  - id: tab_1_stata
    group: tab_1
    engine: stata
    code: code/tab_1.do
    stata_source: code/maketable1.do
    format: code/format_stata.R
    output: artifacts/staging/tab_1_stata.log
```

Shiny and
[`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
treat `group` as one logical table and run **both** engines when listed.

## Example: Table 1 from R

``` r

library(replicateEverything)

# Optional: local monorepo + Stata path
options(
  replicateEverything.registry_root = "c:/path/to/replicate_everything/registry",
  replicateEverything.study_folders_root = "c:/path/to/replicate_everything",
  replicateEverything.use_sibling_packages = TRUE,
  replicateEverything.stata_executable = "C:/Program Files/Stata18/StataMP-64.exe"
)

# R translation
run_replication("10.1257/aer.91.5.1369", "tab_1", format = TRUE)

# Original Stata (when Stata is installed)
run_replication("10.1257/aer.91.5.1369", "tab_1_stata", format = TRUE)
```

When Stata is unavailable, the R entry still runs; Stata entries fail
gracefully with an install hint.

## Related reading

- [Folder replication
  checklist](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md)
  — layout for folder-backed studies, including `engine: stata`
- [Registry
  audit](https://replicate-anything.github.io/replicateEverything/articles/audit.md)
  —
  [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  runs all R and Stata entries with a per-object time limit
