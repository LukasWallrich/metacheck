# Unit tests for plumber response helpers.
# Sources helpers.R directly — no running API needed.

# The plumber API is left out of the built package (.Rbuildignore), so these
# tests run only from the source folder; covr and R CMD check run the tests
# on the installed package, where the file does not exist.
plumber_file <- testthat::test_path("..", "..", "inst", "plumber", "utils", "helpers.R")
testthat::skip_if_not(file.exists(plumber_file), "the plumber API is not in the installed package")
source(plumber_file)

# Regression: LLM modules embed `ellmer_output`-classed values (from ellmer's
# structured extraction) in their table columns. jsonlite has no asJSON method
# for that class, so serializing a /check or /module response aborted the whole
# request with "No method asJSON S3 class: ellmer_output". json_safe() must
# strip such classes to plain, serializable values.

ellmer_table <- function() {
  t <- data.frame(claim = c("c1", "c2"), stringsAsFactors = FALSE)
  t$apriori <- structure(c('{"apriori": false}', '{"apriori": true}'),
                         class = "ellmer_output")
  t
}

test_that("raw ellmer_output column is unserializable (the bug)", {
  expect_error(
    jsonlite::toJSON(ellmer_table(), auto_unbox = TRUE),
    "asJSON"
  )
})

test_that("json_safe strips ellmer_output so the table serializes", {
  safe <- json_safe(ellmer_table())
  expect_silent(out <- jsonlite::toJSON(safe, auto_unbox = TRUE))
  # underlying JSON-string values are preserved, just declassed
  expect_false(inherits(safe$apriori, "ellmer_output"))
  expect_equal(safe$apriori, c('{"apriori": false}', '{"apriori": true}'))
})

test_that("json_safe handles a list-column of per-row ellmer_output", {
  t <- data.frame(x = 1:2)
  t$llm <- I(list(structure("a", class = "ellmer_output"),
                  structure("b", class = "ellmer_output")))
  safe <- json_safe(list(module = "m", summary_table = t))
  expect_silent(jsonlite::toJSON(safe, auto_unbox = TRUE))
})

test_that("json_safe sanitizes nested module-output lists", {
  obj <- structure(
    list(module = "causal_claims", table = ellmer_table(),
         section = "general", traffic_light = "info"),
    class = "metacheck_module_output"
  )
  expect_silent(jsonlite::toJSON(json_safe(obj), auto_unbox = TRUE))
})

test_that("json_safe leaves ordinary columns untouched", {
  t <- data.frame(
    n = 1:2,
    f = factor(c("a", "b")),
    d = as.Date(c("2026-01-01", "2026-01-02"))
  )
  safe <- json_safe(t)
  expect_equal(safe$n, 1:2)
  expect_s3_class(safe$d, "Date")
  expect_s3_class(safe$f, "factor")
  expect_silent(jsonlite::toJSON(safe, auto_unbox = TRUE))
})

# --- parse_bool -------------------------------------------------------------

test_that("parse_bool reads truthy/falsy spellings and falls back to default", {
  for (v in c("true", "TRUE", "True", "1", "yes", "y", "t")) expect_true(parse_bool(v))
  for (v in c("false", "FALSE", "False", "0", "no", "n", "f")) expect_false(parse_bool(v))
  # absent / blank -> default
  expect_true(parse_bool(NULL))
  expect_true(parse_bool(""))
  expect_true(parse_bool(character(0)))
  expect_false(parse_bool(NULL, default = FALSE))
  # unrecognised -> default (honours the supplied default)
  expect_true(parse_bool("maybe"))
  expect_false(parse_bool("maybe", default = FALSE))
})

# --- endpoint logic without a running API (runs in CI) ----------------------
# These exercise the real /check + /module paths — module run -> json_safe ->
# JSON serialization, and the HTML report render — without an HTTP server, so
# the headline endpoints are covered even where the API integration tests skip.
# A cheap, non-LLM, network-free module keeps them fast and deterministic.
CHEAP_MODULE <- "all_urls"

test_that("info_fields returns paper_id plus requested fields, tolerating absent ones", {
  skip_if_not(exists("demopaper"), "metacheck not loaded")
  paper <- demopaper()
  out <- info_fields(paper, c("title", "doi", "definitely_absent_field"))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1L)
  expect_true("paper_id" %in% names(out))
  expect_true(all(c("title", "definitely_absent_field") %in% names(out)))
  expect_true(is.na(out$definitely_absent_field)) # absent field -> NA
})

test_that("the /check module pipeline yields a JSON-serializable result", {
  skip_if_not(exists("demopaper"), "metacheck not loaded")
  paper <- demopaper()
  mo <- module_run(paper, CHEAP_MODULE)
  # The exact JSON-safe view /check builds for each module.
  view <- json_safe(list(
    module = mo$module, title = mo$title, table = mo$table,
    summary_table = mo$summary_table, summary_text = mo$summary_text,
    report = mo$report, traffic_light = mo$traffic_light
  ))
  expect_silent(jsonlite::toJSON(view, auto_unbox = TRUE))
})

test_that("render_report_html renders HTML from real module outputs", {
  skip_if_not(exists("demopaper"), "metacheck not loaded")
  skip_if_not(nzchar(Sys.which("quarto")), "quarto CLI not available")
  paper <- demopaper()
  mo <- module_run(paper, CHEAP_MODULE)
  html <- render_report_html(stats::setNames(list(mo), CHEAP_MODULE), paper, "test")
  expect_type(html, "character")
  expect_length(html, 1L)
  expect_match(html, "<html|<!DOCTYPE", ignore.case = TRUE)
})

test_that("render_report_html degrades gracefully (never throws, one string)", {
  # Best-effort contract: any failure returns "" rather than erroring, so the
  # JSON /check response is never sunk by a bad render.
  out <- tryCatch(render_report_html(list(), list(), "test"),
                  error = function(e) e)
  expect_false(inherits(out, "error"))
  expect_type(out, "character")
  expect_length(out, 1L)
})

# A multipart body as .NET's MultipartFormDataContent (PowerShell, C#) writes
# it, with each part's Content-Type header before its Content-Disposition, or
# as curl and httr2 write it. mime::parse_multipart() found no file in the
# first order (#498).
.multipart_498 <- function(net_order, n_files = 1) {
  b <- "5d2572d0-bf4c-4881-b097-e37483cfc876"
  part <- function(headers, value) c(paste0("--", b), if (net_order) rev(headers) else headers, "", value)
  file_part <- function(i) part(c(sprintf('Content-Disposition: form-data; name="file"; filename="paper%d.json"', i),
                                  "Content-Type: application/json"), sprintf('{"x": %d}', i))
  lines <- c(unlist(lapply(seq_len(n_files), file_part)),
             part(c('Content-Disposition: form-data; name="modules"',
                    "Content-Type: text/plain; charset=utf-8"), "power,stat_check"),
             paste0("--", b, "--"), "")
  list(bodyRaw = charToRaw(paste(lines, collapse = "\r\n")),
       CONTENT_TYPE = paste0("multipart/form-data; boundary=", b))
}

test_that("parse_upload reads a part's headers in either order (#498)", {
  skip_if_not_installed("webutils")
  for (net_order in c(TRUE, FALSE)) {
    mp <- parse_upload(.multipart_498(net_order))
    f <- extract_uploaded_file(mp)
    withr::defer(unlink(f))
    expect_length(f, 1)
    expect_equal(readLines(f, warn = FALSE), '{"x": 1}')
    expect_equal(tools::file_ext(f), "json")
    expect_equal(mp$file$name, "paper1.json")
    expect_equal(mp$modules, "power,stat_check")
  }
})

test_that("parse_upload returns every file sent under one field, for rejection (#498)", {
  skip_if_not_installed("webutils")
  mp <- parse_upload(.multipart_498(TRUE, n_files = 2))
  f <- extract_uploaded_file(mp)
  withr::defer(unlink(f))
  expect_length(f, 2)
})

test_that("parse_upload returns no fields for a body that is not multipart", {
  expect_equal(parse_upload(list(bodyRaw = charToRaw("{}"), CONTENT_TYPE = "application/json")), list())
  expect_equal(parse_upload(list()), list())
})
