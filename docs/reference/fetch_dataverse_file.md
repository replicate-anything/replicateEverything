# Fetch a Dataverse file into a study-relative path (surgical pull)

Downloads one file by Dataverse file id (or absolute URL) into the study
tree. Prefer this over full-dataset zip downloads and over study-local
download helpers. Typical Pattern B: write under `outputs/`.

## Usage

``` r
fetch_dataverse_file(
  file_id = NULL,
  path,
  url = NULL,
  original = TRUE,
  server = "dataverse.harvard.edu",
  study_root = NULL,
  force = TRUE
)
```

## Arguments

- file_id:

  Dataverse file id (ignored when `url` is set).

- path:

  Study-relative destination (e.g. `"outputs/data.dta"`).

- url:

  Optional direct URL (e.g. already including `?format=original`).

- original:

  When `TRUE` and using `file_id`, request native upload.

- server:

  Dataverse host.

- study_root:

  Local study root; defaults to `REPLICATE_STUDY_ROOT` or `"."`.

- force:

  Re-download existing files.

## Value

Invisibly, absolute destination path.

## Examples

``` r
if (FALSE) { # \dontrun{
# Blair et al. APSR analysis .dta (Harvard Dataverse file id)
fetch_dataverse_file(
  file_id = "14058927",
  path = "outputs/analysis.dta",
  study_root = "../rep-10.1017-s0003055422000284"
)
} # }
```
