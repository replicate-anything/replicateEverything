#' Decode HTML entities in kableExtra / modelsummary table output
#'
#' @param html Character HTML string.
#' @return Character HTML with common entities decoded for browser display.
#' @export
normalize_html_table <- function(html) {
  html <- as.character(html)
  if (!length(html) || !nzchar(html)) {
    return(html)
  }

  for (i in seq_len(3)) {
    prev <- html
    html <- gsub("&amp;nbsp;", " ", html, fixed = TRUE)
    html <- gsub("&nbsp;", " ", html, fixed = TRUE)
    html <- gsub("&amp;lt;", "<", html, fixed = TRUE)
    html <- gsub("&lt;", "<", html, fixed = TRUE)
    html <- gsub("&amp;gt;", ">", html, fixed = TRUE)
    html <- gsub("&gt;", ">", html, fixed = TRUE)
    html <- gsub("&amp;quot;", "\"", html, fixed = TRUE)
    html <- gsub("&quot;", "\"", html, fixed = TRUE)
    html <- gsub("&amp;", "&", html, fixed = TRUE)
    if (identical(html, prev)) {
      break
    }
  }

  html
}
