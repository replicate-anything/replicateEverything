# Check whether a baked table artifact file is valid for folder checks

Accepts `.rds`, HTML with a `<table>`, or (for Stata entries) monospace
`<pre class="stata-output">` blocks produced when regression output
cannot be parsed into an HTML table.

## Usage

``` r
table_artifact_file_ok(art_path, engine = NULL)
```

## Arguments

- art_path:

  Path to the artifact file.

- engine:

  Optional replication engine (`"stata"` or `"r"`).
