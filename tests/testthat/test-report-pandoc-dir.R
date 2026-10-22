# .report_pandoc_dir(): the Pandoc Quarto bundles, which the checklist and
# simple reports render with. Quarto keeps it in bin/tools/ on Windows and
# macOS, and in bin/tools/<arch>/ on Linux.
fake_quarto <- function(pandoc_sub) {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  bin <- file.path(root, "bin")
  dir.create(file.path(bin, "tools", pandoc_sub), recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(bin, "quarto"))
  if (!is.na(pandoc_sub)) file.create(file.path(bin, "tools", pandoc_sub, "pandoc"))
  file.path(bin, "quarto")
}

test_that(".report_pandoc_dir finds Pandoc in bin/tools/ (Windows, macOS)", {
  q <- fake_quarto("")
  local_mocked_bindings(quarto_path = function(...) q, .package = "quarto")
  expect_equal(normalizePath(.report_pandoc_dir()), normalizePath(file.path(dirname(q), "tools")))
})

test_that(".report_pandoc_dir finds Pandoc in bin/tools/<arch>/ (Linux)", {
  for (arch in c("x86_64", "aarch64")) {
    q <- fake_quarto(arch)
    local_mocked_bindings(quarto_path = function(...) q, .package = "quarto")
    expect_equal(normalizePath(.report_pandoc_dir()),
                 normalizePath(file.path(dirname(q), "tools", arch)))
  }
})

test_that(".report_pandoc_dir returns NULL without Quarto or without its Pandoc", {
  local_mocked_bindings(quarto_path = function(...) NULL, .package = "quarto")
  expect_null(.report_pandoc_dir())
  q <- fake_quarto("x86_64")
  unlink(file.path(dirname(q), "tools", "x86_64", "pandoc"))
  local_mocked_bindings(quarto_path = function(...) q, .package = "quarto")
  expect_null(.report_pandoc_dir())
})
