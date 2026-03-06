#' Replicate an entire paper
#'
#' Runs all replications (figures and tables) listed in the metadata.
#'
#' @param doi Character DOI of the paper.
#' @importFrom utils read.csv download.file
#' @export
replicate_paper <- function(doi){

  repo <- find_repo(doi)

  doi_path <- gsub("/", "_", doi)

  base_url <- paste0(
    "https://raw.githubusercontent.com/",
    repo,
    "/main/papers/",
    doi_path
  )

  meta_url <- paste0(base_url, "/replication.yml")

  meta <- suppressWarnings(
    yaml::read_yaml(meta_url)
  )

  replications <- meta$replications

  message("Replicating: ", meta$paper$title)
  message("")

  data_cache <- list()

  for(rep in replications){

    message("Running: ", rep$id)

    data_url <- paste0(base_url, "/", rep$data)

    if(!(rep$data %in% names(data_cache))){

      data_cache[[rep$data]] <- read.csv(data_url)

    }

    data <- data_cache[[rep$data]]

    code_url <- paste0(base_url, "/", rep$code)

    tmp <- tempfile()

    download.file(code_url, tmp, quiet = TRUE)

    source(tmp)

    if(rep$type == "figure"){

      print(generate_figure(data))

    }

    if(rep$type == "table"){

      print(generate_table(data))

    }

  }

}
