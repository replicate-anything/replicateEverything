# Remove deposit files not listed in a manifest keep set

After a full Dataverse archive extract, drops PDFs, HTML, extra scripts,
and other paths outside `keep_paths`. Preserves the cached archive zip
and other dotfiles named in `preserve`.

## Usage

``` r
prune_deposit_paths(
  keep_paths,
  deposit_root,
  preserve = c(".dataset_original.zip", ".manifest_applied")
)
```

## Arguments

- keep_paths:

  Character vector of relative paths to retain.

- deposit_root:

  Deposit directory (e.g. `outputs/deposit`).

- preserve:

  Basenames (or relative paths) always kept under `deposit_root`.
