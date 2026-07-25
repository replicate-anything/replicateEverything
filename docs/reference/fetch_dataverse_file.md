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
