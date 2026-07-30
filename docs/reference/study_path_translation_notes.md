# Translation notes for multi-language path groups (study summary)

Generic across studies: for a flat list of step / replication entries
(pre-grouping), finds `group:` clusters where at least one sibling
requires a proprietary system engine (Mathematica, MATLAB, ...) and at
least one other sibling does not. Returns the non-empty `path_note:` of
the runnable sibling(s) - e.g. "R is a translation of the original
Mathematica LBD kernel" - so Shiny can surface it once in the
study/output summary instead of as a per-row callout. Relies only on
yaml-declared `group:`, `requires_engine:`, and `path_note:`; no
study-specific text lives in the package.

## Usage

``` r
study_path_translation_notes(entries)
```

## Arguments

- entries:

  List of step / replication entries (flat, pre-grouping).

## Value

Character vector of unique non-empty notes (possibly empty).
