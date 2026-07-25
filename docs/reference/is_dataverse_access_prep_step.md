# Whether a prep step should use the Dataverse *full-deposit* summary display

Pattern C only (manifest / deposit_root / access_deposit / archive
fetch). Pattern B surgical `access_data` → `outputs/*.dta` uses the
normal data-file preview — do **not** match bare `"access"` in the step
id.

## Usage

``` r
is_dataverse_access_prep_step(prep, meta, ctx = NULL)
```
