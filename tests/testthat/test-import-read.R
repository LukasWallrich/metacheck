
test_that(".read_bibr", {
  expect_true(is.function(metacheck::.read_bibr))
  expect_no_error(helplist <- help(.read_bibr, metacheck))

  expect_error(.read_bibr(bad_arg))

  # single paper from json
  file_path <- demofile("json")
  paper <- .read_bibr(file_path)

  expect_true(paper_validate(paper))
  #expect_match(paper$paper_id, "^[a-f0-9]{14,16}$")
})

test_that("read", {
  expect_true(is.function(metacheck::read))
  expect_no_error(helplist <- help(read, metacheck))

  expect_error(read(bad_arg))

  # no files
  file_path <- file.path(withr::local_tempdir(), "emptydir")
  dir.create(file_path)
  expect_message(paper <- read(file_path))
  expect_equal(length(paper), 0)

  # no relevant files
  txt_path <- file.path(file_path, "hi.txt")
  write("hi", txt_path)
  expect_message(paper <- read(file_path))
  expect_equal(length(paper), 0)
})

test_that("read - json and xml together", {
  # set up temp
  file_path <- file.path(withr::local_tempdir(), "a")
  dir.create(file_path)
  file.copy(demofile("xml"), file.path(file_path, "demo.xml"))
  file.copy(demofile("json"), file.path(file_path, "demo.json"))

  paper <- read(file_path)
  expect_true(.is_paper(paper))
})

test_that("read - recursive", {
  skip_no_psychsci()
  # set up temp
  a <- file.path(withr::local_tempdir(), "a")
  b1 <- file.path(a, "b1")
  b2 <- file.path(a, "b2")
  dir.create(a)
  dir.create(b1)
  dir.create(b2)

  sink <- paper_write(psychsci[[1]], save_path = a )
  sink <- paper_write(psychsci[[1]], save_path = b1)
  sink <- paper_write(psychsci[[2]], save_path = b1)
  sink <- paper_write(psychsci[[3]], save_path = b1)
  sink <- paper_write(psychsci[[3]], save_path = b2)

  # no recursive ----
  paper <- read(a)
  expect_equal(paper$paper_id, psychsci[[1]]$paper_id)

  paper <- read(b1)
  expect_equal(paper_id(paper), paper_id(psychsci[1:3]))

  # recursive ----
  # the same paper in two folders: the second copy is renamed "~2" (U208)
  expect_warning(paper <- read(a, recursive = TRUE), "shared a paper_id")
  expect_equal(length(paper), 5)
  # read(recursive = TRUE) lists files via list.files(..., recursive = TRUE),
  # which returns paths in alphabetical order -- derive the expectation the
  # same way rather than hardcoding a paper-id-dependent pattern.
  exp <- list.files(a, pattern = "\\.json$", recursive = TRUE, full.names = TRUE) |>
    sort() |>
    basename() |>
    gsub("\\.json$", "", x = _)
  exp <- ifelse(duplicated(exp), paste0(exp, "~2"), exp)
  expect_equal(paper_id(paper), exp)
})

test_that("read - single paper", {
  file_path <- demofile("json")
  paper <- read(file_path)

  expect_s3_class(paper, "scivrs_paper")
  expect_true(paper_validate(paper))

  # check for no urls ending in .
  end_dot <- grepl("\\.$", paper$url$href)
  expect_true(all(!end_dot))
  expect_true(all(is.na(paper$figure$image)))
})

# test_that("read - images", {
#   file_path <- system.file("demos/to_err_is_human.json", package = "metacheck")
#   paper <- read(file_path, include_images = TRUE)
#
#   expect_true(paper_validate(paper))
#   expect_true(all(!is.na(paper$figure$image)))
# })

test_that("read - vector of paths", {
  file_path <- demofile("json")
  paper <- read(file_path)

  file_path <- c(
    demofile("json"),
    test_path("fixtures", "psychsci", "0956797613520608.json")
  )
  papers <- read(file_path)
  expect_s3_class(papers, "scivrs_paperlist")
  expect_true(paper_validate(papers[[1]]))
  expect_true(paper_validate(papers[[2]]))

  expect_equal(paper, papers[[1]])
  expect_equal(names(papers),
               c(papers[[1]]$paper_id, papers[[2]]$paper_id))
})

test_that("read - directory", {
  file_path <- test_path("fixtures", "psychsci")
  papers <- read(file_path)
  expect_s3_class(papers, "scivrs_paperlist")
  expect_true(paper_validate(papers[[1]]))
  expect_true(paper_validate(papers[[2]]))
  expect_true(paper_validate(papers[[3]]))
})

test_that("a JSON file that is not a paper is refused with a clear message (#499)", {
  f <- withr::local_tempfile(fileext = ".json")
  for (txt in c("{}", "[]", '{"foo": 1}', '{"paper_id": ""}')) {
    writeLines(txt, f)
    expect_error(metacheck:::.read_bibr(f), "is not bibr output", fixed = TRUE)
    # read() skips it with a warning instead of returning a paper without an id
    expect_warning(p <- read(f), "is not bibr output")
    expect_length(p, 0)
  }
})

test_that("module_run reports the module's own error for a paper without an id (#499)", {
  p <- paper()
  p$paper_id <- character(0)
  p$info <- data.frame(title = "x")
  # paper_id() itself fails on such a paper
  expect_error(paper_id(p))
  # the module's error is the one reported, not paper_id()'s
  err <- tryCatch(module_run(p, "power"), error = function(e) conditionMessage(e))
  expect_match(err, "Running the module 'power' produced errors", fixed = TRUE)
})

test_that("a legacy bibr file without bib has no references, not its bib_match rows (U25)", {
  # data$bib matched data$bib_match by its prefix
  f <- withr::local_tempfile(fileext = ".json")
  writeLines('{"paper_id": "p1", "info": {"title": "T"}, "bib_match": [{"bib_id": 1, "title": "Matched"}]}', f)
  p <- suppressWarnings(read(f))
  expect_equal(nrow(p$bib), 0)
})
