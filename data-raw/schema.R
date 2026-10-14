# The bundled schema describes bibr 10.5. Since 2026-10-13
# (scienceverse/schema#2), https://scienceverse.org/schema/paper.json holds
# bibr's 12.2 export schema, and the 10.5 schema is kept at paper-v10.5.json,
# which is what metacheck bundles. Downloading paper.json here would silently
# replace it with the 12.2 schema.
#
# NOTE: the bundled copy also drops "schema_version" from $defs.info.required,
# so that papers from pre-10.5 bibr (which do not write it) still validate
# (see test-paper.R). A fresh download restores it; remove it again by hand.
if (online("scienceverse.org")) {
  url <- "https://scienceverse.org/schema/paper-v10.5.json"
  destfile <- "inst/schema/paper.json"

  int_hash <- tools::md5sum(destfile)
  download.file(url, destfile, quiet = TRUE)
  ext_hash <- tools::md5sum(destfile)

  if (ext_hash != int_hash) message("schema/paper.json changed")
}
