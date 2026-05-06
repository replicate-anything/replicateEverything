#' Run a single replication
#'
#' Executes a specific replication (figure or table) for a paper.
#'
#' @param doi Character. DOI of the paper or file path to paper in local registry.
#' @param what Character. Replication identifier (e.g., "fig_1").
#'
#' @return A plot or table produced by the replication code.
#'
#' @examples
#' \dontrun{
#' run_replication("10.1177/00491241211036161", "fig_1")
#' run_replication(path, "fig_1")
#' }
#'
#' @export
run_replication <- function(doi, what){

  repo <- tryCatch(
    find_repo(doi),
    error = function(e) NULL
  )

  if(is.null(repo)){

    # treat `doi` as local base path
    base_url <- doi

    meta_path <- file.path(base_url, "replication.yml")

    if(!file.exists(meta_path)){
      stop("Local replication.yml not found")}

    meta <- yaml::read_yaml(meta_path)

  }

  else {

    doi_path <- gsub("/", "_", doi)

    base_url <- paste0(
      "https://raw.githubusercontent.com/",
      repo,
      "/main/papers/",
      doi_path
    )

    meta_url <- paste0(base_url, "/replication.yml")

    tmp_meta <- tempfile(fileext = ".yml")

    utils::download.file(meta_url, tmp_meta, quiet = TRUE)

    meta <- yaml::read_yaml(tmp_meta)

  }

  print(sapply(meta$replications, function(x) x$id))

  matches <- meta$replications[
    sapply(meta$replications, function(x) x$id) == what
  ]

  if(length(matches) == 0){
    stop(paste("Replication", what, "not found in metadata"))
  }

  rep <- matches[[1]]

  message("Using repository: ", repo)
  message("Replication type: ", rep$type)

  # ---- Load data ----
  data_files <- rep$data

  # convert YAML list → character vector
  if(is.list(data_files)){
    data_files <- unlist(data_files, use.names = FALSE)
  }

  data_files <- as.character(data_files)

  read_data_from_url <- function(url) {
    ext <- tolower(tools::file_ext(url))

    if (ext == "") {
      stop("Cannot determine file type from URL (no extension).")
    }

    tmp <- tempfile(fileext = paste0(".", ext))
    on.exit(unlink(tmp), add = TRUE)

    curl::curl_download(url, tmp)

    switch(ext,
           "csv"  = utils::read.csv(tmp),
           "xlsx" = readxl::read_excel(tmp),
           "xls"  = readxl::read_excel(tmp),
           "rds"  = readRDS(tmp),
           "rdata" = ,
           "rda" = {
             e <- new.env()
             load(tmp, envir = e)
             as.list(e)
           },
           "dta"  = haven::read_dta(tmp),

           stop(paste("Unsupported file type:", ext))
    )
  }

  read_data_local <- function(url){
    ext <- tolower(tools::file_ext(url))

    if (ext == "") {
      stop("Cannot determine file type from URL (no extension).")
    }
    # = if its a local path
    switch(ext,
           "csv"  = utils::read.csv(url),
           "rds"  = readRDS(url),
           "rdata" = ,
           "rda" = {
             e <- new.env()
             load(url, envir = e)
             as.list(e)
           },
           "xlsx" = readxl::read_excel(url),
           "xls"  = readxl::read_excel(url),
           "dta"  = haven::read_dta(url),

           stop(paste("Unsupported file type:", ext))
    )
  }

  if(length(data_files) == 1){

    data_url <- paste0(base_url, "/", data_files)

    if(is.null(repo)){

      data <- read_data_local(data_url)

    } else {

      data <- read_data_from_url(data_url)

    }

  } else {

    data <- lapply(data_files, function(f){

      url <- paste0(base_url, "/", f)

      if(is.null(repo)){

        read_data_local(url)

      } else {

        read_data_from_url(url)

      }

    })

    names(data) <- tools::file_path_sans_ext(basename(data_files))

  }

  # ---- Download replication script ----
  if(is.null(repo)){

    code_url <- paste0("file://", base_url, "/", rep$code)

  } else {

    code_url <- paste0(base_url, "/", rep$code)

  }

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
