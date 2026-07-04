# Decode HTML entities in kableExtra / modelsummary table output

Decode HTML entities in kableExtra / modelsummary table output

## Usage

``` r
normalize_html_table(html)
```

## Arguments

- html:

  Character HTML string.

## Value

Character HTML with common entities decoded for browser display.

## Examples

``` r
normalize_html_table("&lt;table&gt;&amp;nbsp;data&lt;/table&gt;")
#> Error in normalize_html_table("&lt;table&gt;&amp;nbsp;data&lt;/table&gt;"): could not find function "normalize_html_table"
```
