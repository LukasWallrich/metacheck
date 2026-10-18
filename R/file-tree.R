# The repository file tree: every file of each repository, drawn as a tree,
# with how it was classified, its study and any file-naming issue. data_check
# shows it in its report ("#### Data Tree"); the repository apps' brief report
# and external modules (such as the TU/e data manager check) show it too, so it
# lives here rather than inside data_check.

# Icon shown in the "Classified as" column, by data_type (readme is a
# doc_role sub-kind of "documentation", checked first so a readme gets its
# own icon rather than the generic documentation one).
.tree_type_icon <- function(data_type, doc_role) {
  ifelse(!is.na(doc_role) & doc_role == "readme", "\U0001F4C4",   # 📄
  ifelse(data_type == "data", "\U0001F4CA",                       # 📊
  ifelse(data_type == "code", "\U0001F4BB",                       # 💻
  ifelse(data_type == "documentation", "\U0001F4D6",              # 📖
  ifelse(data_type == "materials", "\U0001F4C1",                  # 📁
  ifelse(data_type == "output", "\U0001F4C8",                     # 📈
  "\U00002753"))))))                                              # ❓ unknown
}

.tree_type_label <- function(data_type, doc_role) {
  ifelse(!is.na(doc_role) & doc_role == "readme", "readme", data_type)
}

# Walk a set of relative paths into tree rows. Unlike a plain text `tree`
# renderer, each row also carries which INPUT PATH (if any) it is the leaf
# of, via `leaf_idx` (index into `paths`, NA for a folder-only row) — so the
# caller can attach per-file columns (type, study, naming issue) to the
# right row without re-parsing the tree text. Two DISTINCT input rows that
# happen to share the exact same relative path (should not normally happen —
# repo_check dedupes by file_url + file_path before data_check sees this)
# collapse into one tree row, same as the original text-only renderer; only
# the first row's metadata is then shown for it.
.file_tree_rows <- function(paths) {
  keep <- !is.na(paths) & nzchar(paths)
  paths <- paths[keep]
  orig_idx <- which(keep)
  if (length(paths) == 0)
    return(data.frame(text = character(0), leaf_idx = integer(0)))
  parts_list <- strsplit(gsub("\\\\", "/", paths), "/", fixed = FALSE)
  parts_list <- lapply(parts_list, function(x) x[nzchar(x)])
  out_text <- character(0)
  out_leaf <- integer(0)

  walk <- function(parts_subset, idx_subset, prefix = "") {
    heads <- vapply(parts_subset, function(x) x[[1]], character(1))
    head_order <- unique(heads)
    has_child <- vapply(head_order, function(head) {
      i <- heads == head
      any(vapply(parts_subset[i], length, integer(1)) > 1)
    }, logical(1))
    head_order <- head_order[order(!has_child, tolower(head_order))]

    for (i in seq_along(head_order)) {
      head <- head_order[[i]]
      sel <- heads == head
      tails <- lapply(parts_subset[sel], function(x) x[-1])
      tail_idx <- idx_subset[sel]
      is_last <- i == length(head_order)
      child_exists <- any(vapply(tails, length, integer(1)) > 0)
      branch <- if (is_last) "└── " else "├── "
      next_prefix <- paste0(prefix, if (is_last) "    " else "│   ")
      # A leaf row (no child_exists) is exactly one input path; a folder row
      # (child_exists) is not itself an input path, so leaf_idx is NA.
      this_leaf <- if (child_exists) NA_integer_ else tail_idx[[1]]
      out_text <<- c(out_text, paste0(prefix, branch, head, if (child_exists) "/" else ""))
      out_leaf <<- c(out_leaf, this_leaf)
      next_subset  <- tails[vapply(tails, length, integer(1)) > 0]
      next_tailidx <- tail_idx[vapply(tails, length, integer(1)) > 0]
      if (length(next_subset) > 0) walk(next_subset, next_tailidx, next_prefix)
    }
  }

  walk(parts_list, orig_idx)
  data.frame(text = out_text, leaf_idx = out_leaf)
}

# The file tree as report text: "#### Data Tree", a legend, and per repository
# a preformatted block with each file's classification, study and naming issue.
# `files` is a file table with repo_url and file_path (or file_name), and
# optionally data_type, doc_role and group, as data_check and repo_check give
# it; `naming_issues` is repo_check's naming_issues table. NULL when there is
# nothing to draw.
.file_tree_block <- function(files, naming_issues = NULL) {
  if (is.null(files) || nrow(files) == 0 || !"repo_url" %in% names(files)) return(NULL)
  repo_urls <- unique(files$repo_url[!is.na(files$repo_url) & nzchar(files$repo_url)])
  if (length(repo_urls) == 0) return(NULL)

  # Naming detail by file_name, first match only (a name flagged by several
  # rules shows its first; the full list remains in repo_check's own table).
  naming_of <- function(file_name) {
    if (is.null(naming_issues) || nrow(naming_issues) == 0)
      return(rep(NA_character_, length(file_name)))
    hit <- match(file_name, naming_issues$file_name)
    ifelse(is.na(hit), NA_character_, naming_issues$detail[hit])
  }

  blocks <- lapply(repo_urls, function(repo) {
    sub <- files[!is.na(files$repo_url) & files$repo_url == repo, , drop = FALSE]
    rel_paths <- if ("file_path" %in% names(sub)) sub$file_path else sub$file_name
    rows <- .file_tree_rows(rel_paths)
    if (nrow(rows) == 0) return(NULL)

    data_type <- if ("data_type" %in% names(sub)) sub$data_type else NA_character_
    doc_role  <- if ("doc_role"  %in% names(sub)) sub$doc_role  else NA_character_
    group     <- if ("group"     %in% names(sub)) sub$group     else NA_character_
    naming    <- naming_of(sub$file_name)

    is_leaf <- !is.na(rows$leaf_idx)
    # A tree has to READ as a tree: every line visible at once, in order,
    # with the branch characters lining up. A table breaks that — it splits
    # the drawing into cells and pages through it, so a folder can end up on
    # a different page from its contents. So the rows are laid out as text
    # and emitted as a preformatted block, with the per-file columns padded
    # to align. Widths are computed from the content rather than fixed, so
    # a deep tree or a long type name still lines up.
    type_txt <- rep("", nrow(rows))
    type_txt[is_leaf] <- paste(
      .tree_type_icon(data_type[rows$leaf_idx[is_leaf]], doc_role[rows$leaf_idx[is_leaf]]),
      .tree_type_label(data_type[rows$leaf_idx[is_leaf]], doc_role[rows$leaf_idx[is_leaf]])
    )
    grp <- group[rows$leaf_idx[is_leaf]]
    study_txt <- rep("", nrow(rows))
    study_txt[is_leaf] <- ifelse(is.na(grp), "", grp)
    nm <- naming[rows$leaf_idx[is_leaf]]
    naming_txt <- rep("", nrow(rows))
    naming_txt[is_leaf] <- ifelse(is.na(nm), "", nm)

    # Pad to the widest entry in each column. formatC() counts characters,
    # and an emoji is one character here, so the icon does not throw the
    # alignment off in a monospaced block.
    pad <- function(x, extra = 2) {
      w <- max(nchar(x, type = "chars"), 0) + extra
      formatC(x, width = -w, flag = " ")
    }
    has_study  <- any(nzchar(study_txt))
    has_naming <- any(nzchar(naming_txt))
    # Every column is padded the same way. Trailing space on the last one is
    # stripped below, so padding it too costs nothing and keeps the columns
    # evenly separated whichever ones are present.
    lines <- paste0(
      pad(rows$text),
      pad(type_txt),
      if (has_study) pad(study_txt) else "",
      if (has_naming) naming_txt else ""
    )
    lines <- sub("\\s+$", "", lines)

    list(repo = repo, lines = lines,
         has_study = has_study, has_naming = has_naming)
  })
  blocks <- Filter(Negate(is.null), blocks)
  if (length(blocks) == 0) return(NULL)

  sections <- lapply(blocks, function(b) {
    # A fenced block with no language, so Quarto renders it verbatim in a
    # monospaced font and does not try to highlight it as code.
    #
    # The whole block is ONE element, with its lines joined by single
    # newlines. module_report() joins the report vector with blank lines
    # between elements, which is right between paragraphs but would put an
    # empty row between every line of the tree.
    c(paste0("**Repository: ", b$repo, "**"),
      paste(c("```", b$lines, "```"), collapse = "\n"))
  })

  legend <- paste0(
    "Each file is followed by how it was classified",
    if (any(vapply(blocks, function(b) b$has_study, logical(1))))
      ", which study it belongs to" else "",
    if (any(vapply(blocks, function(b) b$has_naming, logical(1))))
      ", and any file-naming issue found by repo_check" else "",
    ".")

  c("#### Data Tree",
    paste("Where the files sit within each repository.", legend),
    unlist(sections))
}

# The "#### Data Tree" part of a report (data_check's), without its heading.
# NULL when the report has no tree.
.file_tree_from_report <- function(report) {
  if (is.null(report)) return(NULL)
  start <- which(report == "#### Data Tree")
  if (length(start) == 0) return(NULL)
  start <- start[[1]]
  is_heading <- grepl("^#{1,4} ", report)
  after <- which(is_heading & seq_along(report) > start)
  end <- if (length(after) > 0) after[[1]] - 1 else length(report)
  if (end <= start) return(NULL)
  report[(start + 1):end]
}

# The file tree of a run, without its heading: data_check's (which also lists
# files inside zip archives and each file's study), else one drawn from
# repo_check's file table, since data_check reports nothing at all when a
# repository has no data file it can read. `module_output` is a list of module
# outputs named by module, as report_module_run() returns. NULL when neither
# module gives a tree.
.file_tree <- function(module_output) {
  tree <- .file_tree_from_report(module_output$data_check$report)
  if (!is.null(tree)) return(tree)
  block <- .file_tree_block(module_output$repo_check$table,
                            module_output$repo_check$naming_issues)
  if (is.null(block)) return(NULL)
  block[-1]
}
