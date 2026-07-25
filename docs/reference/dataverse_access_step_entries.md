# Resolve surgical Dataverse file entries for an access step

Reads step-level `files:` / `file_id` + `outputs:`, or falls back to
study `dataverse.file_id` mapped to the first output path.

## Usage

``` r
dataverse_access_step_entries(rep, meta = NULL)
```
