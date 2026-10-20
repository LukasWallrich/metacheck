test_that("funding_check with two funding title lines (U103)", {
  # the if() on a vector of title lines stopped the module for the whole list
  llm_use(FALSE)
  txt <- c("Funding", "This work was supported by NWO grant 123.", "Funding:", "None.")
  mo <- suppressMessages(module_run(test_paper(text = txt), "funding_check"))
  expect_match(mo$table$text, "supported by NWO grant 123", fixed = TRUE)
  expect_false(grepl("NA", mo$table$text, fixed = TRUE))
})
