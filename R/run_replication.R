#' Run a single replication
#'
#' Executes a specific replication (figure or table) for a paper.
#'
#' @param doi Character. DOI of the paper.
#' @param what Character. Replication identifier (e.g., "fig_1").
#'
#' @return A plot or table produced by the replication code.
#'
#' @examples
#' \dontrun{
#' run_replication("10.1177/00491241211036161", "fig_1")
#' }
#'
#' @export
run_replication <- function(doi, what){

  repo <- tryCatch(
    find_repo(doi),
    error = function(e) NULL
  )

  if(is.null(repo)){
    stop("Replication repository not found")
  }

  doi_path <- gsub("/", "_", doi)

  meta_url <- paste0(
    "https://raw.githubusercontent.com/",
    repo,
    "/main/papers/",
    doi_path,
    "/replication.yml"
  )

  tmp_meta <- tempfile(fileext = ".yml")

  utils::download.file(meta_url, tmp_meta, quiet = TRUE)

  meta <- yaml::read_yaml(tmp_meta)

  print(sapply(meta$replications, function(x) x$id))

  matches <- meta$replications[
    sapply(meta$replications, function(x) x$id) == what
  ]

  if(length(matches) == 0){
    stop(paste("Replication", what, "not found in metadata"))
  }

  rep <- matches[[1]]

  base_url <- paste0(
    "https://raw.githubusercontent.com/",
    repo,
    "/main/papers/",
    doi_path
  )

  message("Using repository: ", repo)
  message("Replication type: ", rep$type)

  # ---- Load data ----
  data_files <- rep$data

  # convert YAML list → character vector
  if(is.list(data_files)){
    data_files <- unlist(data_files, use.names = FALSE)
  }

  data_files <- as.character(data_files)

  if(length(data_files) == 1){

    data_url <- paste0(base_url, "/", data_files)

    data <- utils::read.csv(data_url)

  } else {

    data <- lapply(data_files, function(f){

      url <- paste0(base_url, "/", f)

      utils::read.csv(url)

    })

    names(data) <- tools::file_path_sans_ext(basename(data_files))
  }

  # ---- Download replication script ----
  code_url <- paste0(base_url, "/", rep$code)

  tmp_code <- tempfile(fileext = ".R")

  utils::download.file(code_url, tmp_code, quiet = TRUE)

  source(tmp_code)

  # ---- Run replication ----
  if(rep$type == "figure"){

    result <- generate_figure(data)
    print(result)
    invisible(result)

  }

  if(rep$type == "table"){

    result <- generate_table(data)
    print(result)
    invisible(result)

  }

}
