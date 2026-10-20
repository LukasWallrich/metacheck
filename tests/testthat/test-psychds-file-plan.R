test_that("psychds_file_plan takes a missing name from the path and excludes a file with neither (U113)", {
  # a missing name became the target "unknown/NA"; no file_name column stopped
  s <- data.frame(paper_id = "p", file_name = c("data.csv", NA, NA),
                  file_path = c("data/data.csv", "code/analysis.R", NA),
                  file_type = c("data", "code", "data"), data_type = NA)
  plan <- psychds_file_plan(s, FALSE)$table
  expect_equal(plan$file_name[2], "analysis.R")
  expect_equal(plan$status[3], "excluded")
  s$file_name <- NULL
  expect_equal(nrow(psychds_file_plan(s, FALSE)$table), 3)
})
