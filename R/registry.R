get_registry <- function(){

  url <- "https://raw.githubusercontent.com/replicate-anything/registry/main/registry.yml"

  yaml::read_yaml(url)

}
