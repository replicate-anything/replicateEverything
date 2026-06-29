#' Load replication data from local paths (for self-contained scripts)
#'
#' Used at the bottom of replication scripts so they can be run directly
#' from the paper folder without the package orchestrator.
#'
#' @param data_paths Character vector of paths relative to the paper folder.
#' @param paper_dir Paper root directory. Defaults to current working directory.
#' @return A data frame, list, or other object.
#'
#' @examples
#' tmp <- tempfile()
#' dir.create(tmp)
#' dir.create(file.path(tmp, "data"))
#' write.csv(
#'   data.frame(x = 1:3, y = 4:6),
#'   file.path(tmp, "data", "example.csv"),
#'   row.names = FALSE
#' )
#' load_local_replication_data("data/example.csv", paper_dir = tmp)
#'
#' @export
load_local_replication_data <- function(data_paths, paper_dir = getwd()) {
  if (is.null(data_paths)) {
    return(NULL)
  }
  if (is.list(data_paths)) {
    data_paths <- unlist(data_paths, use.names = FALSE)
  }
  data_paths <- as.character(data_paths)
  data_paths <- data_paths[nzchar(data_paths)]
  if (length(data_paths) == 0) {
    return(NULL)
  }

  ctx <- list(local_root = paper_dir, base_url = "")
  load_replication_data(data_paths, ctx)
}

#' Run a replication script footer when executed directly
#'
#' Scripts normally use an \code{if/else} footer:
#' \code{generate_figure <- make_fig_1(read.csv(...))} when run directly, and
#' \code{generate_figure <- make_fig_1} when sourced by the package.
#'
#' @param make_fn Function that accepts \code{data}.
#' @param data_paths Paths relative to the paper folder.
#' @param paper_dir Paper root directory.
#'
#' @examples
#' \dontrun{
#' # At the bottom of a replication script in code/:
#' # self_run(make_fig_1, "data/fig_1.csv")
#' }
#'
#' @export
self_run <- function(make_fn, data_paths, paper_dir = getwd()) {
  if (isTRUE(getOption("replicateEverything.skip_self_run", FALSE))) {
    return(invisible(NULL))
  }
  paper_dir <- if (dir.exists(file.path(paper_dir, "data"))) {
    normalizePath(paper_dir, winslash = "/", mustWork = FALSE)
  } else {
    normalizePath(file.path(paper_dir, ".."), winslash = "/", mustWork = FALSE)
  }
  data <- load_local_replication_data(data_paths, paper_dir = paper_dir)
  make_fn(data)
}
