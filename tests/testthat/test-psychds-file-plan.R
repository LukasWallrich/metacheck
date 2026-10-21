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

test_that("psychds_file_plan leaves correctly placed files and valid data names alone (U112)", {
  # data/eeg.npy was told to move to itself, and study-a_data.csv was renamed
  # data/study-studyadata_data.csv
  s <- data.frame(file_name = c("data/eeg.npy", "data/study-a_data.csv", "raw.csv"),
                  file_path = c("data/eeg.npy", "data/study-a_data.csv", "raw.csv"),
                  data_type = "data", group = NA_character_)
  tb <- psychds_file_plan(s)$table
  expect_equal(tb$status, c("present", "present", "move"))
  expect_equal(tb$target_path[2], "data/study-a_data.csv")
})
