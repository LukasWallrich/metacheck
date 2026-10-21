
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

test_that("an SPSS box plot from case data decodes (U144)", {
  # abs() ran on the character category column and stopped the decoder
  x_node <- xml2::read_xml(paste0('<sourceVariable><relabel from="1" to="Group A"/>',
                                  '<relabel from="2" to="Group B"/></sourceVariable>'))
  testthat::local_mocked_bindings(.spvviz_resolve_variable = function(root, ref, data) {
    if (identical(ref, "x")) list(values = list(list(d = 1), list(d = 2), list(d = 2)))
    else list(values = list(list(d = 3.5), list(d = .Machine$double.xmax), list(d = 4.1)))
  })
  out <- .spvviz_decode_boxplot_databin(NULL, "x", "y", x_node, NULL, NULL)
  expect_equal(out, data.frame(category = c("Group A", "Group B"), value = c(3.5, 4.1)))
})
