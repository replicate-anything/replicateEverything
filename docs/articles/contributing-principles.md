# Contributing principles

High-level rules for study repos that sit under **Contributing
replications**. Use this before the folder, package, Stata, or
reanalysis checklists. Gold shape:
[`rep-template`](https://github.com/replicate-anything/rep-template).

## Wire, do not ship

Keep study repos **light**. Prefer yaml that points at originals over
committing binaries or inventing download helpers.

    - [ ] Prefer **yaml wiring** (declared URLs / file ids / `engine: dataverse`) over shipping raw deposits
    - [ ] Prefer package helpers (`fetch_dataverse_file()`, `materialize_declared_data()`, `run_replication()`) over study-local `httr::GET` / `download.file` / unzip utilities
    - [ ] Thin runners and pure `make_*` / `format_*` only — do not reimplement package verbs in the study
    - [ ] Do not copy wholesale archives into the study when a deposit API can serve the files you need

## Call original data (Dataverse / ICPSR)

When the replication lives on **Harvard Dataverse** or **ICPSR /
OpenICPSR**, fetch from there.

    - [ ] Resolve dataset / file ids from the deposit (or paper DOI → deposit link)
    - [ ] **Surgical pulls:** `api/access/datafile/<id>?format=original` (or ICPSR equivalent) for **only** files analysis needs
    - [ ] **Pattern B (default)** when the fetch is a claimed step: `access_*` → `outputs/…`; later steps `parents:` that step
    - [ ] **Pattern A (exception):** silent `dataverse.files` / `data_files:` materialize → `data/` when fetch is *not* a replication product
    - [ ] No full-dataset zip / `archive_original` unless Pattern C is justified (author scripts need that tree)
    - [ ] Document direct-download URLs once file ids are known (README or yaml comments)

### Connecting with Dataverse and ICPSR

| Source | Typical entry | Prefer |
|----|----|----|
| Harvard Dataverse | `doi:10.7910/DVN/…` | File-id URL with `?format=original`; package `engine: dataverse` / [`fetch_dataverse_file()`](https://replicate-anything.github.io/replicateEverything/reference/fetch_dataverse_file.md) |
| OpenICPSR / ICPSR | project or study page with downloadable files | Direct file URLs when the API exposes them; same surgical rule |
| No usable fetch API (private, offline, some OpenICPSR) | — | Commit ≤50 MB under `data/`; document why; larger → registry data area |

Discover deposits with the R `dataverse` package (`get_dataset()`) when
on Dataverse — a full zip is not required to start. Inspect
`originalFileName` / native format before converting `.tab` files.

If data lives **elsewhere** (author site, OSF, journal supplement):

    - [ ] Make files **directly accessible** (stable HTTPS URL to the file itself)
    - [ ] Do not rely on “download the zip and dig inside” as the only path — document a direct file URL once you have it

## Public study repos

Shiny and registry enrichment fetch the study’s root `replication.yml`
over HTTP.

    - [ ] Study repo is **public** (or otherwise fetchable by the Shiny host)
    - [ ] `repo:` / `paper.study_repo` points at the correct GitHub slug
    - [ ] Raw `replication.yml` is reachable (no private-only tree for that path)

## Yaml contract

    - [ ] Unified `steps:` DAG — no legacy `prep:` / `replications:`
    - [ ] Products use `outputs:` only — no deprecated `artifact:` / `output:` / `stata_output:`
    - [ ] Edges use `parents:` only — no `requires:` / `depends_on:`; omit `parents` on roots (never `parents: []`)
    - [ ] `maintainer:` name + email filled; `collections:` when known; `languages:` for every engine
    - [ ] Format children: `type: format` + `parent:` (no unused `label:`)
    - [ ] `list_replications("local")` and `describe_study_dag("local")` succeed from the study root

## Lean materials and registry handoff

    - [ ] No ethics / instruments / appendix-only blobs unless a declared step needs them
    - [ ] No empty placeholder data trees; no scratch / `outputs/deposit/` / staging committed
    - [ ] No study-local `registry/` folder — contributor runs `check_and_bake_study(".")`; maintainer syncs stubs
    - [ ] Every table/figure step has a display sink under `outputs/` (`.html` / `.png`) when Display should show it

## Pre-submit gate

``` r

library(replicateEverything)
# from study repo root:
yaml::read_yaml("replication.yml")
list_replications("local")
describe_study_dag("local")
check_and_bake_study(".", build_artifacts = TRUE)
```

Next: [Folder replication
checklist](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md),
[Package replication
checklist](https://replicate-anything.github.io/replicateEverything/articles/package-replication-checklist.md),
[Stata
replications](https://replicate-anything.github.io/replicateEverything/articles/stata-replications.md),
or [Reanalysis and extension
studies](https://replicate-anything.github.io/replicateEverything/articles/reanalysis-studies.md).
