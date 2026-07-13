# Step inheritance (extension / reanalysis studies)

Extension studies reuse upstream steps from a published replication via `paper.extends` and step-level `inherit:`.

## Study-level pointer

```yaml
paper:
  extends:
    repo: replicate-anything/rep-10.1017-S0003055403000534
    ref: main
    doi: 10.1017/S0003055403000534
```

## Step-level inheritance

```yaml
steps:
  - inherit: prep_data

  - id: tab_1
    type: table
    parents: [prep_data]
    data: outputs/prep_data/repdata.rds
    code: code/tab_1.R
    artifact: outputs/tab_1.html
```

At load time the package merges base `steps:` with extension `steps:` (extension wins on id collision unless `override: true`).

## Execution semantics

| `given` | Behaviour |
|---------|-----------|
| `"parents"` | Parent outputs must exist in the base repo checkout |
| `"nothing"` | Run inherited upstream steps in the base repo, then extension steps locally |

Inherited steps run in the **base study root**. Extension steps run in the **extension root** but read base `outputs/` via cross-repo path resolution.

See the **Reanalysis and extension studies** vignette (`vignette("reanalysis-studies")`) and the worked example repo [rep-10.1017-S0003055403000534--alt-1](https://github.com/replicate-anything/rep-10.1017-S0003055403000534--alt-1).

## Problem

A researcher wants to:

1. Reuse `construct_analysis_dataset` from Jiang et al. (2026) without copying code or data prep.
2. Add a new table or figure that depends on that dataset plus their own script.
3. Register the extension as its own folder-backed repo (new DOI or working-paper stub).

They should not fork the entire study repo or duplicate the DAG.

## Recommended model: `extends` + local overrides

### Study-level pointer

```yaml
paper:
  doi: https://doi.org/10.5555/my-extension
  title: "Facial traits and turnover: an extension"
  extends:
    repo: replicate-anything/rep-10.1017-s0003055426101749
    ref: main
    doi: 10.1017/S0003055426101749   # optional; resolved from base replication.yml
```

The extension repo holds **only** new or overridden material:

```
my-extension/
  replication.yml
  code/
    tables/
      tab_ext_1.R
  outputs/          # extension display files only
  data/raw/         # only if new raw inputs are needed
```

At load time the package **merges** base `steps:` with extension `steps:` (extension wins on id collision).

### Step-level inheritance

Reference an upstream step without redeclaring it:

```yaml
steps:
  - inherit: rep-10.1017-s0003055426101749/construct_analysis_dataset

  - id: tab_ext_1
    type: table
    label: Table A1
    description: Robustness with alternate purge coding
    parents:
      - construct_analysis_dataset
    engine: r
    code: code/tables/tab_ext_1.R
    inputs:
      - outputs/construct_analysis_dataset/all_asperson_fulldata.dta
    outputs:
      - outputs/tab_ext_1.html
    artifact: outputs/tab_ext_1.html
```

`inherit:` pulls the full step record (code path, outputs, engine) from the base study. The extension repo does not ship `construct_analysis_dataset.do`; live runs fetch or use a cached checkout of the base repo.

### Execution semantics

| `given` | Behavior for extension |
|---------|------------------------|
| `"parents"` | Parent outputs must exist locally or in base repo cache |
| `"nothing"` | Run inherited upstream steps in base repo checkout, then extension steps |
| character vector | Same downward-closure rules as today |

Inherited steps run in the **base study root** (code + data paths resolve there). Extension steps run in the **extension root**. Outputs from inherited steps remain under the base repo’s `outputs/` unless copied by an explicit `mirror_outputs:` policy (future).

### Registration

1. Extension stub in registry: `studies/<folder>.yml` with `materials: folder`, `study_repo`, DOI.
2. `replication.yml` documents `extends:` for auditors.
3. Shiny shows merged DAG: inherited steps tagged *(inherited)* or grouped under base study label.

### Alternatives considered

| Approach | Pros | Cons |
|----------|------|------|
| Git submodule of base repo | Simple for git-savvy users | Heavy; path confusion |
| Copy-paste base `steps` block | Works today | Drift; no single source of truth |
| Package dependency (`Depends: repJiang`) | Good for R-only | Poor fit for Stata/Python pipeline |
| **`extends` + `inherit:` (proposed)** | Clear DAG; minimal extension repo | Requires merge loader + cross-repo run |

### Implementation order (suggested)

1. `merge_extended_study_meta()` — fetch base yaml, merge steps, validate DAG.
2. `inherit:` step expansion at parse time.
3. `execute_study_plan()` — route inherited steps to base `local_root`.
4. Shiny — visual distinction for inherited nodes.
5. `check_folder_replication()` — warn if extension redefines inherited id without `override: true`.

### Author checklist (extension repo)

- [ ] Set `extends.repo` / `extends.ref` in `replication.yml`
- [ ] List inherited steps with `inherit: repo/step_id`
- [ ] Declare only new steps and new `outputs/`
- [ ] Point `parents:` at inherited step ids
- [ ] Run `run_replication(doi, "tab_ext_1", given = "nothing")` once locally to verify cross-repo prep
- [ ] Register stub; do not duplicate base raw data unless adding new inputs
