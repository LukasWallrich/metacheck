url <- "https://raw.githubusercontent.com/dyne/file-extension-list/refs/heads/master/pub/extensions.json"

jtypes <- jsonlite::read_json(url, simplifyVector = TRUE)
types <- dplyr::tibble(
  ext = names(jtypes),
  type = I(jtypes)
) |> tidyr::unnest_longer(type)

types$type[types$type == "sheet"] <- "data"

extensions <- list()
extensions[["code"]] <- data.frame(
  # "Rds" was listed here as well as under "data" below; lowercased, both are
  # "rds" (R's saved-object format, which is data), so it is listed there only.
  ext = c("R", "Rmd", "qmd", "quarto",
          "Rd",
          "ado","dss",
          "Rnw", "jl", "ipynb",
          "ts", "dart", "sol", "vue", "svelte", "gradle")
)
extensions[["config"]] <- data.frame(
  ext = c("gitignore", "git", "yml", "yaml", "config", "Rproj",
          "make", "mk", "cmake", "lock", "env", "toml", "ini", "cfg",
          "bak", "tmp", "old", "orig", "swp")
)
extensions[["data"]] <- data.frame(
  ext = c("rds", "RData", "rda", "sav", "zsav", "por",
          "dta", "sas7bdat", "xpt", "sd7", "jasp",
          "omv", "arff", "sav.gz", "csv.sav", "gen",
          "gdt", "gdtb", "dft", "wf1",
          "dat", "json", "tsv", "csv",
          "parquet", "feather", "orc", "ndjson", "geojson",
          # MATLAB binary array/workspace file. Not source code (MATLAB
          # scripts are .m); it holds saved variables, so it belongs with the
          # other scientific data containers below.
          "mat",
          # Genomic sequence formats, gzip-compressed (the common convention
          # for these, since sequence files compress well). A bare
          # tools::file_ext() lookup (used by .ext_registry's data_type
          # lock) only ever sees "gz" for a compound name like
          # "sample.fasta.gz", which is itself classified "archive" -- these
          # compound extensions are matched directly against the whole
          # filename instead (see file_category()'s own per-extension regex
          # scan), so a real sequence file is not misread as a generic
          # archive. Confirmed against real corpus files that were falling
          # through to "unknown" (data_availability validation).
          "fasta.gz", "fa.gz", "fq.gz", "fastq.gz")
)
extensions[["archive"]] <- data.frame(
  ext = c("z", "lzop", "sz")
)
extensions[["audio"]] <- data.frame(
  ext = c("amr", "aif", "mka")
)
extensions[["image"]] <- data.frame(
  ext = c("ico", "raw", "nef", "cr2", "cr3", "arw", "psb", "jp2")
)
extensions[["video"]] <- data.frame(
  ext = c("hevc")
)
extensions[["text"]] <- data.frame(
  ext = c("odg", "odf", "rtx", "abw")
)
extensions[["font"]] <- data.frame(
  ext = c("pfb", "pfm")
)
extensions[["stats"]] <- data.frame(
  ext = c( "sas", "por", "jasp", "sps", "spss", "DO", "spv", "spo")
)

for (nm in names(extensions)) {
  extensions[[nm]]$type <- nm
}


file_types <- do.call(dplyr::bind_rows, c(list(types), extensions))
file_types$ext <- tolower(file_types$ext)

# One type per extension. The community list and the lists above disagreed on
# 27 extensions, which then had two rows each: every left_join(..., file_types,
# by = "ext") (GitHub, GitLab, DSpace, PsychArchives and ResearchBox listings)
# duplicated those files' rows, and file_category() saw a type such as
# "code;data", which none of its firm rules match. Each gets the type that fits
# how it occurs in a research repository (decided 2026-10-13):
#   - data, not code/stats: saved data (jsPsych/JSON exports, R objects, SPSS
#     portable files, JASP files, which bundle the dataset with its analyses)
#   - code, not exec/web: shell scripts and program source (experiments
#     written in JavaScript, server scripts)
#   - web, not code: html/htm are usually a rendered report or output page
#   - 3ds/yuv: two media types that both count as materials; one is kept
type_override <- c(
  json = "data", rds = "data", por = "data", jasp = "data",
  sh = "code", bash = "code", zsh = "code", ksh = "code", csh = "code",
  fish = "code", bat = "code",
  js = "code", jsx = "code", ts = "code", tsx = "code", php = "code",
  php3 = "code",
  php4 = "code", php5 = "code", phtml = "code", asp = "code", aspx = "code",
  jsp = "code", inc = "code",
  html = "web", htm = "web",
  `3ds` = "3D", yuv = "video"
)
over <- file_types$ext %in% names(type_override)
file_types$type[over] <- unname(type_override[file_types$ext[over]])

file_types <- unique(file_types) |>
  dplyr::arrange(ext)
stopifnot(!anyDuplicated(file_types$ext))

usethis::use_data(file_types, overwrite = TRUE, compress = "xz")
usethis::use_r("file_types")



