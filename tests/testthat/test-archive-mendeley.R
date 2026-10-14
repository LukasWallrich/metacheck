test_that("mendeley_links finds real hyperlinks and a bare-text mention", {
  expect_true(is.function(metacheck::mendeley_links))

  paper <- test_paper(url = c(
    "https://data.mendeley.com/datasets/vjtxybrc28/1",
    "https://doi.org/10.17632/vjtxybrc28.1",
    "https://osf.io/abcde"
  ))
  links <- mendeley_links(paper)
  expect_equal(nrow(links), 2)
  expect_true(all(unname(links$mendeley_id) == "vjtxybrc28"))
  expect_true(all(links$mendeley_link == "https://doi.org/10.17632/vjtxybrc28"))

  paper_text <- test_paper(text = "data are available at 10.17632/vjtxybrc28.1 under CC-BY")
  links_text <- mendeley_links(paper_text)
  expect_equal(nrow(links_text), 1)
  expect_equal(unname(links_text$mendeley_id), "vjtxybrc28")
})


test_that(".mendeley_id extracts the dataset id from every citation form", {
  expect_true(is.function(metacheck:::.mendeley_id))

  mendeley_url <- c(
    "vjtxybrc28",
    "https://doi.org/10.17632/vjtxybrc28.1",
    "https://doi.org/10.17632/vjtxybrc28",
    "10.17632/vjtxybrc28.1",
    "https://data.mendeley.com/datasets/vjtxybrc28/1",
    "https://data.mendeley.com/datasets/vjtxybrc28",
    "not-a-mendeley-url",
    "",
    NA_character_
  )

  ids <- .mendeley_id(mendeley_url)
  expect_equal(unname(ids), c(
    "vjtxybrc28", "vjtxybrc28", "vjtxybrc28", "vjtxybrc28",
    "vjtxybrc28", "vjtxybrc28",
    NA_character_, NA_character_, NA_character_
  ))

  expect_equal(.mendeley_id(NULL), character(0))
})


test_that("mendeley_links builds a NA link for an unresolvable id, not a malformed DOI", {
  paper <- test_paper(url = "https://data.mendeley.com/datasets/")
  links <- mendeley_links(paper)
  if (nrow(links) > 0) {
    expect_true(all(is.na(links$mendeley_link[is.na(links$mendeley_id)])))
  }
})


test_that(".mendeley_info retrieves real metadata for a known public dataset", {
  info <- metacheck:::.mendeley_info("vjtxybrc28")

  expect_false("error" %in% names(info))
  expect_equal(
    info$title,
    "Reference group influences and campaign exposure effects on rhino horn demand"
  )
  expect_equal(info$doi, "10.17632/vjtxybrc28.1")
  expect_equal(info$license, "CC BY 4.0")
  expect_true(grepl("Dang Vu", info$authors[[1]]))
  # files is the raw parsed-JSON list (rec$files), not a data frame, unlike
  # several sibling archive-*.R files' own `files` columns -- confirmed
  # directly rather than assumed.
  expect_equal(length(info$files[[1]]), 1)
  expect_equal(info$files[[1]][[1]]$filename, "rhusers1.csv")
})


test_that(".mendeley_info marks a malformed id as unfound (real HTTP 400)", {
  expect_warning(
    info <- metacheck:::.mendeley_info("zzzzznope"),
    "could not be found"
  )
  expect_equal(info$error, "unfound")
})


test_that(".mendeley_info reports a well-formed but nonexistent id as unfound", {
  # Mendeley has answered this two ways: HTTP 200 with only an error in the
  # body ({"error":{"message":"error - dataset not found","status":404}},
  # 2026-10-05), and HTTP 400 (2026-10-14). Both are reported as "unfound";
  # the live request below covers whichever Mendeley gives today, and the
  # mocked one the 200-with-error answer.
  info <- suppressWarnings(metacheck:::.mendeley_info("doesnotexist12345xyz"))
  expect_equal(info$error, "unfound")

  local({
    httr2::local_mocked_responses(function(req) httr2::response_json(
      body = list(error = list(message = "error - dataset not found", status = 404))))
    info2 <- suppressWarnings(metacheck:::.mendeley_info("doesnotexist12345xyz"))
    expect_equal(info2$error, "unfound")
  })
})
