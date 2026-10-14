test_that("dryad_links recognises every alternate Dryad DOI prefix", {
  # Regression test: repo_check missed real Dryad deposits cited under a
  # prefix other than the usual 10.5061/dryad.* form. The full prefix list
  # (see .dryad_doi_prefixes()'s own header comment) was found by
  # exhaustively random-sampling DataCite's DOI index for Dryad's client id
  # until no new prefix appeared across 40 consecutive batches, then each
  # one individually confirmed live via doi.org's own handle API to resolve
  # to a real datadryad.org dataset page.
  expect_true(is.function(metacheck::dryad_links))

  alt_prefixes <- setdiff(metacheck:::.dryad_doi_prefixes(), "10.5061")
  urls <- c(
    "https://doi.org/10.5061/dryad.j1fd7",
    paste0("https://doi.org/", alt_prefixes, "/ABC123"),
    "https://doi.org/10.9999/unrelated123"
  )
  paper <- test_paper(url = urls)

  links <- dryad_links(paper)

  expect_equal(nrow(links), length(alt_prefixes) + 1)
  expect_true(all(paste0(c("10.5061", alt_prefixes), "/") %in%
                    paste0(sub("[^/]+$", "", tolower(unname(links$dryad_doi))))))
})

test_that(".dryad_doi extracts the DOI from every recognised prefix", {
  expect_true(is.function(metacheck:::.dryad_doi))

  expect_equal(
    metacheck:::.dryad_doi("https://doi.org/10.5061/dryad.j1fd7"),
    "10.5061/dryad.j1fd7"
  )
  expect_equal(
    metacheck:::.dryad_doi("https://doi.org/10.25338/B8N33J"),
    "10.25338/b8n33j"
  )
  expect_equal(
    metacheck:::.dryad_doi("https://doi.org/10.5068/D14671"),
    "10.5068/d14671"
  )
  expect_equal(
    metacheck:::.dryad_doi("https://doi.org/10.6075/j0w37ttw"),
    "10.6075/j0w37ttw"
  )
  expect_equal(
    metacheck:::.dryad_doi("https://doi.org/10.7941/d18907"),
    "10.7941/d18907"
  )
  # An unrelated DOI under a different registrant prefix must not match --
  # the alternate-prefix list is an explicit, verified allowlist, not a
  # wildcard, precisely to avoid this.
  expect_true(is.na(metacheck:::.dryad_doi("https://doi.org/10.9999/unrelated123")))
})

test_that("dryad_info() does not crash on dryad_links()'s own output for an unfound DOI", {
  # Regression test: dryad_info(dryad_links(paper)) -- the documented,
  # normal usage -- crashed with "Join columns in `x` must be present in
  # the data" whenever the dataset wasn't found. dryad_links()'s output
  # already carries a dryad_doi column; dryad_info() independently
  # recomputed its own `ids$dryad_doi` and left-joined it onto the table
  # without dropping the caller's existing column first, producing
  # dryad_doi.x/.y suffixes that broke the SECOND join further down
  # (by = "dryad_doi") -- confirmed live 2026-09-19, and the same shape
  # in 6 other archive-*.R files (see their own test files / commit).
  paper <- test_paper(url = "https://doi.org/10.5061/dryad.notarealdataset999")
  links <- dryad_links(paper)
  expect_warning(
    expect_no_error(dryad_info(links))
  )
})

test_that(".dryad_download_one_file reports a 401 distinctly from other failures (issue #456.6)", {
  # Dryad's file-byte endpoints 401 without an API key, even for a fully
  # public dataset. Before this fix, dryad_file_download() (the standalone
  # export) left no record of WHY a file failed, so this looked identical to
  # any other download problem once the file stayed un-downloaded. The main
  # pipeline path (download_repo_files(), tested in test-repo-download.R) was
  # already fixed for this; this covers the same mechanism in the
  # less-used standalone export.
  target <- withr::local_tempfile()
  withr::local_envvar(DRYAD_PAT = "", DRYAD_CLIENT_ID = "", DRYAD_CLIENT_SECRET = "")

  httr2::local_mocked_responses(list(
    httr2::response(status_code = 401, url = "https://datadryad.org/api/v2/files/1/download")
  ))
  got <- metacheck:::.dryad_download_one_file(
    "https://datadryad.org/api/v2/files/1/download", target)
  expect_false(got$ok)
  expect_match(got$error, "^HTTP 401")
  expect_match(got$error, "Dryad requires an API key")
  expect_false(file.exists(target))

  # A real public-host 401 (not Dryad) must NOT get the Dryad-specific hint.
  httr2::local_mocked_responses(list(
    httr2::response(status_code = 401, url = "https://example.com/file/1")
  ))
  got_other <- metacheck:::.dryad_download_one_file("https://example.com/file/1", target)
  expect_false(got_other$ok)
  expect_equal(got_other$error, "HTTP 401")

  # A genuine success writes the bytes and reports no error.
  httr2::local_mocked_responses(list(
    httr2::response(status_code = 200, body = charToRaw("file contents"),
                    url = "https://datadryad.org/api/v2/files/1/download")
  ))
  got_ok <- metacheck:::.dryad_download_one_file(
    "https://datadryad.org/api/v2/files/1/download", target)
  expect_true(got_ok$ok)
  expect_true(file.exists(target))
  expect_equal(rawToChar(readBin(target, "raw", n = file.size(target))), "file contents")
})


# The test bodies below are wrapped in local(): helper.R's test_that()
# wrapper evaluates a test's code in the test FILE's environment, so a
# withr/testthat local_*() call made directly in it would stay in force
# until the end of the file instead of the end of the test.

# Clear every Dryad credential for one test, so .dryad_headers() adds no
# OAuth step (which would send its own token request past the mocks) and
# the once-per-session "no Dryad API key" message stays quiet.
local_no_dryad_key <- function(env = parent.frame()) {
  withr::local_envvar(DRYAD_PAT = "", DRYAD_CLIENT_ID = "", DRYAD_CLIENT_SECRET = "",
                      .local_envir = env)
  withr::local_options(list(metacheck.dryad.pat = NULL,
                            metacheck.dryad.client_id = NULL,
                            metacheck.dryad.client_secret = NULL,
                            metacheck.dryad_pat.notified = TRUE),
                       .local_envir = env)
}

test_that(".dryad_list_files follows _links.next to the last page", local({
  # Recorded 2026-10-13 from doi:10.5061/dryad.9ghx3ffgc (22 files), read at
  # per_page = 10 so the 22 files arrive over three pages; the fixtures are
  # trimmed to the fields metacheck reads. Before this fix only the first
  # page (Dryad's default 20 files) was ever read.
  local_no_dryad_key()
  files <- metacheck:::.dryad_list_files("/api/v2/versions/104509/files",
                                         dryad_doi = "10.5061/dryad.9ghx3ffgc",
                                         per_page = 10)
  expect_length(files, 22)
  expect_equal(attr(files, "dryad_total"), 22)
  expect_null(attr(files, "dryad_incomplete"))
  paths <- vapply(files, \(f) f$path, character(1))
  expect_equal(length(unique(paths)), 22)
}), "mock")

test_that(".dryad_info lists more than 20 files and reports storageSize", local({
  local_no_dryad_key()
  info <- metacheck:::.dryad_info("10.5061/dryad.9ghx3ffgc")
  expect_length(info$files[[1]], 22)
  expect_equal(info$storage_size, 756438)
  expect_equal(info$files_total, 22)
  expect_false(info$files_incomplete)
  # storageSize equals the sum of the listed sizes for this dataset
  expect_equal(sum(vapply(info$files[[1]], \(f) as.numeric(f$size), numeric(1))),
               info$storage_size)
}), "mock")

test_that(".dryad_list_files warns and marks a listing that stops early", local({
  local_no_dryad_key()
  page1 <- list(
    `_links` = list(`next` = list(href = "/api/v2/versions/1/files?page=2&per_page=100")),
    count = 2, total = 3,
    `_embedded` = list(`stash:files` = list(list(path = "a.csv", size = 1),
                                            list(path = "b.csv", size = 2))))
  httr2::local_mocked_responses(function(req) {
    if (grepl("page=2", req$url)) return(httr2::response(status_code = 404, url = req$url))
    httr2::response_json(body = page1)
  })
  expect_warning(
    files <- metacheck:::.dryad_list_files("/api/v2/versions/1/files", dryad_doi = "10.5061/dryad.x"),
    "only 2 of 3 files")
  expect_length(files, 2)
  expect_equal(attr(files, "dryad_incomplete"), c(expected = 3, got = 2))

  # A first page that fails altogether is reported too, not returned as an
  # empty dataset.
  httr2::local_mocked_responses(function(req) httr2::response(status_code = 404, url = req$url))
  expect_warning(
    files <- metacheck:::.dryad_list_files("/api/v2/versions/1/files", dryad_doi = "10.5061/dryad.x"),
    "only 0 of its files")
  expect_length(files, 0)
  expect_false(is.null(attr(files, "dryad_incomplete")))

  # A single complete page: no warning, no mark.
  one <- page1
  one$`_links` <- list()
  one$total <- 2
  httr2::local_mocked_responses(function(req) httr2::response_json(body = one))
  expect_no_warning(
    files <- metacheck:::.dryad_list_files("/api/v2/versions/1/files"))
  expect_length(files, 2)
  expect_null(attr(files, "dryad_incomplete"))
}))

test_that(".dryad_verify_downloads checks SHA-256 as well as MD5 digests", local({
  dir <- withr::local_tempdir()
  writeLines("hello dryad", file.path(dir, "a.txt"))
  writeLines("second file", file.path(dir, "b.txt"))
  writeLines("third file", file.path(dir, "c.txt"))
  sha_a <- metacheck:::.bibr12_sha256(file.path(dir, "a.txt"))
  skip_if(is.na(sha_a), "no SHA-256 implementation available")
  md5_b <- unname(tools::md5sum(file.path(dir, "b.txt")))

  files <- data.frame(
    path = c("a.txt", "b.txt", "c.txt"),
    size = file.size(file.path(dir, c("a.txt", "b.txt", "c.txt"))),
    checksum = c(sha_a, md5_b, strrep("0", 64)),
    # digestType as Dryad publishes it ("sha-256", "md5")
    checksum_type = c("sha-256", "md5", "sha-256"),
    downloaded = TRUE
  )
  out <- metacheck:::.dryad_verify_downloads(files, dir)
  expect_equal(out$checksum_ok, c(TRUE, TRUE, FALSE))
  expect_equal(out$downloaded, c(TRUE, TRUE, FALSE))

  # An unrecognised digest type is left unverified rather than failed.
  files$checksum_type <- c("sha-512", "md5", NA)
  out <- metacheck:::.dryad_verify_downloads(files, dir)
  expect_equal(out$checksum_ok, c(NA, TRUE, NA))
  expect_equal(out$downloaded, c(TRUE, TRUE, TRUE))
}))
