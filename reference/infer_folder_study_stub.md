# Build a minimal folder-study stub when the registry yaml is missing

Used when a study is loaded by DOI after its registry stub was moved to
`drafts/` or is not yet published. Looks up the study repo from
`index.csv`, then tries standard `rep-<doi>` GitHub paths.

## Usage

``` r
infer_folder_study_stub(doi, folder = NULL)
```

## Arguments

- doi:

  Normalized DOI.

- folder:

  Registry folder name when known.
