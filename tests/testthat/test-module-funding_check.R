test_that("funding_check with two funding title lines (U103)", {
  # the if() on a vector of title lines stopped the module for the whole list
  llm_use(FALSE)
  txt <- c("Funding", "This work was supported by NWO grant 123.", "Funding:", "None.")
  mo <- suppressMessages(module_run(test_paper(text = txt), "funding_check"))
  expect_match(mo$table$text, "supported by NWO grant 123", fixed = TRUE)
  expect_false(grepl("NA", mo$table$text, fixed = TRUE))
})

test_that("funding_check synonyms match, and the reference list starts at a sentence that begins with its title (U104)", {
  # "Ffoundation", "L(?i)terature" and "B(?i)ibliograpy" never matched, and
  # any sentence ending in "References <Capital>" was taken as the start
  env <- new.env(parent = asNamespace("metacheck"))
  sys.source(metacheck:::module_find("funding_check"), envir = env)
  s <- env$.create_synonyms()
  expect_true(any(grepl(paste(s$foundation, collapse = "|"), "Gates Foundation", perl = TRUE)))
  expect_true(any(grepl(paste(s$References, collapse = "|"), "Bibliography", perl = TRUE)))
  art <- c("Intro.", "References", "Smith 2020.", "Appendix: see the References Section.")
  expect_equal(env$.where_refs_txt(art), 2L)
})
