# Infer replication language when only one engine implements `what`

Infer replication language when only one engine implements `what`

## Usage

``` r
resolve_replication_language(meta, what, language = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

- what:

  Replication id or logical group id.

- language:

  Optional explicit language (normalized when set).

## Value

`"r"`, `"stata"`, `"python"`, or `NULL`.
