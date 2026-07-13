#' Clean LaTeX fragments from esttab HTML output
#'
#' esttab's \code{mgroups(..., prefix(\\multicolumn{...}))} option emits raw
#' LaTeX into HTML tables. This helper strips those fragments and applies simple
#' colspan fixes for two-group headers.
#'
#' @param html Character HTML string.
#' @return Character HTML.
#' @keywords internal
sanitize_esttab_html <- function(html) {
  html <- as.character(html)
  if (!length(html) || !nzchar(html)) {
    return(html)
  }

  html <- gsub("\\\\cmidrule\\([^)]*\\)\\{[^}]*\\}", "", html, perl = TRUE)
  html <- gsub(
    "\\\\multicolumn\\{([0-9]+)\\}\\{[^}]*\\}\\{([^}]*)\\}",
    "\\2",
    html,
    perl = TRUE
  )

  html <- gsub(
    "<tr><td>\\s*</td><td>\\s*([^<(][^<]*?)\\s*</td><td>\\s*([^<(][^<]*?)\\s*</td></tr>",
    "<tr><td></td><td colspan=\"2\">\\1</td><td colspan=\"2\">\\2</td></tr>",
    html,
    perl = TRUE,
    ignore.case = FALSE
  )

  html
}
