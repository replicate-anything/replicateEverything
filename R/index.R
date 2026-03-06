load_index <- function(){

  index_url <- "https://raw.githubusercontent.com/replicate-anything/registry/main/index.json"

  jsonlite::fromJSON(index_url)

}

