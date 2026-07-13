---
name: include-study-in-registry
description: >-
  Check a folder- or package-backed replication study and include it in the
  replicate-anything registry: prepare handoff yaml in the study repo,
  maintainer sync to registry/studies/, rebuild index.csv, and audit.
---

# Include a study in the registry

Use this skill when a study repository is ready for the central
[replicate-anything registry](https://github.com/replicate-anything/registry).

## Roles

| Role | What they do |
|------|----------------|
| **Contributor** | Validates the study and writes **short** registry yaml into the study repo |
| **Maintainer** | Copies that yaml into the registry, rebuilds `index.csv`, reruns audit |

## Handoff files (in the study repo — not in `outputs/`)

| Layout | Short yaml location |
|--------|---------------------|
| Folder-backed | `registry/replication.yml` + `registry/index.csv` |
| Package-backed | `inst/registry/replication.yml` + `inst/registry/index.csv` |

`outputs/` is for replication products only (`manifest.json`, tables, figures, intermediate data).

The full contract stays at repo root: `replication.yml` (folder) or `replication.yml` / `inst/replication.yml` (package).

## Contributor checklist

```
- [ ] 1. Full `replication.yml` uses `steps:` DAG (folder) or package prep/replications
- [ ] 2. `maintainer:` (name + email) and `collections:` declared
- [ ] 3. Build outputs: `build_study_artifacts()` or `build_package_artifacts()`
- [ ] 4. Validate: `check_folder_replication()` or `check_package_replication()`
- [ ] 5. Prepare handoff: `prepare_study_for_registry(".")`
- [ ] 6. Commit study repo including `registry/` or `inst/registry/` handoff files
- [ ] 7. Open PR on study repo; notify registry maintainer
```

```r
library(replicateEverything)

# Folder study
prepare_study_for_registry(".", build_artifacts = TRUE)

# Package study (same function — auto-detects layout)
prepare_study_for_registry("../rep-10.1371_journal.pone.0278337")
```

`prepare_study_for_registry()`:

1. Builds artifacts (optional)
2. Runs the appropriate checklist
3. Writes short yaml + one-row `index.csv` under `registry/` or `inst/registry/`
4. Validates stub consistency against the full `replication.yml`

## Maintainer checklist

```
- [ ] 1. Study PR merged; handoff files present in study repo
- [ ] 2. Re-validate if needed: `check_folder_replication()` / `check_package_replication()`
- [ ] 3. Sync stub: `sync_study_to_registry(study_path, registry_root = "../registry")`
- [ ] 4. Full refresh: `refresh_registry("../registry", audit = TRUE)`
- [ ] 5. Commit registry: `studies/<folder>.yml`, `index.csv`, audit outputs
- [ ] 6. Deploy Shiny / clear study cache if needed
```

```r
library(replicateEverything)
options(replicateEverything.registry_root = "../registry")

# One study
sync_study_to_registry("../rep-10.1177-00491241211036161", audit = TRUE)

# After batch of syncs — recompile index + audit everything
refresh_registry("../registry", audit = TRUE)
```

### Maintainer shortcuts

| Task | Function |
|------|----------|
| Folder study: check + sync | `add_folder_paper(study_path)` (internal) |
| Package study: check + sync | `add_paper(study_path)` (internal) |
| Rebuild index only | `build_registry_index("../registry")` |
| Index + full audit | `refresh_registry("../registry")` |

## Registry stub contents

Short yaml includes only what the registry needs:

- `paper:` — doi, title, journal, year, authors, `materials`, repo pointers
- `repo:` — GitHub slug
- `maintainer:`, `collections:`, `languages:`

No `steps:` block in the registry stub.

## Related skills

- Folder layout and DAG: `folder_replication.md`
- APSR deliveries: `APSR_to_replicateEverything.md`

## Deprecated names

| Old | New |
|-----|-----|
| `prepare_folder_paper()` | `prepare_study_for_registry()` |
| `sync_folder_paper()` | `sync_study_to_registry()` |
