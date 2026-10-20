
test_that("SPSS/jamovi HTML export: trailing empty labels, odd image paths, repeated images (U148)", {
  # strsplit() dropped a trailing empty label, which stopped export_spv_html()
  expect_equal(.spv_split_levels(c("a␟", "a␟b")), list(c("a", ""), c("a", "b")))
  # a malformed %-escape stopped the image inliner; only the first occurrence
  # of an image was embedded
  root <- withr::local_tempdir()
  writeBin(as.raw(c(0x89, 0x50, 0x4e, 0x47)), file.path(root, "plot.png"))
  html <- '<img src="plot.png"><img src="plot.png"><img src="bad%zz.png">'
  out <- .html_inline_images(html, root)
  expect_equal(lengths(regmatches(out, gregexpr("data:image/png", out))), 2)
  expect_match(out, 'src="bad%zz.png"', fixed = TRUE)
})
