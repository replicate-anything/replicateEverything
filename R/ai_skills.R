#' Directory containing bundled AI skill files
#'
#' @param package Optional package name. Defaults to the calling package.
#' @return Normalized path, or \code{""} when no skills are installed.
#' @keywords internal
ai_skills_dir <- function(package = utils::packageName()) {
  system.file("ai", "skills", package = package)
}

#' List bundled AI skills
#'
#' Returns skill names (without \code{.md}) for markdown files shipped under
#' \code{inst/ai/skills/} in the installed package.
#'
#' @param package Optional package name. Defaults to \code{replicateEverything}.
#' @return A character vector of available AI skill names.
#' @export
#'
#' @examples
#' \dontrun{
#' ai_skills()
#' }
ai_skills <- function(package = "replicateEverything") {
  path <- ai_skills_dir(package)
  if (!nzchar(path) || !dir.exists(path)) {
    return(character(0))
  }
  files <- list.files(path, pattern = "\\.md$", full.names = FALSE)
  sort(tools::file_path_sans_ext(files))
}

#' Get the path to a bundled AI skill
#'
#' @param skill Name of the skill, without \code{.md}.
#' @param package Optional package name. Defaults to \code{replicateEverything}.
#' @return Path to the bundled skill file.
#' @export
#'
#' @examples
#' \dontrun{
#' ai_skill_path("APSR_to_replicateEverything")
#' }
ai_skill_path <- function(skill, package = "replicateEverything") {
  skill <- as.character(skill[[1]])
  path <- system.file(
    "ai", "skills", paste0(skill, ".md"),
    package = package
  )

  if (!nzchar(path)) {
    available <- ai_skills(package)
    hint <- if (length(available)) {
      paste0(" Available: ", paste(available, collapse = ", "), ".")
    } else {
      ""
    }
    stop("AI skill not found: ", skill, ".", hint, call. = FALSE)
  }

  path
}

#' Read a bundled AI skill
#'
#' @param skill Name of the skill, without \code{.md}.
#' @param package Optional package name. Defaults to \code{replicateEverything}.
#' @return A character string containing the skill text.
#' @export
#'
#' @examples
#' \dontrun{
#' cat(ai_skill("APSR_to_replicateEverything"))
#' }
ai_skill <- function(skill, package = "replicateEverything") {
  paste(
    readLines(ai_skill_path(skill, package = package), warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
}
