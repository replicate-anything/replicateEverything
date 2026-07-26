# Convert a LaTeX tabular (texdoc / booktabs fragment) to HTML

Parses `\begin{tabular}...\end{tabular}` from author Stata `texdoc` (or
similar) output into a simple HTML table for Shiny Display. Handles
`\multicolumn`, `\hline`, and light text markup (`\textit`, `\textbf`).
Does not require LaTeX or pandoc.

## Usage

``` r
latex_tabular_to_html(tex, title = NULL)
```

## Arguments

- tex:

  Character scalar: raw `.tex` contents, or a path to a `.tex` file.

- title:

  Optional title shown above the table.

## Value

Character scalar containing an HTML fragment with a
`<table class="replication-table">`.
