test_that("coi_check: a short heading as the last sentence, and no pasted NA (U97)", {
  # nchar(NA) as the condition stopped the module, and a read past the end
  # pasted "NA" into the statement
  llm_use(FALSE)
  mo <- suppressMessages(module_run(test_paper(text = "Conflict of interest"), "coi_check"))
  expect_equal(mo$table$text, "Conflict of interest")
  mo <- suppressMessages(module_run(
    test_paper(text = c("Conflict of interest", "The authors declare none")), "coi_check"))
  expect_false(grepl("NA", mo$table$text, fixed = TRUE))
})

test_that("coi_check keeps 'Nil.' and 'nothing to declare' statements (U95)", {
  # the clean-up kept only 4 of its 11 groups, so these became "" (red light)
  for (s in c("Conflict of interest: Nil. We thank our colleagues.",
              "Conflict of interest statement: The authors have nothing to declare. We thank our colleagues.")) {
    mo <- module_run(test_paper(s), "coi_check")
    expect_equal(mo$traffic_light, "green")
    expect_false(grepl("We thank", mo$table$text))
  }
})
