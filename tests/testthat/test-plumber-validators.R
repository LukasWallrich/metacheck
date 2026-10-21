# Unit tests for plumber upload validation.
# Sources validators.R directly — no running API needed.

# The plumber API is left out of the built package (.Rbuildignore), so these
# tests run only from the source folder; covr and R CMD check run the tests
# on the installed package, where the file does not exist.
plumber_file <- testthat::test_path("..", "..", "inst", "plumber", "utils", "validators.R")
testthat::skip_if_not(file.exists(plumber_file), "the plumber API is not in the installed package")
source(plumber_file)

test_that("rejects missing file", {
  v <- validate_file_upload(NULL)
  expect_false(v$valid)
  expect_equal(v$status, 400)
})

test_that("rejects multiple files", {
  v <- validate_file_upload(c("a.json", "b.json"))
  expect_false(v$valid)
  expect_equal(v$status, 400)
})

test_that("rejects nonexistent file", {
  v <- validate_file_upload(tempfile(fileext = ".json"))
  expect_false(v$valid)
  expect_equal(v$status, 400)
})

test_that("accepts an existing file under the size cap", {
  f <- tempfile(fileext = ".json")
  writeLines('{"paper_id": "x"}', f)
  v <- validate_file_upload(f)
  expect_true(v$valid)
})

test_that("rejects files over the size cap", {
  f <- tempfile(fileext = ".json")
  writeLines('{"paper_id": "x"}', f)
  v <- validate_file_upload(f, max_bytes = 5)
  expect_false(v$valid)
  expect_equal(v$status, 413)
})

test_that("default cap is 50MB", {
  expect_equal(MAX_UPLOAD_BYTES, 50 * 1024 * 1024)
})
