# Find a single replication entry by logical id and optional language

`what` is the logical replication id (the `group` field when set,
otherwise the entry `id`). When `language` is `NULL`, R is preferred
when both R and Stata entries exist. Legacy suffixed ids such as
`tab_1_stata` still match by exact `id`.

## Usage

``` r
find_replication_entry(meta, what, language = NULL, paper_meta = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- what:

  Replication identifier (logical id or legacy entry id).

- language:

  Optional `"R"` or `"stata"` engine selector.

- paper_meta:

  Optional paper metadata; defaults to `meta$paper`.
