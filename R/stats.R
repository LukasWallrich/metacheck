#' Check Stats
#'
#' @param text the search table (or list of paper objects)
#' @param ... arguments to pass to statcheck()
#'
#' @return a table of statistics
#' @export
#'
#' @examples
#' paper <- demopaper()
#' stats(paper)
stats <- function(text, ...) {
  # An argument statcheck() does not have made every call fail, and the
  # error was swallowed, so stats() returned an empty table (U4)
  args <- list(...)
  allowed <- setdiff(names(formals(statcheck::statcheck)), c("texts", "messages"))
  bad <- setdiff(names(args) %||% rep("", length(args)), allowed)
  if (length(args) && (is.null(names(args)) || length(bad)))
    stop("stats() passes only named statcheck() arguments: ",
         paste(allowed, collapse = ", "), call. = FALSE)

  # a character vector is searched as a text table, one row per string; it
  # stopped with "argument is of length zero" (U4)
  if (is.character(text))
    text <- data.frame(text = text, text_id = seq_along(text))

  # lines with stats must have at least one number
  text <- text_search(text, "[0-9]")


  n <- nrow(text)
  if (n == 0) {
    return(data.frame())
  }

  # set up progress bar ----
  pb <- pb(n, "Checking stats [:bar] :current/:total :elapsedfull")

  subchecks <- lapply(seq_along(text$text), \(i) {
    subtext <- text$text[[i]]

    # statcheck uses cat() to output messages :(
    # A warning is muffled, not caught: catching it returned nothing for
    # the sentence, so one unparseable p-value ("p = .05-.10") dropped every
    # valid result next to it (U4)
    sink_output <- utils::capture.output(
      sc <- tryCatch(
        withCallingHandlers(statcheck::statcheck(subtext, messages = FALSE, ...),
                            warning = function(w) invokeRestart("muffleWarning")),
        error = function(e) {
          return(NULL)
        }
      )
    )
    if (verbose()) pb$tick()
    if (is.null(sc)) {
      return(data.frame())
    }
    sc$source <- i

    return(sc)
  })
  checks <- do.call(rbind, subchecks)

  if (nrow(checks) == 0) {
    return(checks)
  }

  text$source <- seq_along(text$text)

  stat_table <- dplyr::left_join(checks, text, by = "source")
  rownames(stat_table) <- NULL

  stat_table[, 2:ncol(stat_table)]
}
