# Reanalysis and extension studies

## Overview

A **reanalysis study** reuses upstream data preparation from a published
replication while replacing one or more analysis steps. The
replicateEverything package supports this with `paper.extends` and
step-level `inherit:` declarations.

The worked example pairs:

- **Base study:** Fearon & Laitin (2003) —
  `rep-10.1017-S0003055403000534` ([Cambridge Core
  article](https://www.cambridge.org/core/journals/american-political-science-review/article/abs/ethnicity-insurgency-and-civil-war/B1D5D0E7C782483C5D7E102A61AD6605);
  DOI `10.1017/S0003055403000534`)
- **Reanalysis:** [Simple replication of F&L data /
  repo](https://github.com/replicate-anything/rep-10.1017-S0003055403000534--alt-1)
  — same prepared data, `lm_robust` instead of `glm`

## Base study pipeline

The base study declares a transform step and downstream tables:

    raw data/repdata.dta  →  analysis_data  →  tab_1 (R) / tab_1_stata (Stata)

`analysis_data` renames `lpopl1` to `lpopl` and recodes onset
indicators. Both analysis engines read `outputs/analysis_data.rds` or
`.dta`.

## Extension study layout

The reanalysis repository holds only new material. When the display
format matches the base study, inherit the format child step; when it
differs (as here), inherit with a `code:` override pointing at local R
scripts:

``` yaml
steps:
  - inherit: analysis_data

  - id: tab_1
    type: table
    parents: [analysis_data]
    data: outputs/analysis_data.rds
    code: code/tab_1.R
    format: format_tab_1

  - inherit: tab_1_format
```

`inherit: tab_1_format` is enough when the extension repo has its own
`code/tab_1.R` at the same path as the base format step:
replicateEverything sources that file locally so `format_tab_1` uses the
reanalysis models. Only add a `code:` override when the extension
formatter lives at a different path.

In the base Fearon & Laitin study, Stata table steps read
`data/repdata.dta` directly; R steps use the shared `analysis_data`
output.

## Execution semantics

| `given` | Behaviour |
|----|----|
| `"parents"` | Requires `analysis_data` outputs in the **base** repo (`outputs/analysis_data.rds`) |
| `"nothing"` | Runs inherited `analysis_data` in the base checkout, then the extension analysis locally |

Inherited steps execute in the base study root; extension steps run in
the extension root but may read base `outputs/`.

`run_replication(handle, "everything", given = "nothing")` returns a
named list with one entry per non-format step (`analysis_data`, `tab_1`,
…). Use `format = FALSE` (default) for raw model objects;
`format = TRUE` for display HTML.

## Running locally

From a monorepo checkout with both study folders as siblings:

``` r

devtools::load_all("replicateEverything")
configure_local_monorepo()

# Base study (once)
run_replication("10.1017/S0003055403000534", "analysis_data", given = "nothing")

# Reanalysis (uses base analysis_data outputs)
run_replication(
  "rep-10.1017-S0003055403000534--alt-1",
  "tab_1",
  given = "parents"
)
```

Or pass the extension study path directly when no article DOI exists
yet:

``` r

run_replication("rep-10.1017-S0003055403000534--alt-1", "tab_1")
```

## Registration

Extension studies without a DOI use `paper.study_handle` in
`replication.yml` and a registry stub keyed by that handle. Link to the
original study with `paper.related` and/or `paper.extends` (DOI / repo).
[`build_registry_index()`](https://replicate-anything.github.io/replicateEverything/reference/build_registry_index.md)
stores those as `related_upstream` on the reanalysis and reverses them
into `related_downstream` on the original — the Shiny Studies
**Related** column and `summary(get_study(...))` both use that map. See
`registry/studies/rep-10.1017-S0003055403000534--alt-1.yml` for the stub
template.

Validate before opening a PR:

``` r

check_replication("rep-10.1017-S0003055403000534--alt-1")
```

## Further reading

- Step inheritance design notes:
  `system.file("docs/step-inheritance.md", package = "replicateEverything")`
- Folder replication checklist:
  [`vignette("folder-replication-checklist", package = "replicateEverything")`](https://replicate-anything.github.io/replicateEverything/articles/folder-replication-checklist.md)
