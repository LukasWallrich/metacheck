test_that("researchdata4tu_links finds real hyperlinks and bare mentions", {
  expect_true(is.function(metacheck::researchdata4tu_links))

  paper <- test_paper(url = c(
    "https://data.4tu.nl/articles/dataset/some_title/16766929",
    "https://doi.org/10.4121/16766929.v1",
    "https://osf.io/abcde"
  ))
  links <- researchdata4tu_links(paper)
  expect_equal(nrow(links), 2)
  expect_true(all(unname(links$researchdata4tu_id) == "16766929"))

  # A bare DOI mention in body text, never encoded as a real hyperlink.
  paper_text <- test_paper(text = "data available at 10.4121/16766929")
  links_text <- researchdata4tu_links(paper_text)
  expect_equal(nrow(links_text), 1)
  expect_equal(unname(links_text$researchdata4tu_id), "16766929")

  # A labelled bare uuid DOI mention -- passed through unresolved, since
  # researchdata4tu_links() never calls .researchdata4tu_resolve_uuid()
  # (only researchdata4tu_info() does, per that function's own header
  # comment on issue #431).
  paper_uuid <- test_paper(
    text = "https://doi.org/10.4121/uuid:ce413614-1c82-4e81-90c0-323aa7d2fabd"
  )
  links_uuid <- researchdata4tu_links(paper_uuid)
  expect_equal(nrow(links_uuid), 1)
  expect_equal(unname(links_uuid$researchdata4tu_id), "ce413614-1c82-4e81-90c0-323aa7d2fabd")
})


test_that(".researchdata4tu_id extracts an id or uuid from every citation form", {
  expect_true(is.function(metacheck:::.researchdata4tu_id))

  researchdata4tu_url <- c(
    "16766929",
    "https://doi.org/10.4121/16766929.v1",
    "https://doi.org/10.4121/16766929",
    "https://doi.org/10.4121/uuid:ce413614-1c82-4e81-90c0-323aa7d2fabd",
    "10.4121/ce413614-1c82-4e81-90c0-323aa7d2fabd",
    "https://data.4tu.nl/datasets/ce413614-1c82-4e81-90c0-323aa7d2fabd/1",
    "https://data.4tu.nl/articles/dataset/some_title/16766929",
    "not-a-4tu-url",
    "",
    NA_character_
  )

  ids <- .researchdata4tu_id(researchdata4tu_url)
  expect_equal(unname(ids), c(
    "16766929", "16766929", "16766929",
    "ce413614-1c82-4e81-90c0-323aa7d2fabd",
    "ce413614-1c82-4e81-90c0-323aa7d2fabd",
    "ce413614-1c82-4e81-90c0-323aa7d2fabd",
    "16766929",
    NA, NA, NA
  ))

  expect_equal(.researchdata4tu_id(NULL), character(0))
})


test_that("researchdata4tu_file_download returns NULL for empty/unresolvable input, no network", {
  expect_null(researchdata4tu_file_download(character(0)))
  expect_null(researchdata4tu_file_download(NA_character_))
  expect_null(researchdata4tu_file_download("not-a-4tu-url"))
})


test_that("researchdata4tu_pat gets and sets the token independently of figshare_pat", {
  old <- researchdata4tu_pat()
  on.exit(researchdata4tu_pat(old %||% ""), add = TRUE)

  researchdata4tu_pat("")
  expect_equal(researchdata4tu_pat(), "")

  researchdata4tu_pat("fake-4tu-token-for-test")
  expect_equal(researchdata4tu_pat(), "fake-4tu-token-for-test")

  expect_error(researchdata4tu_pat(123))
  expect_error(researchdata4tu_pat(c("a", "b")))
  expect_error(researchdata4tu_pat(NA_character_))

  researchdata4tu_pat(old %||% "")
})


test_that(".researchdata4tu_id correctly distinguishes a uuid from a numeric id", {
  # Guards the is_uuid branch in researchdata4tu_info() (issue #431): only a
  # genuine uuid-shaped id should ever be sent to
  # .researchdata4tu_resolve_uuid(), never a plain numeric id.
  uuid_shaped <- "ce413614-1c82-4e81-90c0-323aa7d2fabd"
  numeric_shaped <- "16766929"

  uuid_pat <- "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
  expect_true(grepl(uuid_pat, uuid_shaped, ignore.case = TRUE))
  expect_false(grepl(uuid_pat, numeric_shaped, ignore.case = TRUE))
})


test_that("researchdata4tu_info retrieves real metadata when the API is reachable", {
  # data.4tu.nl's v2 API answers every JSON request with {"status":
  # "maintenance"} during a maintenance window (confirmed live 2026-10-05) --
  # not an HTTP error, so .figshare_info()'s own `resp_status != 200` check
  # cannot detect it, and this live test would otherwise fail during an
  # actual outage rather than report it as unrelated to this package's code.
  # Checked explicitly first so the test reports a skip, not a failure, when
  # the live dependency itself is down.
  maintenance <- tryCatch({
    resp <- httr2::request("https://data.4tu.nl/v2/articles/16766929") |>
      httr2::req_headers(Accept = "application/json") |>
      httr2::req_error(is_error = \(resp) FALSE) |>
      httr2::req_perform()
    body <- httr2::resp_body_json(resp, check_type = FALSE)
    identical(body$status, "maintenance")
  }, error = \(e) TRUE)
  skip_if(maintenance, "data.4tu.nl is in maintenance mode")

  info <- researchdata4tu_info("https://doi.org/10.4121/16766929.v1")
  expect_equal(unname(info$researchdata4tu_id), "16766929")
  expect_false(is.na(info$title))
  expect_false(is.na(info$doi))
})


# The test bodies below are wrapped in local(): helper.R's test_that()
# wrapper evaluates a test's code in the test FILE's environment, so a
# withr/testthat local_*() call made directly in it would stay in force
# until the end of the file instead of the end of the test.

test_that("researchdata4tu_info resolves only uuids from a 'uuid:' DOI", local({
  # A bare-uuid DOI (10.4121/<uuid>) or a data.4tu.nl/datasets/<uuid>
  # address carries the record's own uuid, which v2/articles/<uuid> accepts
  # directly (verified 2026-10-13); resolving it built "10.4121/uuid:<uuid>",
  # a DOI that does not exist. Only the legacy "uuid:" form needs resolving.
  resolved <- character(0)
  queried <- character(0)
  local_mocked_bindings(
    online = \(...) TRUE,
    .researchdata4tu_resolve_uuid = function(uuid) {
      resolved <<- c(resolved, uuid)
      "12675218"
    },
    .figshare_info = function(id, host, pb = NULL) {
      queried <<- c(queried, id)
      data.frame(figshare_id = id, title = paste("title", id))
    }
  )
  info <- researchdata4tu_info(c(
    "https://doi.org/10.4121/uuid:04b25e70-ca3e-489f-9510-36385c1a4104",
    "https://doi.org/10.4121/ce413614-1c82-4e81-90c0-323aa7d2fabd",
    "https://data.4tu.nl/datasets/ce413614-1c82-4e81-90c0-323aa7d2fabd/1"
  ))
  expect_equal(resolved, "04b25e70-ca3e-489f-9510-36385c1a4104")
  expect_setequal(queried, c("12675218", "ce413614-1c82-4e81-90c0-323aa7d2fabd"))
  expect_equal(unname(info$researchdata4tu_id),
               c("12675218", rep("ce413614-1c82-4e81-90c0-323aa7d2fabd", 2)))
}))

test_that(".researchdata4tu_resolve_uuid reads the numeric id from the handle API", local({
  seen <- character(0)
  httr2::local_mocked_responses(function(req) {
    seen <<- c(seen, req$url)
    if (grepl("04b25e70", req$url)) {
      # the real registered URL, verified 2026-10-13
      return(httr2::response_json(body = list(responseCode = 1, values = list(
        list(type = "URL", data = list(value = "https://data.4tu.nl/articles/_/12675218/1"))))))
    }
    httr2::response_json(status_code = 404, body = list(responseCode = 100))
  })
  expect_equal(.researchdata4tu_resolve_uuid("04b25e70-ca3e-489f-9510-36385c1a4104"), "12675218")
  expect_equal(seen, "https://doi.org/api/handles/10.4121%2Fuuid%3A04b25e70-ca3e-489f-9510-36385c1a4104?type=URL")
  # an unregistered DOI falls back to the uuid itself, as before
  expect_equal(.researchdata4tu_resolve_uuid("00000000-0000-0000-0000-000000000000"),
               "00000000-0000-0000-0000-000000000000")
}))

test_that("researchdata4tu_file_download resolves a 'uuid:' DOI, and only that", local({
  resolved <- character(0)
  passed <- NULL
  local_mocked_bindings(
    .researchdata4tu_resolve_uuid = function(uuid) {
      resolved <<- c(resolved, uuid)
      "12675218"
    },
    figshare_file_download = function(figshare_id, ...) {
      passed <<- figshare_id
      NULL
    }
  )
  researchdata4tu_file_download(c(
    "https://doi.org/10.4121/uuid:04b25e70-ca3e-489f-9510-36385c1a4104",
    "https://doi.org/10.4121/ce413614-1c82-4e81-90c0-323aa7d2fabd",
    "16766929"))
  expect_equal(resolved, "04b25e70-ca3e-489f-9510-36385c1a4104")
  expect_equal(unname(passed),
               c("12675218", "ce413614-1c82-4e81-90c0-323aa7d2fabd", "16766929"))
}))

test_that(".researchdata4tu_id reads uuid DOIs and every article address form (U41, U156)", {
  # a uuid starting with digits gave its first digits as the id, and the
  # short "_/" and software addresses gave no id
  expect_equal(
    .researchdata4tu_id(c("10.4121/7f866e02-1c82-4e81-90c0-323aa7d2fabd",
                          "https://data.4tu.nl/articles/_/12675218/1",
                          "https://data.4tu.nl/articles/software/my_tool/12675218",
                          "https://data.4tu.nl/articles/dataset/name/12675218",
                          "10.4121/12675218.v1",
                          "ce413614-1c82-4e81-90c0-323aa7d2fabd")),
    c("7f866e02-1c82-4e81-90c0-323aa7d2fabd", "12675218", "12675218", "12675218",
      "12675218", "ce413614-1c82-4e81-90c0-323aa7d2fabd"))
})
