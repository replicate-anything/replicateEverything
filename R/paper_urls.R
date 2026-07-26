#' Resolve a human-facing URL for a published article
#'
#' Some publisher DOI links (notably older Cambridge Core / APSR entries) do
#' not resolve reliably. Study metadata may therefore include an explicit
#' landing page via \code{paper.article_url} (or \code{paper.landing_url} /
#' \code{paper.publisher_url}). When no override is set, the function falls
#' back to \code{https://doi.org/...}.
#'
#' \code{paper.study_url} is the GitHub study repository and is intentionally
#' ignored here — use the Shiny Repo column / study materials link for that.
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
#' # Fearon & Laitin: registry stub supplies paper.article_url
#' paper_article_url(doi = "10.1017/S0003055403000534")
#' paper_article_url(doi = "10.1017/S0003055422000284")
#' paper_article_url(doi = "10.1257/aer.91.5.1369")
#' st <- get_study("10.1017/S0003055403000534")
#' paper_article_url(doi = st$doi)
#' }
paper_article_url <- function(doi = NULL, paper = NULL, meta = NULL) {
  if (is.null(paper) && !is.null(meta)) {
    paper <- meta$paper %||% NULL
  }
  if (!is.null(paper) && length(paper) > 0L) {
    # Paper landing pages only — never paper.study_url (that is the GitHub
    # study repo and belongs in the Repo column, not DOI / journal links).
    for (field in c("article_url", "landing_url", "publisher_url")) {
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
