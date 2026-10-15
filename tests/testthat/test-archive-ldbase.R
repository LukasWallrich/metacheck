test_that("ldbase_links finds item links, bare-text links and DOIs", {
  expect_true(is.function(metacheck::ldbase_links))

  paper <- test_paper(
    text = paste("Data are on LDbase (https://ldbase.org/projects/55d2face-9550-48e2-990f-c04bfe6dded5)",
                 "and at doi:10.33009/ldbase.1627053448.d151."),
    url = "https://ldbase.org/datasets/e54f6aad-e0e2-4b40-9017-d4e347d9a497/")
  links <- ldbase_links(paper)
  expect_setequal(links$ldbase_url, c(
    "https://ldbase.org/datasets/e54f6aad-e0e2-4b40-9017-d4e347d9a497",
    "https://ldbase.org/projects/55d2face-9550-48e2-990f-c04bfe6dded5",
    "10.33009/ldbase.1627053448.d151"))
  expect_setequal(links$ldbase_type, c("datasets", "projects", "doi"))
})

test_that("ldbase_links ignores LDbase's own DOI and its home page", {
  paper <- test_paper(text = "We thank LDbase (10.33009/ldbase).",
                      url = c("https://ldbase.org/", "https://ldbase.org/browse-data"))
  expect_equal(nrow(ldbase_links(paper)), 0)
})

test_that(".ldbase_type and .ldbase_page_url read every link form", {
  urls <- c("https://ldbase.org/projects/55d2face-9550-48e2-990f-c04bfe6dded5",
            "http://ldbase.org:443/code/642b77cc-6e5c-4631-88e8-3bad7253cd12/",
            "ldbase.org/documents/99033578-33fc-4882-b7d1-a03d38a23486",
            "https://doi.org/10.33009/ldbase.1627053448.d151",
            "https://osf.io/abcde", NA_character_)
  expect_equal(.ldbase_type(urls),
               c("projects", "code", "documents", "doi", NA, NA))
  expect_equal(.ldbase_page_url(urls[2]),
               "https://ldbase.org/code/642b77cc-6e5c-4631-88e8-3bad7253cd12")
  expect_true(is.na(.ldbase_page_url(urls[4])))
  expect_equal(.ldbase_type(character(0)), character(0))
})

# Hand-made pages with the structure of LDbase's own (checked 2026-10-15).
ldbase_project_html <- function() {
  xml2::read_html(paste0(
    "<html><head><script type='application/ld+json'>",
    '[{"@type":"BreadcrumbList","itemListElement":[]},',
    '{"@type":"DataCatalog","name":"LAMP Project"}]',
    "</script></head><body><h1>Project: LAMP Project</h1>",
    "<div class='field field--name-field-doi'><a href='https://doi.org/10.33009/ldbase.1790013418.b8ca'>doi</a></div>",
    # 'Most recent' block: not used, the tree is
    "<a href='/datasets/00000000-0000-0000-0000-000000000009'>recent</a>",
    "<ul id='project-tree-view-list-root'>",
    "<li class='project-tree-view project-tree-view-item-current'><a href='/projects/55d2face-9550-48e2-990f-c04bfe6dded5'>Project: LAMP Project</a>",
    "<ul><li><a href='/datasets/ef328591-e249-4803-b673-76f237717d1d'>Dataset: Set 1</a></li>",
    "<li><a href='/code/642b77cc-6e5c-4631-88e8-3bad7253cd12'>Code: prep</a></li>",
    "<li><a href='/projects/11111111-2222-3333-4444-555555555555'>Project: child</a>",
    "<ul><li><a href='/documents/99033578-33fc-4882-b7d1-a03d38a23486'>Document: folder</a></li></ul></li>",
    "</ul></li></ul></body></html>"))
}

ldbase_dataset_html <- function() {
  xml2::read_html(paste0(
    "<html><head><script type='application/ld+json'>",
    '[{"@type":"BreadcrumbList","itemListElement":[]},',
    '{"@type":"Dataset","name":"LAMP Set 1 Analytic Dataset",',
    '"license":"Open Data Commons Attribution License (ODC-By)"}]',
    "</script></head><body>",
    "<div class='field field--name-field-file-upload field--type-file'>",
    "<a href='/system/files/datasets/2026-09/set%201.csv'>set 1.csv</a></div>",
    "<div class='views-element-container'><a href='/system/files/datasets/2025-01/old.csv'>v1</a></div>",
    "</body></html>"))
}

test_that(".ldbase_project_items lists the whole hierarchy tree, child projects included", {
  items <- .ldbase_project_items(ldbase_project_html())
  expect_setequal(items, c(
    "https://ldbase.org/datasets/ef328591-e249-4803-b673-76f237717d1d",
    "https://ldbase.org/code/642b77cc-6e5c-4631-88e8-3bad7253cd12",
    "https://ldbase.org/documents/99033578-33fc-4882-b7d1-a03d38a23486"))
})

test_that(".ldbase_page_meta reads the title, DOI and licence", {
  meta <- .ldbase_page_meta(ldbase_project_html())
  expect_equal(meta$title, "LAMP Project")
  expect_equal(meta$doi, "10.33009/ldbase.1790013418.b8ca")
  expect_true(is.na(meta$license))
  expect_equal(.ldbase_page_meta(ldbase_dataset_html())$license,
               "Open Data Commons Attribution License (ODC-By)")
})

test_that(".ldbase_item_files takes only the current file of an item", {
  item <- "https://ldbase.org/datasets/ef328591-e249-4803-b673-76f237717d1d"
  f <- .ldbase_item_files(ldbase_dataset_html(), item)
  expect_equal(nrow(f), 1)
  expect_equal(f$file_name, "set 1.csv")
  expect_equal(f$file_url, "https://ldbase.org/system/files/datasets/2026-09/set%201.csv")
  expect_equal(f$item_type, "datasets")

  external <- xml2::read_html("<html><body><p>Stored elsewhere</p></body></html>")
  expect_equal(nrow(.ldbase_item_files(external, item)), 0)
})

test_that("ldbase_info lists a real project and dataset", {
  skip_if_quick()
  skip_if_offline("ldbase.org")
  info <- ldbase_info(c(
    "https://ldbase.org/datasets/e54f6aad-e0e2-4b40-9017-d4e347d9a497",
    "10.33009/ldbase.1627053448.d151"))
  expect_true(all(is.na(info$error)))
  expect_equal(info$ldbase_type, c("datasets", "projects"))
  expect_equal(info$files[[1]]$file_name, "read_theta.csv")
  expect_match(info$license[1], "ODC-By")
  expect_true("read_theta.csv" %in% basename(info$files[[2]]$file_path))
})

test_that("repo_check lists the files of an LDbase project", {
  skip_if_quick()
  skip_if_offline("ldbase.org")
  paper <- test_paper(text = "Data: https://ldbase.org/projects/09609d82-c45f-4442-8c0c-d136191bdc50")
  mo <- module_run(paper, "repo_check", peek_zips = FALSE)
  expect_true("read_theta.csv" %in% mo$table$file_name)
  expect_match(mo$table$repo_url[mo$table$file_name == "read_theta.csv"], "ldbase\\.org")
})

test_that(".waf_challenge_check recognises a firewall browser check and warns once per host", {
  rm(list = ls(.waf_challenge_warned), envir = .waf_challenge_warned)
  challenge <- httr2::response(status_code = 202, url = "https://ldbase.org/system/files/x.csv",
                               headers = list(`x-amzn-waf-action` = "challenge"))
  expect_warning(expect_true(.waf_challenge_check(challenge, challenge$url)),
                 "firewall answered with a browser check")
  expect_no_warning(expect_true(.waf_challenge_check(challenge, challenge$url)))
  ok <- httr2::response(status_code = 206, url = "https://ldbase.org/system/files/x.csv")
  expect_false(.waf_challenge_check(ok, ok$url))
  rm(list = ls(.waf_challenge_warned), envir = .waf_challenge_warned)
})
