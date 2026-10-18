## brief_report.R -----------------------------------------------------------
## The report the repository apps show: metacheck's "brief" report (only the
## checks that flagged something, each with what to fix), plus the
## repository's file tree, shown open.
##
## metacheck::report(report_type = "brief") has no file tree and no way to add
## a section, so this does report()'s steps itself -- run the modules, build the
## report text with report_qmd(), render it with Quarto -- and inserts a file
## tree between the summary and the validation section.
##
## The tree comes from metacheck's .file_tree() (R/file-tree.R): data_check's
## "#### Data Tree", which also lists files inside zip archives and each file's
## study, or, when data_check reports nothing, one drawn from repo_check's file
## list.
##
## Needs ensure_quarto() from render_report.R. Kept identical in every app
## folder that uses it (like render_report.R).

# The file tree as an open Quarto callout, or NULL when there is no tree.
# The tree itself sits in a scroll box (see metacheck's .file_tree_block()),
# so a large repository does not make the report endless.
.brief_file_tree <- function(module_output) {
  body <- metacheck:::.file_tree(module_output)
  if (is.null(body)) return(NULL)
  sprintf('::: {.callout-note title="Files in the repository"}\n\n%s\n\n:::',
          paste(body, collapse = "\n\n"))
}

# Put `section` right after the brief report's summary. In brief mode
# report_qmd() follows the summary with "## Validation" (when any check was
# flagged) and otherwise with the feedback sentence, so the section goes
# before whichever comes first; at the end if neither is found.
.brief_insert_after_summary <- function(report_text, section) {
  markers <- c("\n## Validation\n",
               "\nIf there are things we can improve, please email us")
  for (marker in markers) {
    pos <- regexpr(marker, report_text, fixed = TRUE)
    if (pos > 0) {
      return(paste0(substr(report_text, 1, pos), section, "\n",
                    substring(report_text, pos)))
    }
  }
  paste(report_text, section, sep = "\n\n")
}

#' Render the brief report, with the file tree, to an HTML file
#'
#' @param paper a metacheck paper object.
#' @param modules character vector of module names to run.
#' @param output_file path to write the final .html to.
#' @param args list of per-module arguments (as for metacheck::report()).
#' @return the path to the rendered HTML file.
render_brief_report <- function(paper, modules, output_file, args = list()) {
  if (!requireNamespace("quarto", quietly = TRUE)) {
    stop("The 'quarto' package is required to render reports on this server.")
  }
  if (!nzchar(ensure_quarto())) {
    stop("No Quarto CLI found. Run setup.R to install Quarto into ~/opt/quarto, ",
         "or set QUARTO_PATH to a quarto binary.")
  }

  # Set while the modules run, not only while the text is built: modules
  # build parts of their own output differently per report type (see
  # metacheck::report_type()). Restored afterwards, also on error.
  prev_type <- metacheck::report_type()
  metacheck::report_type("brief")
  on.exit(metacheck::report_type(prev_type), add = TRUE)

  module_output <- metacheck::report_module_run(paper, modules, args)

  # Writing the report takes a while (Quarto); say so through metacheck's own
  # progress helper, which an app may have redirected (see shiny_progress.R).
  bar <- metacheck::pb(NA, ":what")
  bar$tick(0, tokens = list(what = "Writing the report"))
  on.exit(bar$terminate(), add = TRUE)

  report_text <- metacheck::report_qmd(module_output, paper)

  tree <- .brief_file_tree(module_output)
  if (!is.null(tree)) report_text <- .brief_insert_after_summary(report_text, tree)

  # The .qmd holds the full report text (the user's data), so every file the
  # render leaves in tempdir is deleted right away, as in render_report.R.
  td <- normalizePath(tempdir(), winslash = "/")
  before <- list.files(td, recursive = TRUE, full.names = TRUE)
  on.exit({
    after <- list.files(td, recursive = TRUE, full.names = TRUE)
    new_paths <- setdiff(after, before)
    keep <- normalizePath(output_file, winslash = "/", mustWork = FALSE)
    new_paths <- new_paths[normalizePath(new_paths, winslash = "/",
                                         mustWork = FALSE) != keep]
    if (length(new_paths)) unlink(new_paths, recursive = TRUE, force = TRUE)
  }, add = TRUE)

  qmd  <- tempfile("brief_report_", fileext = ".qmd")
  html <- sub("qmd$", "html", qmd)
  write(report_text, qmd)
  quarto::quarto_render(input = qmd, quiet = TRUE, output_format = "html")
  if (!file.exists(html)) {
    stop("Quarto render did not produce an HTML file.")
  }
  file.copy(html, output_file, overwrite = TRUE)
  output_file
}
