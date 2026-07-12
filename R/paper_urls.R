#' Resolve a human-facing URL for a published article
#'
#' Some publisher DOI links (notably older Cambridge Core / APSR entries) do
#' not resolve reliably. Study metadata may therefore include an explicit
#' landing page via \code{paper.article_url} (or \code{paper.landing_url}).
#' When no override is set, the function falls back to \code{https://doi.org/...}.
#'
#' @param doi Optional DOI string or URL.
#' @param paper Optional \code{paper} list from \code{replication.yml} or the
#'   registry stub.
#' @param meta Optional full parsed metadata (uses \code{meta$paper}).
#' @return Character URL, or \code{NULL} when no link can be formed.
#' @export
#'
#' @examples
#' \dontrun{
#' paper_article_url(
#'   doi = "10.1017/S0003055403000534",
#'   paper = list(
#'     article_url = paste0(
#'       "https://www.cambridge.org/core/journals/",
#'       "american-political-science-review/article/abs/",
#'       "ethnicity-insurgency-and-civil-war/",
#'       "B1D5D0E7C782483C5D7E102A61AD6605"
#'     )
#'   )
#' )
#' }
paper_article_url <- function(doi = NULL, paper = NULL, meta = NULL) {
  if (is.null(paper) && !is.null(meta)) {
    paper <- meta$paper %||% NULL
  }
  if (!is.null(paper) && length(paper) > 0L) {
    for (field in c("article_url", "landing_url", "publisher_url", "study_url")) {
      val <- paper[[field]] %||% NULL
      if (is.null(val)) {
        next
      }
      url <- trimws(as.character(val[[1]] %||% val))
      if (nzchar(url) && grepl("^https?://", url, ignore.case = TRUE)) {
        return(url)
      }
    }
  }

  doi_val <- doi
  if ((is.null(doi_val) || !nzchar(trimws(as.character(doi_val)))) && !is.null(paper)) {
    doi_val <- paper$doi %||% paper$study_handle %||% NULL
  }
  if (is.null(doi_val) || !nzchar(trimws(as.character(doi_val)))) {
    return(NULL)
  }
  normalized <- tryCatch(
    normalize_doi(as.character(doi_val)),
    error = function(e) trimws(as.character(doi_val))
  )
  if (!nzchar(normalized)) {
    return(NULL)
  }
  if (grepl("^https?://", normalized, ignore.case = TRUE)) {
    return(normalized)
  }
  paste0("https://doi.org/", normalized)
}
