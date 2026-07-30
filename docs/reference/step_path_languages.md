# Path languages declared on a step (multi-language engine path)

Prefer explicit yaml `languages:` on the step (the languages that
participate in this implementation path). When omitted, fall back to the
dispatch `engine:` plus a proprietary `requires_engine:` token when
present (so a Stata wrapper that shells to Mathematica still labels
honestly as Stata + Mathematica).

## Usage

``` r
step_path_languages(step)
```

## Arguments

- step:

  Step / replication entry (list).

## Value

Character vector of normalized language tokens (may be length 1+).
