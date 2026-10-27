test_that("ref_consistency", {
  module <- "ref_consistency"
  mods <- module_list()
  expect_true(module %in% mods$name)

  paper <- demopaper()

  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "red")
  expect_equal(nrow(mod_output$table), 4)
  expect_equal(mod_output$module, module)

  # iteration
  skip_no_psychsci()
  paper <- psychsci[c(23, 25)]
  mod_output1 <- module_run(paper[[1]], module)
  mod_output2 <- module_run(paper[[2]], module)
  mod_output3 <- module_run(paper, module)
  t12 <- rbind(mod_output1$table, mod_output2$table)
  diffs <- dplyr::setdiff(t12, mod_output3$table)
  expect_equal(nrow(diffs), 0)
})

test_that("ref_miscitation", {
  module <- "ref_miscitation"
  mods <- module_list()
  expect_true(module %in% mods$name)

  paper <- demopaper()

  ## custom db
  test_doi <- "10.1037/0003-066x.54.6.408"
  db <- data.frame(
    doi = test_doi,
    reftext = "The full reference (this is a test)",
    warning = "Lorem ipsum this is a test..."
  )

  mod_output <- module_run(paper, module, db = db)
  expect_equal(mod_output$table$doi[[1]], test_doi)
  expect_equal(mod_output$summary_table$`miscite_10.1037/0003-066x.54.6.408`,
               1)

  ## all matched papers are reported
  db <- data.frame(
    doi = unique(na.omit(paper$bib$doi))[1:2],
    reftext = c("Reference A", "Reference B"),
    warning = c("Warning A", "Warning B")
  )
  mod_output <- module_run(paper, module, db = db)
  expect_length(mod_output$report, 2)
})


test_that("ref_accuracy", {
  module <- "ref_accuracy"
  mods <- module_list()
  expect_true(module %in% mods$name)

  # no references
  paper <- demopaper()
  paper$bib <- paper$bib[c(), ]
  paper$bib_match <- NULL
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "na")
  expect_null(mod_output$table)

  # no bib_match
  paper <- demopaper()
  paper$bib_match <- NULL
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "na")
  expect_null(mod_output$table)
  expect_match(mod_output$summary_text, "not looked up at Crossref")

  # relevant references
  paper <- demopaper()
  mod_output <- module_run(paper, module)
  expect_equal(nrow(mod_output$table), nrow(paper$bib))

  # references that supplied a DOI are checked; the demo paper includes two
  # references with a DOI that does not resolve, which are flagged as incoherent,
  # and one without a DOI, which CrossRef matched by title (#528)
  st <- mod_output$summary_table
  expect_equal(st$refs_checked, 4)
  expect_equal(st$no_doi, 1)
  expect_equal(st$incoherent, 2)
  expect_equal(mod_output$traffic_light, "yellow")

  # those two are the "unresolved" tier: a cited DOI CrossRef could not find
  unresolved <- mod_output$table[mod_output$table$tier == "unresolved", ]
  expect_equal(nrow(unresolved), 2)
  expect_true(all(unresolved$incoherent))

  # a checked reference (one whose DOI resolves) whose cited journal differs
  # from the record its DOI points to is also incoherent. Corrupt the journal
  # of a "provided" reference and confirm one more reference is flagged.
  checked_id <- mod_output$table$bib_id[mod_output$table$tier == "provided"][[1]]
  bad <- demopaper()
  bad$bib$container[bad$bib$bib_id == checked_id] <-
    "A Completely Different Journal Name"
  bad_out <- module_run(bad, module)
  expect_equal(bad_out$traffic_light, "yellow")
  expect_equal(bad_out$summary_table$incoherent, 3)

  # min_mismatches controls whether a single title/author mismatch flags. A lone
  # author mismatch flags at the default (1) but not when set to 2.
  auth <- demopaper()
  auth$bib$authors[auth$bib$bib_id == checked_id] <- "Nonexistent, A; Madeup, B"
  loose  <- module_run(auth, module)                       # default = 1
  strict <- module_run(auth, module, min_mismatches = 2)   # conservative
  # the two unresolved references are always incoherent; the lone author
  # mismatch adds a third only at the sensitive setting
  expect_equal(loose$summary_table$incoherent, 3)
  expect_equal(strict$summary_table$incoherent, 2)
})

test_that("ref_replication", {
  module <- "ref_replication"
  mods <- module_list()
  expect_true(module %in% mods$name)

  # no references
  paper <- demopaper()
  paper$bib <- paper$bib[c(), ]
  paper$bib_match <- NULL
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "na")
  expect_null(mod_output$table)

  # no DOIs
  paper <- demopaper()
  paper$bib$doi[[1]] <- NA
  paper$bib <- paper$bib[is.na(paper$bib$doi), ]
  paper$bib_match <- NULL
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "na")
  expect_null(mod_output$table)

  # relevant references
  paper <- demopaper()
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "info")
  expect_equal(nrow(mod_output$table), 1)

  mod_output <- module_run(paper, module, show_outcomes = TRUE)
  expect_equal(mod_output$table$replication_outcome, "failed")
  expect_equal(mod_output$table$replication_type, "replication")
})

test_that("ref_retraction", {
  module <- "ref_retraction"
  mods <- module_list()
  expect_true(module %in% mods$name)

  # no references
  paper <- demopaper()
  paper$bib <- paper$bib[c(), ]
  paper$bib_match <- NULL
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "na")
  expect_null(mod_output$table)

  # no DOIs
  paper <- demopaper()
  paper$bib <- paper$bib[is.na(paper$bib$doi), ]
  paper$bib_match <- NULL
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "na")
  expect_null(mod_output$table)

  # relevant references
  paper <- demopaper()
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "info")
  expect_equal(nrow(mod_output$table), 1)
  expect_equal(mod_output$table$retractionwatch, "Retraction")
})

test_that("ref_pubpeer", {
  skip_no_psychsci()
  module <- "ref_pubpeer"
  mods <- module_list()
  expect_true(module %in% mods$name)

  # no references
  paper <- demopaper()
  paper$bib <- paper$bib[c(), ]
  paper$bib_match <- paper$bib_match[c(), ]
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "na")
  expect_null(mod_output$table)

  # no bib_match
  paper <- demopaper()
  paper$bib_match <- NULL
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "info")
  expect_equal(sum(mod_output$table$total_comments), 3)

  # no DOIs
  paper <- demopaper()
  paper$bib <- paper$bib[is.na(paper$bib$doi), ]
  paper$bib_match <- NULL
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "na")
  expect_null(mod_output$table)

  # relevant references
  paper <- demopaper()
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "info")
  expect_equal(sum(mod_output$table$total_comments), 3)

  # multiple papers
  paper <- psychsci[c(4, 9)]
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "info")
  expect_gte(nrow(mod_output$table), 2)
  expect_equal(mod_output$summary_table$paper_id, names(psychsci)[c(4, 9)])
}, "mock")


test_that("ref_summary", {
  module <- "ref_summary"
  mods <- module_list()
  expect_true(module %in% mods$name)

  # relevant references
  paper <- demopaper()
  mod_output <- module_run(paper, module)
  expect_equal(mod_output$traffic_light, "info")
  expect_equal(nrow(mod_output$table), 5)
  expect_in("doi", names(mod_output$table))
  expect_disjoint("crossref_doi_mismatch", names(mod_output$table))
  expect_disjoint("retractionwatch", names(mod_output$table))

  # chaining 1
  paper <- demopaper()
  mod_output <- paper |>
    module_run("ref_accuracy") |>
    module_run(module)
  expect_in("accuracy_mismatch", names(mod_output$table))
  expect_disjoint("retractionwatch", names(mod_output$table))
})

test_that("ref_pubpeer reports a failed PubPeer request instead of stopping (U23)", {
  # pubpeer_comments() gives NULL for an error answer; the join stopped on it
  local_mocked_bindings(pubpeer_comments = function(doi) NULL)
  mo <- module_run(demopaper(), "ref_pubpeer")
  expect_equal(mo$traffic_light, "fail")
  expect_match(mo$summary_text, "PubPeer could not be reached", fixed = TRUE)
})

test_that("ref_consistency reports a citation to a missing reference, and reads 'bib' xrefs (U115, U207)", {
  # a citation with a bib_id that is not in the bibliography was never
  # reported, and an older bibr export ("bib" xrefs) had no citations at all
  p <- demopaper()
  x <- p$xref[p$xref$xref_type == "bibr", ][1, ]
  x$xref_id <- 99L; x$contents <- "(Nobody, 1900)"
  p$xref <- rbind(p$xref, x)
  mo <- module_run(p, "ref_consistency")
  expect_equal(mo$summary_table$n_missing, 1)
  expect_true(99L %in% mo$table$bib_id)

  p2 <- demopaper()
  n_cited <- module_run(p2, "ref_consistency")$summary_table$n_xrefs
  p2$xref$xref_type[p2$xref$xref_type == "bibr"] <- "bib"
  expect_equal(module_run(p2, "ref_consistency")$summary_table$n_xrefs, n_cited)
})

test_that("ref_accuracy counts a reference with several bib_match rows once, and ignores footnote markers in titles (U114)", {
  # three joins multiplied duplicate bib_match rows (3 copies: 31 rows for 5
  # references); <sup> markers were compared as part of the title
  p <- demopaper()
  n <- nrow(module_run(p, "ref_accuracy")$table)
  p$bib_match <- rbind(p$bib_match, p$bib_match[1, ], p$bib_match[1, ])
  expect_equal(nrow(module_run(p, "ref_accuracy")$table), n)

  p <- demopaper()
  i <- match(p$bib_match$bib_id[1], p$bib$bib_id)
  before <- module_run(p, "ref_accuracy")$table
  p$bib$title[i] <- paste0(p$bib$title[i], "<sup>1</sup>")
  after <- module_run(p, "ref_accuracy")$table
  expect_equal(after$title_mismatch, before$title_mismatch)
})

test_that("ref_accuracy accepts a cited DOI written as a URL", {
  # a PLOS article URL around the matched DOI was flagged as a DOI mismatch
  p <- demopaper()
  i <- match(p$bib_match$bib_id[1], p$bib$bib_id)
  doi <- p$bib_match$doi[1]
  p$bib$doi[i] <- paste0("http://journals.plos.org/plosone/article?id=", doi)
  tbl <- module_run(p, "ref_accuracy")$table
  expect_false(tbl$doi_mismatch[tbl$bib_id == p$bib_match$bib_id[1]])
  p$bib$doi[i] <- paste0("https://doi.org/", toupper(doi))
  tbl <- module_run(p, "ref_accuracy")$table
  row <- tbl$bib_id == p$bib_match$bib_id[1]
  expect_false(tbl$doi_mismatch[row])
  expect_false(tbl$incoherent[row])

  # a genuinely different DOI is still flagged (the cited DOI could not be
  # looked up, so the record was found by a title search; a record found by
  # the cited DOI itself is an alias)
  p$bib$doi[i] <- "https://doi.org/10.1037/0003-066x.54.6.4 09"
  p$bib_match$score[1] <- 80
  tbl <- module_run(p, "ref_accuracy")$table
  expect_true(tbl$doi_mismatch[row])
  expect_true(tbl$incoherent[row])

  # an unresolved DOI written as a URL links to doi.org once
  p$bib_match <- p$bib_match[-1, ]
  p$bib$doi[i] <- paste0("https://doi.org/", doi)
  mo <- module_run(p, "ref_accuracy")
  expect_equal(mo$table$tier[mo$table$bib_id == p$bib$bib_id[i]], "unresolved")
  report <- paste(unlist(mo$report), collapse = "\n")
  expect_false(grepl("doi.org/https", report, fixed = TRUE))
  expect_match(report, paste0("https://doi.org/", doi), fixed = TRUE)
})

test_that("ref_accuracy discovers synthetic errors and ignores cosmetic differences", {
  # bib 1 (Eagly & Wood 1999) cites its own DOI and matches its record; each
  # case changes the citation or the record and runs the module on it
  base <- demopaper()
  i <- match(1, base$bib$bib_id)
  m <- match(1, base$bib_match$bib_id)
  run <- function(edit) {
    p <- edit(base)
    tbl <- module_run(p, "ref_accuracy")$table
    as.list(tbl[tbl$bib_id == 1, ])
  }
  expect_false(run(identity)$incoherent)

  # errors that should be discovered, with the field that shows them
  errors <- list(
    year = \(p) { p$bib$year[i] <- 2004L; p },
    container = \(p) { p$bib$container[i] <- "Journal of Experimental Social Psychology"; p },
    # the title as parsed and in the reference text, which the module also
    # searches for the record's title
    title = \(p) {
      new <- "Gender differences in moral judgement: A meta-analysis"
      j <- p$text$text_id == p$bib$text_id[i]
      p$text$text[j] <- sub(p$bib$title[i], new, p$text$text[j], fixed = TRUE)
      p$bib$title[i] <- new
      p
    },
    author = \(p) { p$bib$authors[i] <- "Smith, John; Wood, Wendy"; p },
    # a misspelled author, as in "Bernsten" for "Berntsen"
    author = \(p) { p$bib$authors[i] <- "Eagley, Alice H; Wood, Wendy"; p },
    # the DOI of another paper: its record disagrees with the citation
    title = \(p) {
      p$bib$doi[i] <- base$bib_match$doi[2]
      p$bib_match[m, setdiff(names(p$bib_match), "bib_id")] <-
        base$bib_match[2, setdiff(names(p$bib_match), "bib_id")]
      p
    },
    # a DOI that could not be looked up, so the record came from a title
    # search, and that points elsewhere
    doi = \(p) { p$bib$doi[i] <- "10.1037/0003-066x.54.6.4 09"; p$bib_match$score[m] <- 80; p },
    # a fabricated DOI that does not resolve
    unresolved = \(p) { p$bib$doi[i] <- "10.1037/0003-066x.99.9.999"; p$bib_match <- p$bib_match[-m, ]; p },
    # a changed compound surname shares only its last word with the record
    author = \(p) {
      p$bib_match$authors[[m]]$family[1] <- "Smith Jones"
      p$bib$authors[i] <- "Brown Jones, Alice H; Wood, Wendy"; p
    },
    # a surname is not found across the boundary to the given name
    author = \(p) { p$bib$authors[i] <- "Eag, Ly; Wood, Wendy"; p },
    author = \(p) {
      p$bib_match$authors[[m]]$family[1] <- "St. John"
      p$bib$authors[i] <- "Smith, John; Wood, Wendy"; p
    },
    # the record's title continues without a title delimiter
    title = \(p) {
      p$bib_match$title[m] <- "The Origins of Sex Differences in Human Behavior"
      new <- "The Origins of Sex Differences in Human Behaviorism and the Long-Term Effects of Hormone Therapy"
      j <- p$text$text_id == p$bib$text_id[i]
      p$text$text[j] <- sub(p$bib$title[i], new, p$text$text[j], fixed = TRUE)
      p$bib$title[i] <- new
      p
    },
    title = \(p) {
      p$bib_match$title[m] <- "The Origins of Sex Differences in Human Behavior"
      new <- "The Origins of Sex Differences in Human Behavior and the Long-Term Effects of Hormone Therapy"
      j <- p$text$text_id == p$bib$text_id[i]
      p$text$text[j] <- sub(p$bib$title[i], new, p$text$text[j], fixed = TRUE)
      p$bib$title[i] <- new
      p
    },
    # the record's title is found in the reference text only inside a word
    title = \(p) {
      p$bib_match$title[m] <- "Learning changes human behaviour"
      new <- "Unlearning changes human behaviour: A different account of animal cognition"
      j <- p$text$text_id == p$bib$text_id[i]
      p$text$text[j] <- sub(p$bib$title[i], new, p$text$text[j], fixed = TRUE)
      p$bib$title[i] <- new
      p
    },
    # a short record title that is found in the reference text as the journal
    title = \(p) { p$bib_match$title[m] <- "American Psychologist"; p },
    # a DOI written as a URL that was matched by a title search, before
    # add_bib_match() cleaned DOIs, to a work with another DOI
    doi = \(p) {
      p$bib$doi[i] <- "https://doi.org/10.1037/0003-066x.99.9.999"
      p$bib_match$score[m] <- 80; p
    },
    # a one-word journal name that a longer one starts with
    container = \(p) {
      p$bib_match$container[m] <- "Cognition and Emotion"
      p$bib$container[i] <- "Cognition"; p
    },
    # names without a comma ("Given Family") match on whole words only
    author = \(p) { p$bib$authors[i] <- "Alice H Eagly; John Blackwood"; p },
    author = \(p) {
      p$bib_match$authors[[m]]$family[1] <- "Smith Jones"
      p$bib$authors[i] <- "Alice Brown Jones; Wendy Wood"; p
    }
  )
  for (k in seq_along(errors)) {
    field <- names(errors)[k]
    r <- run(errors[[k]])
    expect_true(r$incoherent, label = paste("error", k, field))
    if (field == "unresolved") {
      expect_equal(r$tier, "unresolved")
    } else {
      expect_true(r[[paste0(field, "_mismatch")]], label = paste("error", k, field))
    }
  }

  # cosmetic differences that should not be flagged
  fine <- list(
    doi_url = \(p) { p$bib$doi[i] <- "https://doi.org/10.1037/0003-066X.54.6.408"; p },
    doi_double_slash = \(p) { p$bib$doi[i] <- "10.1037//0003-066x.54.6.408"; p },
    year_online_first = \(p) { p$bib$year[i] <- 2000L; p },
    journal_abbreviated = \(p) { p$bib$container[i] <- "Am. Psychol."; p },
    # the record has only the main title, and a line-break hyphen in the
    # reference text ("Dif- ferences") hides it there
    subtitle_not_in_record = \(p) {
      p$bib_match$title[m] <- "The Origins of Sex Differences in Human Behavior"
      j <- p$text$text_id == p$bib$text_id[i]
      p$text$text[j] <- sub("Differences", "Dif- ferences", p$text$text[j], fixed = TRUE)
      p
    },
    particle_spacing = \(p) {
      p$bib_match$authors[[m]]$family[1] <- "Le Eagly"
      p$bib$authors[i] <- "LeEagly, Alice H; Wood, Wendy"; p
    },
    nonbreaking_space = \(p) {
      p$bib_match$authors[[m]]$family[2] <- "de\u00a0Wood"
      p$bib$authors[i] <- "Eagly, Alice H; De Wood, Wendy"; p
    },
    given_name_in_family = \(p) { p$bib_match$authors[[m]]$family[1] <- "Alice Eagly"; p },
    comma_below = \(p) {
      p$bib_match$authors[[m]]$family[1] <- "\u021aurcanu"
      p$bib$authors[i] <- "Turcanu, Alice H; Wood, Wendy"; p
    },
    given_first = \(p) { p$bib$authors[i] <- "Alice H Eagly; Wendy Wood"; p },
    journal_subtitle = \(p) { p$bib_match$container[m] <- "American Psychologist: Official Journal"; p },
    journal_words_lost = \(p) { p$bib_match$container[m] <- "Journal of the American Psychologist"; p },
    # the record drops the particle the citation keeps
    particle_not_in_record = \(p) { p$bib$authors[i] <- "Eagly, Alice H; Van Wood, Wendy"; p },
    no_authors_read = \(p) { p$bib$authors[i] <- ""; p },
    # a line-break space in a DOI that was then matched by a title search
    doi_space_title_search = \(p) {
      p$bib$doi[i] <- "10.1037/0003-066x.54.6.4 08"; p$bib_match$score[m] <- 80; p
    },
    # a bib_match table without a score column
    no_score_column = \(p) { p$bib_match$score <- NULL; p },
    # an article number read as the journal
    article_number_as_journal = \(p) { p$bib$container[i] <- "Article e17018"; p },
    # a book chapter, whose registry container is a series or platform name
    chapter_container = \(p) {
      p$bib_match$bib_type[m] <- "incollection"
      p$bib_match$container[m] <- "Oxford Handbooks Online"; p
    }
  )
  for (k in names(fine)) {
    expect_false(run(fine[[k]])$incoherent, label = k)
  }

  # a cited DOI that the registry lists as an alias of the record's DOI is a
  # note, not an incoherence
  r <- run(\(p) { p$bib_match$doi[m] <- "10.1037/alias-of-the-cited"; p })
  expect_true(r$doi_alias)
  expect_false(r$incoherent)
})

test_that("ref_accuracy counts references without a DOI and suggests a DOI for confident matches (#528)", {
  # a reference with no printed DOI that CrossRef matched by title search was
  # counted neither as checked nor as without a DOI, and no DOI was suggested
  p <- demopaper()
  k <- match(3, p$bib_match$bib_id)   # bib 3 printed no DOI; CrossRef found one
  p$bib_match$score[k] <- 85
  mo <- module_run(p, "ref_accuracy")
  tbl <- mo$table
  expect_equal(tbl$tier[tbl$bib_id == 3], "crossref")
  expect_true(tbl$no_doi[tbl$bib_id == 3])
  expect_true(tbl$doi_suggested[tbl$bib_id == 3])
  expect_equal(mo$summary_table$no_doi, sum(tbl$tier %in% c("crossref", "none")))
  expect_equal(mo$summary_table$doi_suggested, 1)
  expect_equal(mo$summary_table$refs_checked + mo$summary_table$no_doi, nrow(tbl))
  report <- paste(unlist(mo$report), collapse = "\n")
  expect_match(report, paste0("https://doi.org/", p$bib_match$doi[k]), fixed = TRUE)

  # a low-scoring match is counted but not suggested
  p$bib_match$score[k] <- 40
  mo <- module_run(p, "ref_accuracy")
  expect_true(mo$table$no_doi[mo$table$bib_id == 3])
  expect_equal(mo$summary_table$doi_suggested, 0)

  # nothing to check when no reference supplied a DOI
  p$bib$doi <- ""
  expect_equal(module_run(p, "ref_accuracy")$traffic_light, "na")
})

test_that("ref_pubpeer counts a DOI cited three times once, and runs without url fields (U118)", {
  # 3 citations x 3 lookups gave 9 rows ("You cited 9 references", 18
  # comments); without a url the module stopped
  p <- test_paper("x")
  local_mocked_bindings(
    ref_table = function(paper) data.frame(paper_id = paper$paper_id, bib_id = 1:3,
                                           doi = "10.1/x", text = c("A", "A2", "A3")),
    pubpeer_comments = function(doi) data.frame(doi = doi, total_comments = 2, users = "someone"))
  mo <- module_run(p, "ref_pubpeer")
  expect_match(mo$summary_text, "You cited 1 reference", fixed = TRUE)
  expect_equal(mo$summary_table$pubpeer_comments, 2)
})

test_that("ref_retraction compares DOIs without case (U157)", {
  # a lower-case citation of a RetractionWatch DOI with capitals was missed
  p <- test_paper("x")
  local_mocked_bindings(ref_table = function(paper)
    data.frame(paper_id = paper$paper_id, bib_id = 1, doi = "10.1016/s0140-6736(97)11096-0",
               text = "Wakefield"))
  mo <- module_run(p, "ref_retraction")
  expect_equal(mo$table$doi, "10.1016/s0140-6736(97)11096-0")
  expect_match(mo$table$retractionwatch, "Retraction", fixed = TRUE)
})

test_that("ref_miscitation matches DOIs without case, and a missing DOI matches nothing (U117, U157)", {
  paper <- demopaper()
  test_doi <- "10.1037/0003-066x.54.6.408"
  db <- data.frame(doi = c(toupper(test_doi), NA), reftext = c("Ref", "None"),
                   warning = c("Warn", "No DOI"))
  mo <- module_run(paper, "ref_miscitation", db = db)
  expect_equal(unique(mo$table$doi), test_doi)
  expect_false("No DOI" %in% mo$table$warning)
})

test_that("ref_replication drops a citation of the original only when the same paper cites the replication (U116)", {
  # paper B citing a replication hid paper A's citation of the original
  fl <- FLoRA()
  row <- fl[!is.na(fl$doi_r) & nzchar(fl$doi_r) & !is.na(fl$doi_o) & nzchar(fl$doi_o), ][1, ]
  pa <- test_paper("x"); pa$paper_id <- "A"
  pb <- test_paper("y"); pb$paper_id <- "B"
  local_mocked_bindings(ref_table = function(paper)
    data.frame(paper_id = c("A", "B"), bib_id = 1L, doi = c(row$doi_o, row$doi_r),
               text = c("original", "replication")))
  mo <- module_run(paperlist(pa, pb), "ref_replication")
  # the replication paper B cites is still listed for paper A
  expect_true(tolower(row$doi_r) %in% tolower(mo$table$replication_doi[mo$table$paper_id == "A"]))
})

test_that("ref_summary labels unmatched references and keeps one row per reference (U119)", {
  # no_match with every *_mismatch FALSE gave NA; two replications repeated
  # the reference
  p <- demopaper()
  pid <- p$paper_id; b <- unique(ref_table(p)$bib_id)
  acc <- data.frame(paper_id = pid, bib_id = b[1:2], no_match = c(TRUE, FALSE),
                    title_mismatch = c(FALSE, TRUE), doi_mismatch = FALSE)
  rep_tbl <- data.frame(paper_id = pid, bib_id = b[3], replication_type = c("direct", "conceptual"))
  fake <- structure(list(module = "ref_replication", table = rep_tbl, paper = p,
                         summary_table = data.frame(paper_id = pid),
                         prev_outputs = list(ref_accuracy = list(table = acc))),
                    class = "metacheck_module_output")
  mo <- module_run(fake, "ref_summary")
  expect_equal(nrow(mo$table), length(b))
  expect_equal(mo$table$accuracy_mismatch[mo$table$bib_id == b[1]], "no match")
})

test_that("ref_accuracy reads bibr 12.x author lists and article types", {
  # bibr 12.x keeps the author list as printed ("Adam, H., Shirako, A., &
  # Maddux, W. W") and calls a journal article "journal_article"
  p <- read(test_path("fixtures", "bibr12", "preprint.json"))
  mo <- module_run(p, "ref_accuracy")
  tbl <- mo$table[mo$table$tier == "provided", ]
  expect_true(any(tbl$bib_type.match == "journal_article"))
  expect_lt(sum(tbl$author_mismatch), 3)

  k <- which(p$bib$bib_id == tbl$bib_id[!tbl$incoherent][1])
  q <- p
  q$bib$container[k] <- "A Completely Different Journal Name"
  r <- module_run(q, "ref_accuracy")$table
  expect_true(r$container_mismatch[r$bib_id == p$bib$bib_id[k]])
  q <- p
  q$bib$authors[k] <- "Nobody, A., & Else, B"
  r <- module_run(q, "ref_accuracy")$table
  expect_true(r$author_mismatch[r$bib_id == p$bib$bib_id[k]])
})

test_that("ref_accuracy only compares references that printed a DOI and were looked up", {
  # a reference without a DOI is not compared, so ref_summary shows no
  # mismatch for it
  p <- demopaper()
  k <- match(3, p$bib_match$bib_id)
  p$bib_match$year[k] <- 1900L
  tbl <- module_run(p, "ref_accuracy")$table
  expect_equal(tbl$tier[tbl$bib_id == 3], "crossref")
  expect_false(tbl$year_mismatch[tbl$bib_id == 3])

  # a match without a DOI is not suggested, nor counted as suggested
  p$bib_match$score[k] <- 90
  p$bib_match$doi[k] <- NA_character_
  mo <- module_run(p, "ref_accuracy")
  expect_equal(mo$summary_table$doi_suggested, 0)

  # in a paper list, a paper that was not looked up has no DOIs that "could
  # not be found"
  a <- demopaper()
  b <- demopaper()
  b$paper_id <- "nolookup"
  b$bib_match <- b$bib_match[0, ]
  mo <- module_run(paperlist(a, b), "ref_accuracy")
  st <- mo$summary_table[mo$summary_table$paper_id == "nolookup", ]
  expect_equal(st$refs_checked, 0)
  expect_equal(st$incoherent, 0)
  expect_true(all(mo$table$tier[mo$table$paper_id == "nolookup"] %in%
                    c("not_checked", "none")))
  expect_match(mo$summary_text, "not looked up at Crossref")
})
