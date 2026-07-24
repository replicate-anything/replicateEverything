---
name: include-study-in-registry
description: >-
  Check a folder- or package-backed replication study and include it in the
  replicate-anything registry: validate the study, maintainer sync stub into
  registry/studies/ from study replication.yml, rebuild index.csv, and audit.
---

# Include a study in the registry

Use this skill when a study repository is ready for the central
[replicate-anything registry](https://github.com/replicate-anything/registry).

## Roles

| Role | What they do |
|------|----------------|
| **Contributor** | Validates the study (`check_and_bake_study` / `check_replication`) |
| **Maintainer** | Builds stub **from study `replication.yml`** into the registry, rebuilds `index.csv`, audits |

## Important: no study-local registry handoff

Stub yaml and `index.csv` belong **only** in the registry repository
(`registry/studies/<folder>.yml` + `registry/index.csv`).

Do **not** commit `registry/` or `inst/registry/` handoff folders inside study
repos. `sync_study_to_registry()` reads the study root `replication.yml` and
writes the stub into the registry checkout.

`outputs/` is for replication products only (`manifest.json`, tables, figures,
intermediate data).

The full contract stays at repo root: `replication.yml` (folder) or
`replication.yml` / `inst/replication.yml` (package). Yaml must use a unified
`steps:` DAG (`parents:` and `outputs:` only).

## Contributor checklist

```
- [ ] 1. Full `replication.yml` uses `steps:` DAG
- [ ] 2. `maintainer:` (name + email) and `collections:` declared
- [ ] 3. Build outputs: `build_study_outputs()`
- [ ] 3b. Manual smoke check: `list_replications("local")`, `describe_study_dag("local")`, `run_replication("local", "<id>")`
- [ ] 4. Validate: `check_replication()` (includes substantive-check coverage)
- [ ] 4b. Add `tests/substantive/<step_id>.R` for published benchmarks where possible
- [ ] 5. Prepare / validate: `check_and_bake_study(".")`
- [ ] 6. Commit study repo (code, data, outputs, tests, replication.yml) — no registry/
- [ ] 7. Open PR on study repo; notify registry maintainer
```

From the study repo root (`setwd()` there, or open its RStudio project),
every consumer verb accepts `doi = "local"` for the working-directory study
— no registry lookup needed:

```r
library(replicateEverything)

list_replications("local")
describe_study_dag("local")
run_replication("local", "<id>")  # one light step

# Folder or package study — bake + validate; stub is written later by the maintainer
check_and_bake_study(".", build_artifacts = TRUE)

check_and_bake_study("../rep-10.1371-journal.pone.0278337")
```

`check_and_bake_study()`:

1. Builds artifacts (optional)
2. Runs the appropriate checklist
3. Does **not** write stub files into the study repo

## Maintainer checklist

```
- [ ] 1. Study PR merged; root `replication.yml` complete
- [ ] 2. Re-validate if needed: `check_replication()` / `check_and_bake_study()`
- [ ] 3. Sync stub from study yaml: `sync_study_to_registry(study_path, registry_root = "../registry")`
   (or `register_study()` for check + sync in one call)
- [ ] 4. Full refresh: `refresh_registry("../registry", audit = TRUE)`
- [ ] 4b. Check display outputs: `validate_outputs(doi = "everywhere", what = "everything")`
- [ ] 5. Commit registry: `studies/<folder>.yml`, `index.csv`, audit outputs
- [ ] 6. Deploy Shiny / clear study cache if needed
```

```r
library(replicateEverything)
options(replicateEverything.registry_root = "../registry")

# One study — builds stub from study replication.yml into registry/studies/
sync_study_to_registry("../rep-10.1177-00491241211036161", audit = TRUE)

# Or check + sync:
register_study("../rep-10.1177-00491241211036161", build_artifacts = TRUE)

# After batch of syncs — recompile index + audit everything
refresh_registry("../registry", audit = TRUE)
```

### Maintainer shortcuts

| Task | Function |
|------|----------|
| Check + bake | `check_and_bake_study(study_path)` |
| Check + sync | `register_study(study_path)` |
| Sync stub only | `sync_study_to_registry(study_path)` |
| Rebuild index only | `build_registry_index("../registry")` |
| Index + full audit | `refresh_registry("../registry")` |

## Registry stub contents

Short yaml includes only what the registry needs:

- `paper` summary fields (doi/handle, title, journal, year, authors, materials pointers)
- `repo`, `maintainer`, `collections`, `languages`

No `steps:` block in the stub — the study repo yaml is authoritative for the DAG.
