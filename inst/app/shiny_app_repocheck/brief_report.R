## brief_report.R -----------------------------------------------------------
## The report the repository apps show: metacheck's "brief" report (only the
## checks that flagged something, each with what to fix), plus the
## repository's file tree in a section that stays folded until the reader
## opens it.
##
## metacheck::report(report_type = "brief") has no file tree and no way to add
## a section, so this does report()'s steps itself -- run the modules, build the
## report text with report_qmd(), render it with Quarto -- and inserts a file
## tree between the summary and the validation section.
##
## The tree is the one data_check builds (the "#### Data Tree" part of its
## report), which also lists files inside zip archives and each file's study.
## data_check reports nothing at all when a repository has no data file it can
## read, so the tree is then drawn here from repo_check's file list instead.
##
## Needs ensure_quarto() from render_report.R. Kept identical in every app
## folder that uses it (like render_report.R).

# The "#### Data Tree" part of data_check's report, without its heading.
# NULL when data_check did not run or reported no tree.
.brief_data_check_tree <- function(data_check_report) {
  if (is.null(data_check_report)) return(NULL)
  start <- which(data_check_report == "#### Data Tree")
  if (length(start) == 0) return(NULL)
  start <- start[[1]]
  is_heading <- grepl("^#{1,4} ", data_check_report)
  after <- which(is_heading & seq_along(data_check_report) > start)
  end <- if (length(after) > 0) after[[1]] - 1 else length(data_check_report)
  if (end <= start) return(NULL)
  data_check_report[(start + 1):end]
}

# Tree rows for a set of relative paths: folders first, then files, each
# alphabetically. `leaf_idx` is the index into `paths` of the file a row
# shows (NA for a folder row). A copy of repo_tree_rows() in
# inst/modules/data_check.R -- keep the two drawing trees the same way.
.brief_tree_rows <- function(paths) {
  parts_list <- strsplit(gsub("\\\\", "/", paths), "/")
  parts_list <- lapply(parts_list, function(x) x[!is.na(x) & nzchar(x)])
  keep <- lengths(parts_list) > 0
  parts_list <- parts_list[keep]
  out_text <- character(0)
  out_leaf <- integer(0)

  walk <- function(parts_subset, idx_subset, prefix = "") {
    heads <- vapply(parts_subset, function(x) x[[1]], character(1))
    head_order <- unique(heads)
    has_child <- vapply(head_order, function(head) {
      any(lengths(parts_subset[heads == head]) > 1)
    }, logical(1))
    head_order <- head_order[order(!has_child, tolower(head_order))]
    for (i in seq_along(head_order)) {
      sel <- heads == head_order[[i]]
      tails <- lapply(parts_subset[sel], function(x) x[-1])
      tail_idx <- idx_subset[sel]
      is_last <- i == length(head_order)
      is_folder <- any(lengths(tails) > 0)
      out_text <<- c(out_text, paste0(prefix, if (is_last) "└── " else "├── ",
                                      head_order[[i]], if (is_folder) "/" else ""))
      out_leaf <<- c(out_leaf, if (is_folder) NA_integer_ else tail_idx[[1]])
      deeper <- lengths(tails) > 0
      if (any(deeper)) {
        walk(tails[deeper], tail_idx[deeper],
             paste0(prefix, if (is_last) "    " else "│   "))
      }
    }
  }

  if (length(parts_list) > 0) walk(parts_list, which(keep))
  data.frame(text = out_text, leaf_idx = out_leaf)
}

# The same kind of tree as data_check's, drawn from repo_check's file table:
# per repository, each file with how it was classified and any file-naming
# issue. NULL when repo_check listed no files.
.brief_repo_check_tree <- function(files, naming_issues = NULL) {
  if (is.null(files) || nrow(files) == 0 || !"repo_url" %in% names(files)) {
    return(NULL)
  }
  col <- function(df, name) if (name %in% names(df)) df[[name]] else rep(NA_character_, nrow(df))
  # Icons as in data_check's tree (readme first, as it is a kind of documentation).
  type_icon <- function(type, role) {
    icons <- c(data = "\U0001F4CA", code = "\U0001F4BB", documentation = "\U0001F4D6",
               materials = "\U0001F4C1", output = "\U0001F4C8")
    out <- unname(icons[type])
    out[is.na(out)] <- "\U00002753"
    out[!is.na(role) & role == "readme"] <- "\U0001F4C4"
    out
  }
  pad <- function(x) formatC(x, width = -(max(nchar(x, type = "chars"), 0) + 2), flag = " ")

  blocks <- lapply(unique(stats::na.omit(files$repo_url)), function(repo) {
    sub <- files[!is.na(files$repo_url) & files$repo_url == repo, , drop = FALSE]
    paths <- col(sub, "file_path")
    paths[is.na(paths) | !nzchar(paths)] <- col(sub, "file_name")[is.na(paths) | !nzchar(paths)]
    rows <- .brief_tree_rows(paths)
    if (nrow(rows) == 0) return(NULL)
    leaf <- !is.na(rows$leaf_idx)
    type <- col(sub, "data_type")[rows$leaf_idx[leaf]]
    role <- col(sub, "doc_role")[rows$leaf_idx[leaf]]
    type_txt <- rep("", nrow(rows))
    type_txt[leaf] <- paste(type_icon(type, role),
                            ifelse(!is.na(role) & role == "readme", "readme",
                                   ifelse(is.na(type), "unknown", type)))
    naming_txt <- rep("", nrow(rows))
    if (!is.null(naming_issues) && nrow(naming_issues) > 0) {
      hit <- match(col(sub, "file_name")[rows$leaf_idx[leaf]], naming_issues$file_name)
      naming_txt[leaf] <- ifelse(is.na(hit), "", naming_issues$detail[hit])
    }
    lines <- sub("\\s+$", "", paste0(pad(rows$text), pad(type_txt), naming_txt))
    c(paste0("**Repository: ", repo, "**"),
      paste(c("```", lines, "```"), collapse = "\n"))
  })
  blocks <- unlist(Filter(Negate(is.null), blocks))
  if (length(blocks) == 0) return(NULL)
  c("Where the files sit within each repository. Each file is followed by how it was classified, and any file-naming issue found by repo_check.",
    blocks)
}

# The file tree as a folded Quarto callout, or NULL when there is no tree.
.brief_file_tree <- function(module_output) {
  body <- .brief_data_check_tree(module_output$data_check$report) %||%
    .brief_repo_check_tree(module_output$repo_check$table,
                           module_output$repo_check$naming_issues)
  if (is.null(body)) return(NULL)
  sprintf('::: {.callout-note collapse="true" title="Files in the repository"}\n\n%s\n\n:::',
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

#' Render the brief report, with a folded file tree, to an HTML file
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
