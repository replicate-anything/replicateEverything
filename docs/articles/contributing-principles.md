# Contributing principles

Heart of contributing a study under **Contributing replications**. Gold
shape:
[`rep-template`](https://github.com/replicate-anything/rep-template).
Detail lives in the linked checklists — use this page as the order of
work and the principles gate.

## Walkthrough: four steps

### 1. First write the yaml (wiring)

Create `replication.yml` before filling the repo with materials. Declare
paper metadata, `maintainer:`, `collections:`, `languages:`, and a
unified `steps:` DAG that points at originals (URLs, Dataverse file ids,
`engine: dataverse`) rather than shipping binaries.

Field-level contract and examples: [Folder replication
checklist](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md)
or [Package replication
checklist](https://replicate-anything.github.io/replicateEverything/articles/package-replication-checklist.md).
Stata engines: [Stata
replications](https://replicate-anything.github.io/replicateEverything/articles/stata-replications.md).

### 2. Then make `code/` and `data/` (if any)

Add step scripts under `code/` (thin runners; pure `make_*` /
`format_*`). Add `data/` only when files must live in-repo. Prefer
package fetch helpers over study-local download scripts — see **Wire, do
not ship** below.

### 3. Then bake (creates `outputs/`)

From the study root:

``` r

library(replicateEverything)
list_replications("local")
describe_study_dag("local")
check_and_bake_study(".", build_artifacts = TRUE)
```

That validates the yaml DAG and writes display products under `outputs/`
(plus `manifest.json`). Do not invent a parallel bake path in the study.

### 4. Then share

Push a **public** study repo so Shiny can fetch root `replication.yml`.
Contributor stops at a green bake; a registry **maintainer** syncs the
stub — no study-local `registry/` folder. See the folder/package
checklists for
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
/
[`register_study()`](https://replicate-anything.github.io/replicateEverything/reference/register_study.md).

------------------------------------------------------------------------

## Principles checklist

Tick as you go. Details that belong in the folder, package, Stata, or
Dataverse articles are linked rather than repeated.

### Wire, do not ship

Keep study repos **light**. Yaml points at originals; do not ship
wholesale deposits or invent download helpers.

Prefer **yaml wiring** (declared URLs / file ids / `engine: dataverse`)
over shipping raw deposits

Prefer package helpers
([`fetch_dataverse_file()`](https://replicate-anything.github.io/replicateEverything/reference/fetch_dataverse_file.md),
[`materialize_declared_data()`](https://replicate-anything.github.io/replicateEverything/reference/materialize_declared_data.md),
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md))
over study-local
[`httr::GET`](https://httr.r-lib.org/reference/GET.html) /
`download.file` / unzip utilities

Thin runners and pure `make_*` / `format_*` only — do not reimplement
package verbs in the study

Do not copy wholesale archives into the study when a deposit API can
serve the files you need

### Call original data (Dataverse / ICPSR)

When the replication lives on **Harvard Dataverse** or **ICPSR /
OpenICPSR**, fetch from there.

Resolve dataset / file ids from the deposit (or paper DOI → deposit
link)

**Surgical pulls:** `api/access/datafile/<id>?format=original` (or ICPSR
equivalent) for **only** files analysis needs

**Pattern B (default)** when the fetch is a claimed step: `access_*` →
`outputs/…`; later steps `parents:` that step

**Pattern A (exception):** silent `dataverse.files` / `data_files:`
materialize → `data/` when fetch is *not* a replication product

No full-dataset zip / `archive_original` unless Pattern C is justified
(author scripts need that tree)

Document direct-download URLs once file ids are known (README or yaml
comments)

#### Connecting with Dataverse and ICPSR

| Source | Typical entry | Prefer |
|----|----|----|
| Harvard Dataverse | `doi:10.7910/DVN/…` | File-id URL with `?format=original`; package `engine: dataverse` / [`fetch_dataverse_file()`](https://replicate-anything.github.io/replicateEverything/reference/fetch_dataverse_file.md) |
| OpenICPSR / ICPSR | project or study page with downloadable files | Direct file URLs when the API exposes them; same surgical rule |
| No usable fetch API (private, offline, some OpenICPSR) | — | Commit ≤50 MB under `data/`; document why; larger → registry data area |

Discover deposits with the R `dataverse` package (`get_dataset()`) when
on Dataverse — a full zip is not required to start. Inspect
`originalFileName` / native format before converting `.tab` files.

If data lives **elsewhere** (author site, OSF, journal supplement):

Make files **directly accessible** (stable HTTPS URL to the file itself)

Do not rely on “download the zip and dig inside” as the only path —
document a direct file URL once you have it

### Public study repos

Shiny and registry enrichment fetch the study’s root `replication.yml`
over HTTP.

Study repo is **public** (or otherwise fetchable by the Shiny host)

`repo:` / `paper.study_repo` points at the correct GitHub slug

Raw `replication.yml` is reachable (no private-only tree for that path)

### Lean materials and registry handoff

No ethics / instruments / appendix-only blobs unless a declared step
needs them

No empty placeholder data trees; no scratch / `outputs/deposit/` /
staging committed

No study-local `registry/` folder — contributor runs
`check_and_bake_study(".")`; maintainer syncs stubs

Every table/figure step has a display sink under `outputs/` (`.html` /
`.png`) when Display should show it

Yaml DAG rules (`steps:`, `outputs:`, `parents:`, format children): see
[Folder replication
checklist](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md)
— do not re-learn them here.

------------------------------------------------------------------------

## Next

- [Folder replication
  checklist](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md)
- [Package replication
  checklist](https://replicate-anything.github.io/replicateEverything/articles/package-replication-checklist.md)
- [Stata
  replications](https://replicate-anything.github.io/replicateEverything/articles/stata-replications.md)
- [Reanalysis and extension
  studies](https://replicate-anything.github.io/replicateEverything/articles/reanalysis-studies.md)
