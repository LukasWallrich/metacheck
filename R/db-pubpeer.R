#' Get Pubpeer Comments
#'
#' Takes a DOI, and retrieves information from pubpeer related to post-publication peer review comments.
#'
#' @param doi a vector of paper DOIs
#'
#' @returns a dataframe with information from pubpeer
#' @export
#'
#' @examples
#' doi <- c(
#'   "10.1038/s41598-025-24662-9",
#'   "10.1177/0146167211398138"
#' )
#' pubpeer_comments(doi)
pubpeer_comments <- function(doi) {
  url <- "https://pubpeer.com/v3/publications?devkey=PubPeerZotero"
  doi_na <- doi[!is.na(doi)]
  # I(): auto_unbox sent a single DOI as a JSON string, not an array (U14)
  body <- list(dois = I(tolower(doi_na))) |>
    jsonlite::toJSON(auto_unbox = TRUE)

  resp <- .mc_request(url) |>
    httr2::req_headers(`Content-Type` = "application/json;charset=UTF-8") |>
    httr2::req_body_raw(body, type = "application/json;charset=UTF-8") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) == 200) {
    data <- httr2::resp_body_json(resp)
    # feedback without an id cannot be matched to a DOI; when none had one,
    # the table had no doi column and the join below stopped (U14)
    feedbacks <- Filter(\(fb) length(fb$id) == 1, data$feedbacks)
    pp_fb <- lapply(feedbacks, \(fb) {
      list(
        doi = fb$id,
        total_comments = fb$total_comments,
        url = fb$url,
        users = paste(trimws(fb$users), collapse = ", ")
      )
    }) |>
      do.call(dplyr::bind_rows, args = _)

    if (nrow(pp_fb) == 0) {
      all <- data.frame(
        doi = tolower(doi),
        total_comments = 0,
        url = NA_character_,
        users = NA_character_
      )
    } else {
      # a DOI reported twice keeps its first feedback (no duplicated rows)
      pp_fb <- pp_fb[!duplicated(pp_fb$doi), , drop = FALSE]
      all <- data.frame(doi = tolower(doi)) |>
        dplyr::left_join(pp_fb, by = "doi")
      all$doi <- doi
      all$total_comments[is.na(all$total_comments)] <- 0
    }

    return(all)
  } else {
    return(NULL) # Request failed
  }
}
