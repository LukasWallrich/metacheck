test_that(".file_tree_rows", {
  rows <- .file_tree_rows(c("data/raw.csv", "README.md", "data/clean.csv", NA, ""))
  # folders first, then files, each alphabetically
  expect_equal(rows$text, c("├── data/", "│   ├── clean.csv", "│   └── raw.csv",
                            "└── README.md"))
  # each file row points back at its input path; a folder row has none
  expect_equal(rows$leaf_idx, c(NA, 3L, 1L, 2L))

  empty <- .file_tree_rows(character(0))
  expect_equal(nrow(empty), 0)
  expect_equal(names(empty), c("text", "leaf_idx"))
})

test_that(".file_tree_block", {
  files <- data.frame(
    repo_url = "my_study",
    file_name = c("raw.csv", "README.md", "analysis.R"),
    file_path = c("data/raw.csv", "README.md", "code/analysis.R"),
    data_type = c("data", "documentation", "code"),
    doc_role = c(NA, "readme", NA)
  )
  naming <- data.frame(file_name = "raw.csv", detail = "no date")
  block <- .file_tree_block(files, naming)

  expect_equal(block[[1]], "#### Data Tree")
  expect_match(block[[2]], "and any file-naming issue found by repo_check", fixed = TRUE)
  expect_equal(block[[3]], "**Repository: my_study**")
  tree <- block[[4]]
  expect_match(tree, "^```\n")
  expect_match(tree, "data/", fixed = TRUE)
  expect_match(tree, "raw.csv\\s+\U0001F4CA data\\s+no date")
  expect_match(tree, "README.md\\s+\U0001F4C4 readme")

  expect_null(.file_tree_block(NULL))
  expect_null(.file_tree_block(files[0, ]))
  expect_null(.file_tree_block(data.frame(file_name = "a.csv")))
})

test_that(".file_tree_from_report and .file_tree", {
  report <- c("Intro", "#### Data Tree", "legend", "tree", "#### Data Files", "x")
  expect_equal(.file_tree_from_report(report), c("legend", "tree"))
  expect_null(.file_tree_from_report(c("Intro", "#### Data Files")))
  expect_null(.file_tree_from_report(NULL))

  # data_check's tree first
  mo <- list(data_check = list(report = report))
  expect_equal(.file_tree(mo), c("legend", "tree"))

  # else one drawn from repo_check's files, without its heading
  files <- data.frame(repo_url = "my_study", file_name = "raw.csv",
                      file_path = "data/raw.csv", data_type = "data")
  mo <- list(data_check = list(report = "nothing"), repo_check = list(table = files))
  tree <- .file_tree(mo)
  expect_false("#### Data Tree" %in% tree)
  expect_equal(tree[[2]], "**Repository: my_study**")

  expect_null(.file_tree(list()))
})
