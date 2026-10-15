test_that("no function or object is defined twice in R/ (#482)", {
  # Without a Collate field R loads R/ alphabetically, so a second definition
  # of a name silently replaces the first: an edit to the unused copy has no
  # effect, and the two copies drift apart. Eleven helpers and one constant
  # were defined twice before #482.
  r_dir <- testthat::test_path("..", "..", "R")
  skip_if_not(dir.exists(r_dir), "package source (R/) not available")

  name_of <- character(0); file_of <- character(0)
  for (f in sort(list.files(r_dir, pattern = "[.]R$", full.names = TRUE))) {
    for (x in parse(f, keep.source = FALSE, encoding = "UTF-8")) {
      if (is.call(x) && (identical(x[[1]], as.name("<-")) || identical(x[[1]], as.name("="))) &&
          is.name(x[[2]])) {
        name_of <- c(name_of, as.character(x[[2]]))
        file_of <- c(file_of, basename(f))
      }
    }
  }
  dup <- unique(name_of[duplicated(name_of)])
  where <- vapply(dup, function(d) paste0(d, " (", paste(file_of[name_of == d], collapse = ", "), ")"),
                  character(1))
  expect(length(dup) == 0,
         paste("Defined more than once:", paste(where, collapse = "; ")))
})
