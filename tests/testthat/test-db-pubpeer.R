test_that("exists", {
  expect_true(is.function(metacheck::pubpeer_comments))
  expect_no_error(helplist <- help(pubpeer_comments, metacheck))

  expect_error(pubpeer_comments(bad_arg))
})


test_that("defaults", {
  # both with comments
  doi <- c("10.1038/s41598-025-24662-9",
           "10.1177/0146167211398138")

  pp <- pubpeer_comments(doi)
  expect_equal(pp$doi, doi)
  expect_true(pp$total_comments[[1]] >= 16)

  # one with comments
  doi <- c("10.1038/s41598-025-24662-9",
           "10.1016/j.tics.2006.06.010")

  pp <- pubpeer_comments(doi)
  expect_equal(pp$doi, doi)
  expect_equal(pp$total_comments[[2]], 0)

  # none with comments
  doi <- c("10.1016/j.tics.2006.06.010")

  pp <- pubpeer_comments(doi)
  expect_equal(pp$doi, doi)
  expect_equal(pp$total_comments[[1]], 0)

  # invalid DOI
  doi <- c("nope/hasd")

  pp <- pubpeer_comments(doi)
  expect_equal(pp$doi, doi)
  expect_equal(pp$total_comments[[1]], 0)

  # one NA
  doi <- c("10.1038/s41598-025-24662-9",
           NA)

  pp <- pubpeer_comments(doi)
  expect_equal(pp$doi, doi)
  expect_equal(pp$url[[2]], NA_character_)
  expect_equal(pp$total_comments[[2]], 0)

  # empty doi
  pp <- pubpeer_comments(c())
  expect_null(pp)
}, "mock")

test_that("pubpeer_comments: one DOI is sent as an array; feedback without id or twice (U14)", {
  sent <- NULL
  answer <- list(feedbacks = list(list(total_comments = 3, url = "u", users = "a")))
  local_mocked_bindings(req_perform = function(req, ...) {
    sent <<- req$body$data
    httr2::response_json(body = answer)
  }, .package = "httr2")
  r <- pubpeer_comments("10.1/abc")
  expect_match(if (is.raw(sent)) rawToChar(sent) else as.character(sent),
               '["10.1/abc"]', fixed = TRUE)
  expect_equal(r$total_comments, 0)   # feedback without an id is not matched
  answer <- list(feedbacks = list(
    list(id = "10.1/abc", total_comments = 3, url = "u", users = "a"),
    list(id = "10.1/abc", total_comments = 9, url = "v", users = "b")))
  r <- pubpeer_comments(c("10.1/abc", "10.1/xyz"))
  expect_equal(r$total_comments, c(3, 0))   # one row per DOI, first feedback
})

test_that("check_orcid is FALSE for NA or an X before the check digit (U14)", {
  verbose(FALSE); withr::defer(verbose(FALSE))
  expect_false(check_orcid(NA))
  expect_false(check_orcid("0000-000X-0000-0001"))
  expect_equal(check_orcid("0000-0002-0247-239X"), "0000-0002-0247-239X")
})
