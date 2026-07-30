# Format one Excel preview cell for Shiny Display

Numeric values (and character cells that parse as plain numbers) are
rounded to 3 decimal places. Non-numeric text is left unchanged.

## Usage

``` r
format_xlsx_preview_cell(x)
```

## Arguments

- x:

  A length-1 cell value.

## Value

Character scalar suitable for an HTML table cell.
