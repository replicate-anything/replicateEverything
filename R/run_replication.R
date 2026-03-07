#' Run a replication
#'
#' Reproduces a single figure or table from a paper using the
#' replication metadata stored in the registry.
#'
#' @param doi Character. The DOI of the paper.
#' @param what Character. The replication ID (e.g., "fig_1", "tab_1").
#' @importFrom utils read.csv download.file
#' @export
run_replication <- function(doi, what){

  repo <- tryCatch(
    find_repo(doi),
    error = function(e) NULL
  )

  if(is.null(repo)){
    message("Using local replication folder")
    base_path <- gsub("/", "_", doi)
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

  download.file(meta_url, tmp_meta, quiet = TRUE)

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

  data_url <- paste0(base_url,"/",rep$data)
  code_url <- paste0(base_url,"/",rep$code)

  message("Using repository: ", repo)
  message("Replication type: ", rep$type)

  data <- read.csv(data_url)

  tmp <- tempfile()

  download.file(code_url,tmp)

  source(tmp)

  if(rep$type == "figure"){

    result <- generate_figure(data)
    print(result)

  }

  if(rep$type == "table"){

    result <- generate_table(data)

    print(result)

    invisible(result)

  }

}
