# Format an audit timeout error for reports

Format an audit timeout error for reports

## Usage

``` r
audit_timeout_message(patience, detail = NULL)
```

## Arguments

- patience:

  Seconds used as the audit elapsed-time cap.

- detail:

  Optional underlying error text (kept short when present).

## Value

Character scalar for the Error column.
