# causal_claims, with its web classifier (causal_relations()) replaced

fake_causal <- function(sentence, ...) {
  sentence <- sentence[!is.na(sentence)]
  data.frame(sentence = sentence, causal = grepl("causes", sentence),
             cause = rep(NA_character_, length(sentence)),
             effect = rep(NA_character_, length(sentence)))
}

test_that("causal_claims checks every title, and a missing title does not stop it (U84)", {
  # a paper whose title was NA stopped the module; a paper list's titles were
  # never checked (a list has no $info)
  local_mocked_bindings(causal_relations = fake_causal)
  p1 <- test_paper(text = "We studied mood."); p1$info$title <- NA_character_
  p1$paper_id <- p1$info$paper_id <- "p1"
  expect_no_error(mo <- suppressMessages(module_run(p1, "causal_claims")))
  p2 <- test_paper(text = "We studied mood."); p2$info$title <- "Coffee causes happiness"
  p2$paper_id <- p2$info$paper_id <- "p2"
  mo <- suppressMessages(module_run(paperlist(p1, p2), "causal_claims"))
  expect_match(mo$summary_text, "Causal claims were detected in the title", fixed = TRUE)
})

test_that("causal_relations of a missing sentence returns no rows, without a request (U84)", {
  # all(trimws(NA) == "") is NA, which stopped the function
  expect_equal(nrow(causal_relations(NA_character_)), 0)
})

test_that("causal_claims finds 'randomised', skips negations, and keeps assignment next to random effects (U85)", {
  s <- c("Participants were randomised to two groups.",
         "The study was not randomized.",
         "Participants were randomly assigned to conditions, and the model had random intercepts.",
         "We used random effects for items.")
  mo <- module_run(test_paper(s), "causal_claims")
  r <- paste(mo$report, collapse = "\n")
  expect_match(r, "randomised to two groups", fixed = TRUE)
  expect_match(r, "randomly assigned to conditions", fixed = TRUE)
  expect_false(grepl("not randomized", r, fixed = TRUE))
  expect_false(grepl("random effects for items", r, fixed = TRUE))
})
