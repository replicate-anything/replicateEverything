#' Convert a LaTeX tabular (texdoc / booktabs fragment) to HTML
#'
#' Parses \code{\\begin\{tabular\}...\\end\{tabular\}} from author Stata
#' \code{texdoc} (or similar) output into a simple HTML table for Shiny Display.
#' Handles \code{\\multicolumn}, \code{\\hline}, and light text markup
#' (\code{\\textit}, \code{\\textbf}). Does not require LaTeX or pandoc.
#'
#' @param tex Character scalar: raw \code{.tex} contents, or a path to a
#'   \code{.tex} file.
#' @param title Optional title shown above the table.
#' @return Character scalar containing an HTML fragment with a
#'   \code{<table class="replication-table">}.
#' @keywords internal
latex_tabular_to_html <- function(tex, title = NULL) {
  tex <- as.character(tex[[1]] %||% tex)
  if (!nzchar(tex)) {
    return('<p class="text-muted">No LaTeX table content.</p>')
  }
  if (length(tex) == 1L && file.exists(tex) && !grepl("\\\\begin\\{", tex)) {
    tex <- paste(readLines(tex, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }

  caption <- latex_extract_braced(tex, "\\\\caption")
  body <- latex_extract_tabular(tex)
  if (is.null(body) || !nzchar(body)) {
    stop("No \\\\begin{tabular}...\\\\end{tabular} found in LaTeX input.", call. = FALSE)
  }

  rows_html <- latex_tabular_rows_to_html(body)
  title_use <- title
  if (is.null(title_use) || !nzchar(as.character(title_use)[1])) {
    title_use <- caption
  }

  parts <- character(0)
  if (!is.null(title_use) && nzchar(as.character(title_use)[1])) {
    parts <- c(parts, paste0("<h3>", html_escape_text(as.character(title_use)[1]), "</h3>"))
  }
  if (!is.null(caption) && nzchar(caption) &&
      !identical(trimws(caption), trimws(as.character(title_use %||% "")))) {
    parts <- c(
      parts,
      paste0("<p class=\"text-muted\">", html_escape_text(caption), "</p>")
    )
  }
  parts <- c(
    parts,
    '<div class="replication-table stata-texdoc-output table-responsive">',
    '<table class="table table-sm replication-table">',
    "<tbody>",
    rows_html,
    "</tbody></table></div>"
  )
  paste(parts, collapse = "\n")
}

#' @keywords internal
latex_extract_tabular <- function(tex) {
  m <- regexpr("\\\\begin\\{tabular\\}[\\s\\S]*?\\\\end\\{tabular\\}", tex, perl = TRUE)
  if (m < 1) {
    return(NULL)
  }
  chunk <- regmatches(tex, m)
  chunk <- sub("^\\\\begin\\{tabular\\}\\{[^}]*\\}\\s*", "", chunk, perl = TRUE)
  chunk <- sub("\\\\end\\{tabular\\}\\s*$", "", chunk, perl = TRUE)
  chunk
}

#' @keywords internal
latex_extract_braced <- function(tex, cmd) {
  m <- regexpr(paste0(cmd, "\\{"), tex, perl = TRUE)
  if (m < 1) {
    return(NULL)
  }
  start <- as.integer(m) + attr(m, "match.length") - 1L
  content <- latex_read_braced(tex, start)
  if (is.null(content)) {
    return(NULL)
  }
  trimws(latex_inline_to_text(content))
}

#' Read {...} starting at the opening brace index (1-based).
#' @keywords internal
latex_read_braced <- function(text, open_idx) {
  if (open_idx < 1L || open_idx > nchar(text) ||
      substr(text, open_idx, open_idx) != "{") {
    return(NULL)
  }
  depth <- 0L
  i <- open_idx
  n <- nchar(text)
  while (i <= n) {
    ch <- substr(text, i, i)
    if (ch == "{") {
      depth <- depth + 1L
    } else if (ch == "}") {
      depth <- depth - 1L
      if (depth == 0L) {
        if (i <= open_idx + 1L) {
          return("")
        }
        return(substr(text, open_idx + 1L, i - 1L))
      }
    } else if (ch == "\\" && i < n) {
      i <- i + 1L
    }
    i <- i + 1L
  }
  NULL
}

#' @keywords internal
latex_tabular_rows_to_html <- function(body) {
  # Normalize line endings; keep \\ as row separators.
  body <- gsub("\r\n", "\n", body, fixed = TRUE)
  body <- gsub("\r", "\n", body, fixed = TRUE)
  # Drop resizebox / center noise if somehow included.
  body <- gsub("\\\\resizebox\\{[^}]*\\}\\{[^}]*\\}\\{", "", body, perl = TRUE)

  parts <- latex_split_rows(body)
  out <- character(0)
  for (part in parts) {
    part <- trimws(part)
    if (!nzchar(part)) {
      next
    }
    # Pure rule row(s)
    hline_row <- '<tr class="texdoc-hline"><td colspan="99" style="border-top:1px solid #333;padding:0;height:0;line-height:0;"></td></tr>'
    if (grepl("^(\\\\hline\\s*)+$", part, perl = TRUE)) {
      out <- c(out, hline_row)
      next
    }
    part <- gsub("\\\\hline", "", part, fixed = TRUE)
    part <- trimws(part)
    if (!nzchar(part)) {
      out <- c(out, hline_row)
      next
    }
    cells <- latex_split_cells(part)
    cell_html <- vapply(cells, latex_cell_to_html, character(1))
    out <- c(out, paste0("<tr>", paste(cell_html, collapse = ""), "</tr>"))
  }
  paste(out, collapse = "\n")
}

#' Split tabular body on row-ending \\\\ outside braces.
#' @keywords internal
latex_split_rows <- function(body) {
  latex_split_on_token(body, "\\\\")
}

#' Split a row on & outside braces.
#' @keywords internal
latex_split_cells <- function(row) {
  latex_split_on_token(row, "&")
}

#' @keywords internal
latex_split_on_token <- function(text, token) {
  text <- as.character(text %||% "")
  n <- nchar(text)
  if (n < 1L) {
    return(character(0))
  }
  tok_len <- nchar(token)
  if (tok_len < 1L) {
    return(text)
  }
  depth <- 0L
  starts <- 1L
  pieces <- character(0)
  i <- 1L
  while (i <= n) {
    ch <- substr(text, i, i)
    if (identical(ch, "{")) {
      depth <- depth + 1L
      i <- i + 1L
      next
    }
    if (identical(ch, "}")) {
      depth <- max(0L, depth - 1L)
      i <- i + 1L
      next
    }
    if (depth == 0L && (i + tok_len - 1L) <= n &&
        identical(substr(text, i, i + tok_len - 1L), token)) {
      pieces <- c(pieces, substr(text, starts, i - 1L))
      i <- i + tok_len
      starts <- i
      next
    }
    i <- i + 1L
  }
  c(pieces, substr(text, starts, n))
}

#' @keywords internal
latex_cell_to_html <- function(cell) {
  cell <- trimws(as.character(cell %||% ""))
  colspan <- 1L
  align <- NULL

  if (grepl("^\\\\multicolumn\\{", cell, perl = TRUE)) {
    open_n <- regexpr("\\\\multicolumn\\{", cell, perl = TRUE)
    brace_n <- as.integer(open_n) + attr(open_n, "match.length") - 1L
    n_str <- latex_read_braced(cell, brace_n)
    if (is.null(n_str)) {
      return(paste0("<td>", latex_inline_to_html(cell), "</td>"))
    }
    after_n <- brace_n + nchar(n_str) + 2L
    spec <- latex_read_braced(cell, after_n)
    if (is.null(spec)) {
      return(paste0("<td>", latex_inline_to_html(cell), "</td>"))
    }
    after_spec <- after_n + nchar(spec) + 2L
    content <- latex_read_braced(cell, after_spec)
    colspan <- suppressWarnings(as.integer(n_str))
    if (is.na(colspan) || colspan < 1L) {
      colspan <- 1L
    }
    if (grepl("c", spec, fixed = TRUE)) {
      align <- "center"
    } else if (grepl("r", spec, fixed = TRUE)) {
      align <- "right"
    } else if (grepl("l", spec, fixed = TRUE)) {
      align <- "left"
    }
    cell <- content %||% ""
  }

  inner <- latex_inline_to_html(cell)
  attrs <- character(0)
  if (colspan > 1L) {
    attrs <- c(attrs, sprintf('colspan="%d"', colspan))
  }
  if (!is.null(align)) {
    attrs <- c(attrs, sprintf('style="text-align:%s"', align))
  }
  attr_str <- if (length(attrs)) paste0(" ", paste(attrs, collapse = " ")) else ""
  paste0("<td", attr_str, ">", inner, "</td>")
}

#' Light inline LaTeX → HTML (escape text; keep italics/bold).
#' @keywords internal
latex_inline_to_html <- function(text) {
  text <- as.character(text %||% "")
  if (!nzchar(text)) {
    return("")
  }
  # Protect \textit{...} / \textbf{...} by converting recursively.
  out <- ""
  i <- 1L
  n <- nchar(text)
  while (i <= n) {
    if (i + 7L <= n && substr(text, i, i + 7L) == "\\textit{") {
      content <- latex_read_braced(text, i + 7L) %||% ""
      out <- paste0(out, "<em>", latex_inline_to_html(content), "</em>")
      i <- i + 8L + nchar(content) + 1L
      next
    }
    if (i + 7L <= n && substr(text, i, i + 7L) == "\\textbf{") {
      content <- latex_read_braced(text, i + 7L) %||% ""
      out <- paste0(out, "<strong>", latex_inline_to_html(content), "</strong>")
      i <- i + 8L + nchar(content) + 1L
      next
    }
    # Skip unknown simple commands \cmd or \cmd{...}; always advance.
    if (substr(text, i, i) == "\\") {
      if (i >= n) {
        break
      }
      rest <- substr(text, i + 1L, n)
      m <- regexpr("^[A-Za-z]+", rest, perl = TRUE)
      if (m == 1L) {
        cmd_len <- as.integer(attr(m, "match.length"))
        j <- i + 1L + cmd_len
        if (j <= n && substr(text, j, j) == "{") {
          content <- latex_read_braced(text, j) %||% ""
          out <- paste0(out, latex_inline_to_html(content))
          i <- j + nchar(content) + 2L
          next
        }
        # bare command remnant (\hline etc.)
        i <- max(j, i + 1L)
        next
      }
      # escaped special char: \# \$ \& \% \_ \{ \}
      nxt <- substr(text, i + 1L, i + 1L)
      if (nxt %in% c("#", "$", "%", "&", "_", "{", "}")) {
        out <- paste0(out, html_escape_text(nxt))
        i <- i + 2L
        next
      }
      i <- i + 1L
      next
    }
    # Consume a run of plain text until next backslash
    j <- i
    while (j <= n && substr(text, j, j) != "\\") {
      j <- j + 1L
    }
    if (j <= i) {
      # Should not happen; force progress to avoid an infinite loop.
      i <- i + 1L
      next
    }
    out <- paste0(out, html_escape_text(substr(text, i, j - 1L)))
    i <- j
  }
  # Collapse excess whitespace inside cells
  out <- gsub("[ \t]+", " ", out, perl = TRUE)
  trimws(out)
}

#' Plain-text version of inline LaTeX (for captions).
#' @keywords internal
latex_inline_to_text <- function(text) {
  html <- latex_inline_to_html(text)
  html <- gsub("<[^>]+>", "", html, perl = TRUE)
  html <- gsub("&amp;", "&", html, fixed = TRUE)
  html <- gsub("&lt;", "<", html, fixed = TRUE)
  html <- gsub("&gt;", ">", html, fixed = TRUE)
  html <- gsub("&quot;", "\"", html, fixed = TRUE)
  trimws(html)
}
