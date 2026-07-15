# Normalize a caller file path for code-link resolution

Accepts study-relative or absolute paths and returns an absolute path
under `allowed_root` when possible.

## Usage

``` r
normalize_code_from_file(from_file, study_root, allowed_root = study_root)
```
