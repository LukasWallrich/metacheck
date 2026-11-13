#' Reference Accuracy
#'
#' @description
#' This module compares the details each reference cites with the record for its DOI and flags references whose details disagree. For a reference without a DOI, it looks for a work with the same title, and suggests its DOI or flags the reference when the work's authors, journal or year differ.
#'
#' @details
#' A flagged reference is *incoherent*: its cited details disagree with the record. This may be an error in reading the reference list from the PDF, a citation mistake, or an AI-generated reference, so check the original source.
#'
#' The module uses the `bib_match` table, which holds the metadata retrieved from CrossRef for each reference (added or refreshed with `add_bib_match()`, which makes live network calls). The module itself also makes network calls: to doi.org for cited DOIs without a record, and to CrossRef, DataCite and Semantic Scholar for title searches of references without a DOI. Semantic Scholar is asked only about titles the registries do not hold, about one a second (a key in the environment variable `SEMANTIC_SCHOLAR_API_KEY` is used when set), so that a paper with many such references takes a minute or more.
#'
#' For a reference with a DOI, the module compares the cited details field by field with the record found for that DOI. `add_bib_match()` looks up a cited DOI directly when it is valid after `doi_clean()`, which removes a doi.org or journal URL around it and the spaces, punctuation and brackets that reading the PDF adds; a DOI that is still not valid is matched by a title search instead. A DOI printed in the reference text that the PDF reader did not take as the reference's DOI (a link with "%2F" for "/", or a malformed DOI such as "doi.org/1073191116659134") counts as the cited DOI when it is the DOI the title search found, apart from lost punctuation or prefix; a malformed one is then a DOI mismatch. For a cited DOI with no record, the module asks doi.org whether it exists. A DOI that does not exist is flagged. A registered DOI, or one doi.org could not be asked about, is listed as not checked: its record is missing because a lookup failed, or because its agency's records are not looked up (DataCite, mEDRA). References in papers that were not looked up at all are not checked. References without a DOI are listed separately, with a recommendation to add a DOI where one exists. Their record comes from a CrossRef title search, which can return the wrong work, so a reference is compared only with a record whose title agrees with the cited title. The match must be confident (a score of at least `suggest_score`), or have almost the same title (a character similarity of at least 0.9): a wrong year or author lowers CrossRef's score. When the match's authors, journal or year disagree with the citation (by the rules below), the reference is flagged with the match, and its DOI is not suggested: the citation may be wrong, the match may be another version of the work (an abstract or a reprint), or an AI-generated reference may borrow a real title. Otherwise the DOI of a confident match is suggested, and the report shows the record it points to. Unless both are articles, only a confident match is compared, and only on its authors, because the editions of a book or report share its title; its DOI is not suggested when the year differs by more than `year_tolerance`. A reference whose title was not read is neither compared nor given a DOI.
#'
#' A reference without a DOI whose title is not that of CrossRef's match is searched by its title alone, first in CrossRef (the search in `add_bib_match()` also uses the authors and journal, and keeps a match only above a minimum score, which short titles do not reach), then in DataCite, which holds arXiv, Zenodo, OSF and many data repositories, and then in Semantic Scholar, which holds conference papers without DOIs and many books. When none of the first five records of the registries' searches, nor Semantic Scholar's best match, has the cited title (by the title rules below), the reference is listed as not found. When a record has almost the same title (a character similarity of at least 0.9), and both the reference and the record are articles or preprints, its authors, year and (for a CrossRef journal article or a Semantic Scholar record) journal or venue are compared as for CrossRef's confident match, and the reference is flagged when they disagree. Books, software, reports and standard titles are not compared this way, because their editions, versions, reprints, chapters and reviews share a title with other authors and years. Most such references are works these sources do not hold (books, reports, theses, software, web pages) or titles misread from the PDF, so they do not change the traffic light; but a journal article or a preprint that cannot be found may be cited with a wrong title, or may not exist. Titles of fewer than three words are not searched. Each title is searched once, also when several references cite it. When a search fails, the reference is counted as not checked (`search_failed`), not as not found.
#'
#' Entries that were not read correctly from the PDF are listed separately and not compared: two references read as one entry (a second APA author-year start, as in "... Bar, M. (2004). ..."), an entry of which only the DOI was read, and a reference whose printed DOI was not read and so not looked up. When only the DOI was read and the entry before it has no DOI but its title search found that DOI, the DOI is given to that reference. These entries do not change the traffic light.
#'
#' For each checked reference we compare five fields against the DOI's record (for a reference without a DOI, the authors, journal and year):
#'
#' - **DOI** — flagged only when the reference printed a DOI that differs from the record (a blank cited DOI is never a mismatch). DOIs are compared after removing URL wrappers (`https://doi.org/`, journal article URLs), spaces and trailing punctuation left by the PDF, and the old double slash after the prefix (`10.1037//`). When the record was found by looking up the cited DOI (it has no search score), a record with a different DOI means the registry lists the cited DOI as an alias (for example after a journal moved publisher); this is reported as a note with the current DOI, not as an incoherence. A DOI mismatch is therefore only flagged when the record came from a title search. Papers read from bibr 12.x exports do not record how a record was found, so for them a different DOI is always a mismatch.
#' - **Year** — flagged when the cited year is more than `year_tolerance` years from the record (online-first and print years routinely differ by one year, so this is allowed by default). Before a year is flagged, CrossRef's dates for the record are read: a cited year near its online, print, issue or posting date is not a mismatch, because some publishers (IEEE among them) print a paper years after it appears online without depositing the online date. A cited year near only the year the DOI was created or the work accepted is listed as a note, not flagged. A creation date after the publication date (a DOI deposited for an old paper) is not used. A reference cited in a journal whose work is found only as a preprint is flagged: the journal article may not exist. Conference papers are left out, because many proceedings (ICML, NeurIPS, ICLR) have no DOIs; a venue that names a conference, has an acronym or belongs to a reference typed as a conference paper is taken as one, unless it is the name of a journal in SCImago's journal list ("IEEE Transactions on Neural Networks and Learning Systems", "Proceedings of the National Academy of Sciences") or a journal cited by its acronym alone ("PNAS", "JMLR"). A cited preprint (its journal, or its text when no journal was read, names a preprint server such as arXiv or PsyArXiv) is not compared on its year or journal with a published version of the work, and a cited published version found as a preprint may be up to `year_tolerance` + 1 years later than the preprint. A cited preprint with a published version, and authors that agree, is listed as a note.
#' - **Journal** — flagged when the cited journal disagrees with the record. Journal names are matched tolerantly: standard ISO-4 abbreviations (e.g. "J. Pers. Soc. Psychol." for "Journal of Personality and Social Psychology"), "&"/"and", "the", "WIREs" for "Wiley Interdisciplinary Reviews", an acronym before the full name ("MMWR. Morbidity and Mortality Weekly Report"), the conference name or acronym for a proceedings record registered as a journal article ("AAAI" for "Proceedings of the AAAI Conference on Artificial Intelligence"), a venue cited by the initials of its main words ("ICML" for "International Conference on Machine Learning", "NeurIPS" for "Neural Information Processing Systems"), and British and American spellings ("Behaviour" and "Behavior") are treated as equivalent. The words of the shorter name must appear in order in the longer one, starting with its first word, so a subtitle or section may be left out, but a name that starts inside another is another journal ("Psychological Science" is not "Current Directions in Psychological Science"), and a one-word name must match the other name exactly ("Nature" is not "Nature Neuroscience"). Words that the parsed journal lost are accepted when the record's name is in the reference text ("Perception, & Psychophysics" for "Attention, Perception, & Psychophysics"), also when a word in it is hyphenated at a line break. A name that continues another is still accepted ("Journal of Experimental Psychology" for "Journal of Experimental Social Psychology"). The journal is only compared when the record is a journal article: for book chapters, proceedings and reports the registry often gives a series or platform name ("Oxford Handbooks Online"). A cited "journal" that is an article number ("Article e17018"), which comes from reading the PDF, is not compared either.
#' - **Title** — flagged when the cited title is too different from the record's title, judged by character-level similarity (`title_similarity`) after stripping case, punctuation, footnote markers and diacritics. This ignores cosmetic differences (colons, question marks, em-dash spacing, line-break word splits), but also a change of one or two words in a long title. A title is also accepted when the record's title appears in the reference text as whole words ending at a title delimiter, for references whose title was not read correctly from the PDF. A title that begins with the other one followed by a title delimiter (":", "?", "." or "!") is accepted, because the record or the citation often holds only the main title; the subtitle is then not checked. A translated title in square brackets, as APA gives for a work in another language, is compared too. Letters of every script count, so titles in Cyrillic or Chinese are compared like others.
#' - **Authors** — flagged when the leading author surnames (the first `max_authors`) from the record are not all present in the cited author list, or when the record's first author is not cited first. Only the leading authors are required because author lists are routinely truncated with "et al.". The cited authors are read one person at a time, and each record surname must equal one cited surname, compared on its letters only, so diacritics, spacing and case are ignored ("Gredebäck" and "Gredeback", "Le Doux" and "LeDoux" match). When one of the two is a single word, it may also match the other's last word, for shortened compound surnames and particles ("Vafaei Shooshtari" cited as "Shooshtari", "Gelder" cited as "De Gelder"); the last word is also taken after a hyphen or an elided particle ("Purdie-Vaughns" cited as "Vaughns", "O'Connell" read from the PDF as "Connell"). A cited name without a comma is read as given name first, and the record surname must equal its last word or words. A name whose given and family names are swapped on one side (the record's given name is the cited surname, and the record's surname starts with the cited initial, as in "Wu, K." for the record's family name "Kui" and given name "Wu") is not flagged but listed as a note. Papers read from bibr 12.x exports keep each author list as printed ("Adam, H., Shirako, A., & Maddux, W. W"), so for them each record surname must equal one or more consecutive whole words of the list, with the same tolerance for compound surnames. A reference whose authors could not be read is not flagged. Extra cited authors after the first and given names are not checked. A cited list truncated with "et al." (or "and others", as BibTeX gives it), in the parsed authors or in the reference text before the title, needs only as many record authors as it cites, in order: truncation is a citation style, not an error.
#'
#' A mismatched DOI, journal or year flags a reference on its own. Title and author mismatches are governed by `min_mismatches`: the default (1) flags a reference when either the title or the authors disagree. For a reference without a DOI the title is not compared, so its authors alone flag it only at the default. In the validation below, all genuine author errors were single author mismatches, so `min_mismatches = 2` removed them while keeping most flags that were not errors; it is not recommended.
#'
#' The report shows each disagreeing cited value struck through beside the record's value, or lists the record's author surnames missing from the citation.
#'
#' <validation>In 30 randomly sampled Psychological Science papers (1,269 references, matched with `add_bib_match()` in November 2026), the module flagged 6 of the 555 references that printed a DOI and 12 of the 706 that did not (the other 8 were 6 entries not read reliably, a DOI read as an entry of its own, and a DOI registered with DataCite). Checked by hand, 13 of the 18 flags were citation errors: seven wrong author names (such as "Bernsten" for Berntsen, "Sonuga-Burke" for Sonuga-Barke, and "Sanderson, A." for Sanderson Abel), three printed DOIs that do not work (all three appear so in the reference lists the publishers deposited at CrossRef), and three wrong or misspelled journal names ("Nature Neuroscience Reviews" for Nature Reviews Neuroscience, "Cortex" for Neuropsychologia, and "Neuropsychophamacology"). Two were unclear (a diacritic in "Teder-Sälejärvi" and a compound surname cited by its first part), one was another version of the work (an 1897 abstract of an 1898 paper), and two were not errors (a renamed journal, and authors misread from the PDF). Two online-first years were not flagged once CrossRef's dates were read; one of them, cited with the year its DOI was created, is listed as a note. At `min_mismatches = 2`, 8 flags remain, 6 of them errors: the six author errors are lost.
#'
#' The module suggested a DOI for 507 references. For 443, the record agreed with the citation on title (character similarity of at least 0.95), first author, year (within one) and journal; a random 15 of these, checked by hand, were all the cited work. The other 64 were checked by hand: 63 were the cited work (most differed only by a subtitle or by "&amp;" in the record's journal), and 1 was unclear (an ICCV paper, with the title, authors and year of a cited ICLR workshop paper). The module listed 33 references as not found (57 before Semantic Scholar was searched; it holds most of the books). All were works these sources do not hold (books and chapters, reports, web pages and news, software, and journal articles without a DOI) or entries misread from the PDF, such as two statements of author contributions.
#'
#' For each kind of error, one error was added to each of 30 references, in the parsed reference and its text; these references had passed the check or had a suggested DOI. They were then looked up again with `add_bib_match()`. Of references with a DOI, the module flagged all 30 with a wrong year, 28 of 28 with a misspelled author (one of the first six), 29 of 29 with another journal, 29 of 30 with a changed digit in the DOI, and 28 of 30 with another reference's title; the 2 titles it missed were printed differently in the reference text, so the seeding left the original title there. Of references without a DOI, it flagged all 30 with a wrong year, 28 of 29 with a misspelled author and 25 of 30 with another journal. It flagged or listed as not found 26 of 30 titles with half their words replaced, and 24 of 30 titles taken from another reference. For 2 of the changed titles it suggested the DOI of the real work, because the changed title kept 70% of its characters (`title_similarity`). No other reference's result changed. These errors were added to references that were read correctly, so these rates exclude errors hidden by reading the PDF, and they do not estimate how often citation errors occur.
#'
#' On CiteTracer's synthetic benchmark (2,450 machine-learning citations built from real BibTeX entries; `data-raw/ref_accuracy_citetracer.R`, data version of 9 May 2026), the module flagged or listed as not found 64% of the 1,156 citations with a fabricated or changed field: 99.5% of fabricated DOIs, 92% of wrong years, 73% of wrong author lists, 68% of fabricated or paraphrased titles, 41% of fabricated venues, and 1% of citations with wrong pages, volumes or publishers (fields it does not compare). It flagged 7 of the 1,023 real citations (0.7%; two TPAMI papers cited with their preprint year, one conference paper cited two years before its arXiv record, three arXiv records listing an author the citation does not, and a paper in the Journal of Machine Learning Research, which has no DOIs, found only as a preprint) and listed none as not found (25 conference and workshop papers without DOIs were not found before Semantic Scholar was searched). Of the 271 borderline citations (name variants, fields no source has), it flagged 2 and listed none as not found. 25 real citations had a note: 20 cited preprints with a published version, 4 swapped names and 1 year of DOI creation. The benchmark has no PDF reading errors, and all its references are cited as articles.
#'
#' A flag should be read as "check this reference against the original source", not as a confirmed error.</validation>
#'
#' @keywords reference
#'
#' @author Daniel Lakens (\email{D.Lakens@tue.nl})
#' @author Lisa DeBruine (\email{lisa.debruine@glasgow.ac.uk})
#'
#' @import dplyr
#'
#' @param paper a paper object or paperlist object
#' @param max_authors how many of the leading authors to compare against the
#'   retrieved record. Author lists are routinely truncated with "et al." (APA
#'   abbreviates after 7), and GROBID often drops the tail of long lists, so we
#'   only require the first `max_authors` surnames to match.
#' @param title_similarity the minimum character-level similarity (0-1, after
#'   stripping case, punctuation, footnote markers and diacritics) for a cited
#'   title to be considered a match for the retrieved title. Lower values
#'   tolerate more formatting noise; a title below this is flagged.
#' @param min_mismatches how many of the parsing-sensitive fields (title and
#'   author) must disagree with the retrieved record before a reference is
#'   flagged as incoherent. The default (1) flags a single title or author
#'   mismatch. Set to 2 to require both; in the validation this removed the
#'   genuine author errors and kept most other flags. A mismatched DOI,
#'   journal or year always flags on its own, regardless of this setting.
#' @param year_tolerance how many years the cited year may differ from the
#'   retrieved record before the year is flagged. The default (1) allows a
#'   one-year difference, because the online-first and print publication years
#'   of an article routinely differ by a year. Set to 0 to require an exact
#'   match, or higher to be more lenient.
#' @param suggest_score for references with no DOI, the minimum CrossRef
#'   relevance score for a DOI found by title search to be offered as a
#'   suggested DOI. Low-scoring matches are usually the wrong paper, so they are
#'   not suggested. Raise to be more conservative, lower to suggest more.
#'   Scores of 1 or less, as bibr 12.x exports give, are on a 0-1 scale and
#'   are compared with `suggest_score / 100`.
#'
#' @returns a module output list. Its `table` has one row per reference, with
#'   the cited (`.orig`) and record (`.match`) values and these columns:
#'   - `tier`: how the reference was checked. "provided": compared with the
#'     record of its own DOI. "unresolved": its DOI has no record, and doi.org
#'     reports that it does not exist (flagged). "registered": its DOI exists
#'     but has no record; "unconfirmed": doi.org could not be asked; "not_checked":
#'     its paper was not looked up (these three are not checked). "crossref": no
#'     DOI, and `add_bib_match()` found a record. "search": no DOI, and a title
#'     search found a record that disagrees (flagged). "none": no DOI and no
#'     record. "unreadable": not read reliably from the PDF (see
#'     `read_problem`). "fragment": a DOI read as an entry of its own.
#'   - `incoherent`: the reference is flagged.
#'   - `doi_mismatch`, `title_mismatch`, `author_mismatch`, `year_mismatch`,
#'     `container_mismatch`: which fields disagree, for flagged references only.
#'     FALSE does not mean the field was compared.
#'   - `author_note`: the record's authors missing from the citation.
#'   - `year_note`: the cited year is that of another date in the record (a
#'     note).
#'   - `name_note`: an author's given and family names are swapped in the
#'     citation or the record (a note).
#'   - `preprint_only`: the reference is cited in a journal, but only a
#'     preprint with its title was found (flagged).
#'   - `published_doi`: the cited preprint has a published version with this
#'     DOI (a note).
#'   - `doi_alias`: the cited DOI is an alias of the record's DOI (a note).
#'   - `no_doi`, `doi_suggested`: no DOI was cited; a DOI is suggested.
#'   - `not_found`, `search_failed`: the title search found the work in none
#'     of CrossRef, DataCite and Semantic Scholar; the search failed.
#'   - `no_match`: no record was retrieved, for whatever reason (see `tier`).
#'   - `doi_exists`, `doi_ra`: doi.org's answer for a DOI without a record.
#'   - `record_source`: where the compared record comes from.
#'
#'   `summary_table` counts per paper the references with a DOI checked (`refs_checked`,
#'   tiers "provided" and "unresolved"), flagged, without a DOI, with a
#'   suggested DOI, not found and unreadable; a reference without a DOI may be
#'   counted as flagged, as suggested or as not found, but in only one of them.
ref_accuracy <- function(paper, max_authors = 6, title_similarity = 0.7,
                         min_mismatches = 1, year_tolerance = 1,
                         suggest_score = 70) {
  # table ----
  bib <- paper_table(paper, "bib")
  bib_match <- paper_table(paper, "bib_match")

  # If there are no rows, return immediately
  if (nrow(bib) == 0) {
    norefs <- list(
      traffic_light = "na",
      summary_text = "We found no references"
    )
    return(norefs)
  }

  cols <- c("paper_id", "bib_id", "doi", "title", "year", "authors",
            "container", "bib_type")
  if (!"bib_type" %in% names(bib)) bib$bib_type <- NA_character_
  # no Crossref lookup (convert() without crossref, no add_bib_match()): the
  # references are not checked, which is not a fault of the paper, but those
  # without a DOI are still counted
  if (nrow(bib_match) == 0) bib_match <- bib[0, cols]
  if (!"bib_type" %in% names(bib_match)) bib_match$bib_type <- NA_character_
  ref_table <- ref_table(paper)
  ref_table$doi <- NULL
  # one row per reference: with several bib_match rows for a bib_id the three
  # joins below gave k^3 rows, and ref_table() repeats the reference too
  # (U114); the match with the highest score is kept
  # matches read from elsewhere may have no score column
  if (!"score" %in% names(bib_match)) bib_match$score <- NA_real_
  if (!"service" %in% names(bib_match)) bib_match$service <- NA_character_
  bib_match <- bib_match[order(-bib_match$score), , drop = FALSE]
  bib_match <- bib_match[!duplicated(bib_match[, c("paper_id", "bib_id")]), , drop = FALSE]
  ref_table <- ref_table[!duplicated(ref_table[, c("paper_id", "bib_id")]), , drop = FALSE]
  # left join so every reference is kept, including those with no CrossRef
  # record. A reference that printed a DOI which does not resolve produces no
  # bib_match row; an inner join would silently drop it (and lose its cited
  # DOI), mislabelling it as a reference without a DOI.
  # The CrossRef relevance score comes along: only a title search gives one.
  table <- dplyr::left_join(
    bib[, cols], bib_match[, c(cols, "score", "service")],
    by = c("paper_id", "bib_id"),
    suffix = c(".orig", ".match")
  ) |>
    dplyr::left_join(ref_table, by = c("paper_id", "bib_id"))
  blank <- \(x) is.na(x) | !nzchar(trimws(x))
  alnum <- \(x) gsub("[^a-z0-9]", "", tolower(x))

  # Reading problems: entries that cannot be compared field by field.
  table$read_problem <- NA_character_
  # A DOI printed in the reference that the PDF reader did not take as its DOI:
  # a URL with "%2F" for "/", or a malformed DOI ("doi.org/1073191116659134"
  # for 10.1177/1073191116659134). It counts as the cited DOI when it is the
  # DOI the title search found, apart from lost punctuation or prefix; the
  # record is then the DOI's record, and a malformed DOI is a DOI mismatch.
  # Another DOI was not looked up, so the entry is a reading problem.
  text_doi <- vapply(table$text, \(x) {
    if (is.na(x)) return(NA_character_)
    m <- regmatches(x, regexpr(
      "(?i)(doi\\.org/|\\bdoi:\\s*)\\S+|10\\.\\d{4,9}(/|%2F)\\S+", x, perl = TRUE))
    if (!length(m)) return(NA_character_)
    doi_clean(sub("(?i)^.*?(doi\\.org/|doi:\\s*)", "", m, perl = TRUE))
  }, character(1), USE.NAMES = FALSE)
  in_text_doi <- blank(table$doi.orig) & !is.na(text_doi) &
    nchar(alnum(text_doi)) >= 8
  same_doi <- !is.na(table$doi.match) & (
    alnum(text_doi) == alnum(table$doi.match) |
      alnum(text_doi) == alnum(sub("^[^/]*/", "", table$doi.match)))
  table$doi.orig[in_text_doi & same_doi] <- text_doi[in_text_doi & same_doi]
  table$read_problem[in_text_doi & !same_doi] <- sprintf(
    "A DOI is printed in this reference (%s), but it was not read from the PDF, so it was not looked up.",
    text_doi[in_text_doi & !same_doi])

  # Only a DOI was read: the rest of the reference stayed with the entry
  # before it. When that entry has no DOI and its title search found this one,
  # the DOI is given to it and the fragment is dropped.
  doi_only <- !blank(table$doi.orig) & blank(table$title.orig) &
    blank(table$authors.orig) & blank(table$container.orig) & is.na(table$year.orig)
  prev <- c(NA, seq_len(nrow(table) - 1))
  prev[c(TRUE, table$paper_id[-1] != table$paper_id[-nrow(table)])] <- NA
  joins <- doi_only & !is.na(prev)
  joins[joins] <- blank(table$doi.orig[prev[joins]]) &
    alnum(doi_clean(table$doi.orig[joins])) == alnum(table$doi.match[prev[joins]]) &
    !is.na(table$doi.match[prev[joins]])
  table$doi.orig[prev[joins]] <- table$doi.orig[joins]
  table$read_problem[joins] <- "fragment"
  table$read_problem[doi_only & !joins] <-
    "Only the DOI was read for this entry; the rest of the reference was not separated from the entry before it."

  # Two references read as one entry: a second APA author-year start
  # ("... Bar, M. (2004). ..."). The details and the DOI may come from
  # different references, so the entry is not compared.
  apa_start <- "\\.\\s\\(((19|20)\\d{2}[a-z]?|n\\.d\\.|in press)\\)\\."
  merged <- lengths(gregexpr(apa_start, table$text, perl = TRUE)) >= 2 &
    grepl(apa_start, table$text, perl = TRUE)
  table$read_problem[merged & is.na(table$read_problem)] <-
    "This entry contains two references, which were read from the PDF as one, so it was not checked."

  # DOI: only flag when the reference itself printed a DOI that differs from
  # the matched record. A blank reference DOI is not a mismatch (the citer just
  # did not include one, and CrossRef supplied it). Cited DOIs are cleaned
  # first, so a doi.org or journal URL around the same DOI is not a mismatch,
  # and the old double slash after the prefix ("10.1037//0022-3514...", common
  # in APA references) is the same DOI as the single slash.
  # doi_clean() also drops what reading the PDF adds ("10.1037/0003-066x.54.6.4 08",
  # "...408.", "<https://doi.org/...>").
  norm_doi <- \(x) tolower(sub("^(10\\.\\d+)//", "\\1/", doi_clean(x)))
  doi_differs <- !is.na(table$doi.orig) & nzchar(table$doi.orig) &
    norm_doi(table$doi.orig) != norm_doi(table$doi.match)
  # A record that add_bib_match() found by looking up the cited DOI has no
  # search score. If it carries another DOI, the registry treats the cited DOI
  # as an alias of it, e.g. after a journal moved publisher: the citation still
  # finds the right work, so this is a note, not an incoherence. A record from
  # a title search (it has a score) can show that the cited DOI is wrong; that
  # is the route for a cited DOI that is not valid as printed, such as a DOI
  # written as a URL before add_bib_match() cleaned DOIs. bibr 12.x exports do
  # not record how a record was found (writing one drops the score), so there
  # a different DOI stays a mismatch.
  looked_up_by_doi <- is.na(table$score) &
    doi_valid_format(doi_clean(table$doi.orig)) %in% TRUE &
    !table$paper_id %in% .bibr12_paper_ids(paper)
  table$doi_alias <- (doi_differs %in% TRUE) & looked_up_by_doi
  table$doi_mismatch <- doi_differs & !table$doi_alias

  # year: only flag when more than `year_tolerance` years apart (online-first
  # vs print publication routinely differ by a year and is not an incoherence)
  year_diff <- abs(as.numeric(table$year.orig) - as.numeric(table$year.match))
  table$year_mismatch <- !is.na(year_diff) & year_diff > year_tolerance

  # fold accented Latin letters to plain ASCII ("Gredebäck" and "Gredeback",
  # "Nguyễn" and "Nguyen", "Þórsson" and "Thorsson"), so that diacritics never
  # cause a mismatch on their own
  deaccent <- \(x) stringi::stri_trans_general(x, "Latin-ASCII")

  # clean up text to prevent irrelevant mismatches
  clean <- \(x) {
    tolower(x) |>
      gsub("</?[a-z]+>", "", x = _) |>
      deaccent() |>                              # fold diacritics
      gsub("\\p{Pd}", " ", x = _, perl = TRUE) |> # dashes fold to spaces (they were removed: "retractedevil"; U114)
      gsub("\\s+", " ", x = _) |>
      gsub("[\u2018\u2019\u201A\u201B\u0060]", "'", x = _) |>
      # make all single quotes, even doubles
      gsub("[\"\u201C\u201D\u201E\u201F]", "'", x = _) |>
      gsub("\\.\\s*$", "", x = _) # remove . at end
  }

  # journal/container: flag when the cited journal disagrees with CrossRef.
  # Skip when either side is missing (NA container is unknown, not a mismatch).
  # Journals are routinely abbreviated (ISO-4: "J. Pers. Soc. Psychol." for
  # "Journal of Personality and Social Psychology"), so a plain string compare
  # over-flags. We drop stop-words, then accept the shorter name when its
  # significant tokens appear in the longer one in order, starting with its
  # first token, allowing each abbreviated token to be a prefix of the full
  # token; the longer name may continue with a subtitle or section ("Journal
  # of Experimental Psychology: General"). A name that starts inside another
  # ("Psychological Science" in "Current Directions in Psychological Science")
  # is another journal. Words lost in
  # reading the PDF ("Perception, & Psychophysics" for "Attention, Perception,
  # & Psychophysics") are allowed when the record's name is in the reference
  # text. "WIREs" is Wiley's short form of "Wiley Interdisciplinary Reviews".
  # British and American spellings of the same word ("Behaviour" and
  # "Behavior", "Paediatrics" and "Pediatrics", "Organisation" and
  # "Organization", "Centre" and "Center", "Modelling" and "Modeling") are
  # folded the same way on both sides, so an abbreviation stays a prefix
  uk_us <- \(w) {
    w <- gsub("our", "or", w, fixed = TRUE)
    w <- gsub("(?<=[a-z])(ae|oe)", "e", w, perl = TRUE)
    w <- gsub("is(e|ed|es|ing|ation|ations)$", "iz\\1", w)
    w <- gsub("tre$", "ter", w)
    w <- gsub("ll", "l", w, fixed = TRUE)
    sub("^programme", "program", w)
  }
  journal_tokens <- \(x) {
    x <- clean(x)
    x <- gsub("&amp;|&", " and ", x)
    x <- gsub("\\bwires\\b", "wiley interdisciplinary reviews", x)
    x <- gsub("[^a-z ]", " ", x)
    toks <- strsplit(trimws(gsub("\\s+", " ", x)), " ")[[1]]
    toks <- uk_us(toks)
    toks[!toks %in% c("of","and","the","for","in","on","a","an","de","") &
           nchar(toks) > 0]
  }
  # do tokens ta match tb from position `from` on, a token as a prefix?
  tokens_at <- \(ta, tb, from) {
    idx <- from + seq_along(ta) - 1L
    all(idx <= length(tb)) &&
      all(startsWith(tb[idx], ta) | startsWith(ta, tb[idx]))
  }
  # do the tokens of ta appear in tb in order, starting with its first token?
  # Later words may be skipped ("Royal Society of London B" for "Royal Society
  # B", "Psycho logical Review" split at a line break)
  in_sequence <- \(ta, tb) {
    hit <- \(a, b) startsWith(b, a) || startsWith(a, b)
    if (!hit(ta[1], tb[1])) return(FALSE)
    j <- 2L
    for (tok in ta[-1]) {
      while (j <= length(tb) && !hit(tok, tb[j])) j <- j + 1L
      if (j > length(tb)) return(FALSE)
      j <- j + 1L
    }
    TRUE
  }
  journal_coherent <- \(cited, record, text) {
    # an acronym before a full stop at the start of a name ("MMWR. Morbidity
    # and Mortality Weekly Report") may be left out
    acronym <- "^\\s*[A-Z]{2,}\\.\\s+(?=\\S)"
    # proceedings are cited by the conference name ("AAAI Conference on
    # Artificial Intelligence" for "Proceedings of the AAAI Conference ..."),
    # or by its acronym alone ("AAAI")
    proc <- "(?i)^\\s*proceedings\\s+of\\s+(the\\s+)?"
    if (grepl(proc, record, perl = TRUE)) {
      conf <- sub(proc, "", record, perl = TRUE)
      if (grepl("^\\s*[A-Z]{3,}\\s*$", cited) &&
          trimws(cited) %in% strsplit(conf, "[^[:alnum:]]+")[[1]]) return(TRUE)
      if (names_coherent(cited, conf, text)) return(TRUE)
    }
    # a venue cited by the initials of its name's main words ("ICML" for
    # "International Conference on Machine Learning", "NeurIPS" for "Neural
    # Information Processing Systems")
    short <- gsub("[^[:alpha:]]", "", cited)
    caps <- gsub("[^A-Z]", "", short)
    if (!grepl("\\s", trimws(gsub("\\b\\d{4}\\b", "", cited))) && nchar(caps) >= 3 &&
        identical(caps, toupper(paste(substr(journal_tokens(record), 1, 1), collapse = ""))))
      return(TRUE)
    names_coherent(cited, record, text) ||
      (grepl(acronym, cited, perl = TRUE) || grepl(acronym, record, perl = TRUE)) &&
      names_coherent(sub(acronym, "", cited, perl = TRUE),
                     sub(acronym, "", record, perl = TRUE), text)
  }
  names_coherent <- \(cited, record, text) {
    ta <- journal_tokens(cited); tb <- journal_tokens(record)
    if (!length(ta) || !length(tb)) return(TRUE)        # unknown, don't flag
    short <- if (length(ta) > length(tb)) tb else ta
    long <- if (length(ta) > length(tb)) ta else tb
    if (!(length(short) == 1 && length(long) > 1) && in_sequence(short, long))
      return(TRUE)
    # the record's name in the reference text, when the parsed journal lost
    # words of it
    if (length(ta) >= length(tb)) return(FALSE)
    # (a word hyphenated at a line break, "Ad- vances", is joined)
    tt <- if (is.na(text)) character() else
      journal_tokens(gsub("(?<=[a-z])- (?=[a-z])", "", text, perl = TRUE))
    length(tt) >= length(tb) &&
      any(vapply(seq_len(length(tt) - length(tb) + 1L),
                 \(k) tokens_at(tb, tt, k), logical(1)))
  }
  # Only compared when the record is a journal article: for book chapters,
  # proceedings and reports the registry's container is often a series or
  # platform name ("Oxford Handbooks Online" for a handbook's title). An
  # article number read as the journal ("Article e17018") is not compared
  # either.
  article_number <- grepl("^(article\\s*)?e?\\d+$", trimws(tolower(table$container.orig)))
  # bibr 12.x calls a journal article "journal_article"
  is_article <- table$bib_type.match %in% c("article", "journal_article") |
    is.na(table$bib_type.match)
  table$container_mismatch <- mapply(\(a, b, text, check) {
    if (!check || is.na(a) || is.na(b) || !nzchar(trimws(a)) || !nzchar(trimws(b)))
      return(FALSE)
    !journal_coherent(a, b, text)
  }, table$container.orig, table$container.match, table$text,
  is_article & !article_number, USE.NAMES = FALSE)

  # title check: compare on character similarity rather than exact equality, so
  # that formatting noise (footnote markers, em-dash spacing, colons/question
  # marks, line-break word splits like "Proba bilistic") does not flag a real
  # title, while a genuinely different title still does. norm_title strips tags,
  # footnote markers and punctuation, folds dashes to spaces and diacritics.
  norm_title <- \(x) {
    # footnote superscripts first: clean() removes the tags but keeps their
    # text, so this never matched after it and the markers stayed (U114)
    x <- gsub("<sup>.*?</sup>", "", x, ignore.case = TRUE, perl = TRUE)
    x <- clean(x)                 # lowercases, strips tags, folds diacritics
    # letters and digits of every script: keeping only a-z emptied a title
    # in Cyrillic or Chinese, which then agreed with any record
    gsub("[^\\p{L}\\p{N}]", "", x, perl = TRUE)
  }
  # does a cited title agree with a record's title? Vectorised over the three
  # arguments; also used for the DataCite records found for a reference
  # without a DOI
  title_check <- \(cited, record, text) {
    a <- norm_title(cited)
    b <- norm_title(record)
    charsim <- mapply(\(x, y) {
      if (is.na(x) || is.na(y) || !nzchar(x) || !nzchar(y)) return(NA_real_)
      1 - utils::adist(x, y)[1, 1] / max(nchar(x), nchar(y))
    }, a, b, USE.NAMES = FALSE)

    # also accept when the record title appears verbatim in the reference text
    # (handles cases where GROBID failed to split the title out of the
    # citation), as whole words ("behavior" is not found in "behaviorism" or
    # "misbehavior") and ending at a title delimiter or at the bracket of an
    # APA description ("(Version 1.0.0) [Computer code]"), so that a cited title
    # that continues ("Origins" in "The origins of ...") or a journal name
    # followed by its volume is not taken for the title.
    clean_text <- clean(text)
    match_clean <- clean(record)
    escape <- \(x) gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)
    in_text <- mapply(\(pattern, x) !is.na(pattern) && nzchar(pattern) &&
                        grepl(pattern, x, fixed = TRUE) &&
                        grepl(paste0("(^|[^a-z0-9])", escape(pattern),
                                     if (grepl("[:?.!]$", pattern)) "" else "\\s*($|[:?.!(\\[])"),
                              x, perl = TRUE),
                      match_clean, clean_text, USE.NAMES = FALSE)

    # CrossRef often holds only the main title, without the subtitle the
    # reference cites ("Marginally significant effects as evidence for
    # hypotheses" for "...: Changing attitudes over four decades"). A cited
    # title that starts with the record's title is accepted when the rest
    # starts at a title delimiter (":", "?", "." or "!"); the subtitle itself
    # cannot then be checked.
    delimited <- \(x) {
      x <- gsub("<sup>.*?</sup>", "", x, ignore.case = TRUE, perl = TRUE)
      trimws(gsub("[^a-z0-9:?.!]+", " ", clean(x)))
    }
    # The citation may also omit a subtitle that the record has.
    starts_at_delimiter <- \(long, short) {
      if (is.na(long) || is.na(short) || nchar(short) < 20 ||
          !startsWith(long, short)) return(FALSE)
      grepl("[:?.!]$", short) ||
        grepl("^ ?[:?.!]", substring(long, nchar(short) + 1))
    }
    cited_d <- delimited(cited)
    record_d <- delimited(record)
    main_title <- mapply(\(c, r) starts_at_delimiter(c, r) || starts_at_delimiter(r, c),
                         cited_d, record_d, USE.NAMES = FALSE)

    # APA gives the English translation of a title in another language in
    # square brackets ("Características vocais ... [Vocal acoustic
    # characteristics ...]"), which may be close to the record's title
    translated <- mapply(\(cited, y) {
      tr <- regmatches(cited, regexpr("\\[[^]]+\\]", cited))
      if (is.na(y) || !nzchar(y) || !length(tr)) return(FALSE)
      x <- norm_title(tr)
      nzchar(x) && 1 - utils::adist(x, y)[1, 1] / max(nchar(x), nchar(y)) >= title_similarity
    }, ifelse(is.na(cited), "", cited), b, USE.NAMES = FALSE)

    # For a suggested DOI, a title that only adds or drops words at the end
    # (a subtitle without its colon, a footnote CrossRef appended to the
    # title) is close enough: the suggestion is checked by the user.
    starts_same <- mapply(\(x, y) {
      if (is.na(x) || is.na(y)) return(FALSE)
      short <- if (nchar(x) < nchar(y)) x else y
      nchar(short) >= 20 && startsWith(if (nchar(x) < nchar(y)) y else x, short)
    }, a, b, USE.NAMES = FALSE)

    # A title that was not read (or a record without one) neither agrees nor
    # disagrees: it is not a mismatch, but no DOI is suggested for it.
    known <- !is.na(charsim)
    agrees <- (known & charsim >= title_similarity) | in_text | main_title | translated
    list(mismatch = known & !agrees, agrees = agrees, starts_same = starts_same,
         charsim = charsim)
  }
  tc <- title_check(table$title.orig, table$title.match, table$text)
  table$title_mismatch <- tc$mismatch
  table$title_starts_same <- tc$starts_same
  table$title_agrees <- tc$agrees
  title_charsim <- tc$charsim

  # Before a year is flagged, CrossRef's dates for the record are read.
  # bib_match keeps the print year, and some publishers (IEEE among them)
  # print a paper years after it appears online without depositing the
  # online date. A cited year within `year_tolerance` of the online, print,
  # issue or posting date is not a mismatch. A cited year that is only near
  # the year the DOI was created, or the work accepted, is a note
  # (`year_note`), not a flag. Only records whose title agrees are read.
  record_dates <- c(published = "published-online", published = "published-print",
                    published = "issued", published = "posted",
                    created = "created", accepted = "accepted", approved = "approved")
  # for each DOI, "published" when the cited year is near a publication date,
  # the name of another date it is near, or NA
  year_source <- \(doi, cited) {
    out <- rep(NA_character_, length(doi))
    ok <- which(doi_valid_format(doi_clean(doi)) %in% TRUE & !is.na(cited))
    if (!length(ok)) return(out)
    cr <- tryCatch(suppressMessages(crossref_doi(doi[ok], select = c("DOI", record_dates))),
                   error = \(e) NULL)
    if (is.null(cr) || nrow(cr) != length(ok)) return(out)
    yrs <- vapply(record_dates, \(col)
      suppressWarnings(as.integer(substr(cr[[col]] %||% rep(NA, nrow(cr)), 1, 4))),
      integer(length(ok)))
    yrs <- matrix(yrs, nrow = length(ok))
    # a DOI created after the work was published (deposited for an old
    # paper) says nothing about the year it appeared
    pub <- suppressWarnings(apply(yrs[, names(record_dates) == "published", drop = FALSE],
                                  1, min, na.rm = TRUE))
    after <- !is.na(yrs) & col(yrs) > sum(names(record_dates) == "published") &
      is.finite(pub) & yrs > pub
    yrs[after] <- NA
    near <- !is.na(yrs) & abs(yrs - cited[ok]) <= year_tolerance
    near <- matrix(near, nrow = length(ok))
    out[ok] <- apply(near, 1, \(r) names(record_dates)[which(r)[1]])
    out
  }
  year_note_text <- \(src, cited, record) sprintf(
    "%s is the year the record was %s; it was published in %s", cited, src, record)
  table$year_note <- NA_character_
  # the record each note refers to
  note_record <- rep(NA_character_, nrow(table))
  ychk <- which(table$year_mismatch & (table$title_agrees | table$title_starts_same))
  if (length(ychk)) {
    src <- year_source(table$doi.match[ychk], as.integer(table$year.orig[ychk]))
    table$year_mismatch[ychk[!is.na(src)]] <- FALSE
    soft <- ychk[!is.na(src) & src != "published"]
    table$year_note[soft] <- year_note_text(src[!is.na(src) & src != "published"],
                                            table$year.orig[soft], table$year.match[soft])
    note_record[soft] <- table$doi.match[soft]
  }

  # A reference that cites a preprint (its journal, or its text when no
  # journal was read, names a preprint server) is not compared on its year or
  # journal with a published version of the work, and a reference that cites
  # a published version may be a year later than its preprint (see the title
  # search below). A preprint with a published version
  # is noted (`published_doi`), so that a reviewer can see that it has been
  # superseded.
  preprint_words <- "(?i)\\b(arxiv|corr|biorxiv|medrxiv|psyarxiv|socarxiv|edarxiv|chemrxiv|ssrn|research square|preprints?)\\b"
  cited_preprint <- table$bib_type.orig %in% "preprint" |
    (!blank(table$container.orig) & grepl(preprint_words, table$container.orig, perl = TRUE)) |
    (blank(table$container.orig) & grepl(preprint_words, table$text, perl = TRUE))
  table$published_doi <- NA_character_
  # A reference cited in a journal whose work is found only as a preprint is
  # flagged (`preprint_only`): the journal article may not exist. Conference
  # papers are left out, because many proceedings (ICML, NeurIPS, ICLR) have
  # no DOIs, so their papers are found only as preprints. A venue is taken as
  # a conference when it names one ("Proceedings", "Workshop", ...), has an
  # acronym ("ICML", "Tiny Papers @ ICLR"), or the reference is typed as a
  # conference paper.
  conference_words <- "(?i)\\b(proc|proceedings|conference|conf|workshops?|symposium|meeting|congress|colloquium|summit|track)\\b"
  acronym_word <- "(^|[^[:alnum:]])[[:alnum:]]*[A-Z][[:alnum:]]*[A-Z][[:alnum:]]*($|[^[:alnum:]])"
  # Journals whose names look like conferences ("IEEE Transactions on ...",
  # "Proceedings of the National Academy of Sciences", "PLoS ONE") are taken
  # as journals: names from SCImago's journal list (data-raw/journal_names.R),
  # matched as journal names are, and a few journals cited by their acronym
  # alone ("PNAS", "JMLR").
  journal_names <- readRDS(system.file("databases/journal_names.Rds", package = "metacheck"))
  listed_journal <- local({
    first <- NULL
    \(x) {
      if (trimws(x) %in% journal_names$acronyms) return(TRUE)
      tok <- journal_tokens(x)
      if (!length(tok)) return(FALSE)
      if (is.null(first)) first <<- vapply(journal_names$titles,
        \(t) journal_tokens(t)[1] %||% "", "", USE.NAMES = FALSE)
      cand <- journal_names$titles[nzchar(first) &
                                     (startsWith(first, tok[1]) | startsWith(tok[1], first))]
      # a conference is not the journal its name begins with ("Proceedings
      # of the IEEE Computer Society Conference ..." is not "Proceedings of
      # the IEEE")
      if (grepl(event_words, x, perl = TRUE))
        cand <- cand[grepl(event_words, cand, perl = TRUE)]
      any(vapply(cand, \(t) journal_coherent(x, t, NA_character_), logical(1)))
    }
  })
  # a name with a journal word and no event word is a journal ("Journal of
  # the International Neuropsychological Society: JINS", "ACM Transactions
  # on Graphics")
  event_words <- "(?i)\\b(conferences?|symposium|workshops?|meetings?|congress|colloquium|summit)\\b"
  journal_words <- "(?i)\\b(journal|reviews?|wires|letters|transactions|bulletin|annals|quarterly|magazine)\\b"
  looks_like_conference <- !blank(table$container.orig) &
    (grepl(conference_words, table$container.orig, perl = TRUE) |
       grepl(acronym_word, table$container.orig)) &
    !(grepl(journal_words, table$container.orig, perl = TRUE) &
        !grepl(event_words, table$container.orig, perl = TRUE))
  check <- unique(table$container.orig[looks_like_conference & !cited_preprint])
  listed <- check[vapply(check, listed_journal, logical(1))]
  journal_cited <- !cited_preprint & !blank(table$container.orig) &
    (!looks_like_conference | table$container.orig %in% listed) &
    !table$bib_type.orig %in% c("inproceedings", "proceedings", "conference",
                                "book", "inbook", "incollection", "techreport",
                                "phdthesis", "mastersthesis", "misc", "preprint")
  table$preprint_only <- FALSE


  # author check: do the leading author surnames from the retrieved record
  # appear in the cited author list, and is the record's first author cited
  # first? Only the first `max_authors` are required, because author lists are
  # commonly truncated with "et al." (and GROBID often drops the tail of long
  # lists), so a missing trailing author is not evidence of an incoherent
  # citation. Diacritics are ignored (handled by clean()).
  last_names <- lapply(table$authors.match, \(a) {
    tryCatch({
      # the given names go along, for names with their parts swapped
      if (is.data.frame(a)) {
        structure(a$family, given = if ("given" %in% names(a)) a$given else rep(NA_character_, nrow(a)))
      } else {
        names <- strsplit(a, "; ")[[1]]
        structure(unname(sapply(names, \(x) strsplit(x, ", ")[[1]][[1]])),
                  given = unname(sapply(names, \(x) strsplit(x, ", ")[[1]][2])))
      }
    }, error = \(e) return(NA))
  })

  # The cited authors are read one person at a time ("Family, Given; ..."),
  # and a record surname must equal one cited surname. Surnames are compared
  # on their letters only, so spacing in particles and compound names ("Le
  # Doux" and "LeDoux", or CrossRef's non-breaking space in "de Lange") does
  # not matter. When one side is a single word, it also matches the other
  # side's last word: CrossRef sometimes has the given name in the family
  # field ("Mike Burton"), citations shorten compound surnames ("Vafaei
  # Shooshtari" cited as "Shooshtari"), and CrossRef sometimes drops the
  # particle that the citation keeps ("Gelder" cited as "De Gelder"). A
  # cited name without a comma is taken as "Given Family": the record
  # surname must equal its last word or words ("Wood" is not found in
  # "John Blackwood"). bibr 12.x exports keep the author list as printed
  # ("Adam, H., Shirako, A., & Maddux, W. W"), which cannot be split into
  # people reliably, so there a record surname must equal one or more
  # consecutive whole words of the list ("Adam" is not found in "McAdam").
  letters_only <- \(x) gsub("[^a-z]", "", clean(x))
  # the last part of a surname, after a space, a hyphen or an elided
  # particle: "O'Connell" read from the PDF as "Connell", "Purdie-Vaughns"
  # cited as "Vaughns"
  last_part <- \(x) letters_only(
    sub(".*([[:space:] ‐-]|\\b[DdLlOo]['’])", "", x, perl = TRUE))
  cited_surnames <- \(o) {
    people <- trimws(strsplit(paste(o, collapse = ";"), ";", fixed = TRUE)[[1]])
    people <- people[nzchar(people)]
    family <- trimws(sub(",.*", "", people))
    has_comma <- grepl(",", people, fixed = TRUE)
    list(name = letters_only(family),
         last = last_part(family),
         one_word = has_comma & !grepl("[[:space:] ]", family),
         given_first = !has_comma,
         given = ifelse(has_comma, letters_only(sub("^[^,]*,", "", people)), ""),
         # "Alice Brown Jones" ends in "jones", "brownjones", ...
         ends = lapply(family, \(f) {
           w <- letters_only(strsplit(f, "[[:space:] ]+")[[1]])
           w <- w[nzchar(w)]
           vapply(seq_along(w), \(k) paste(utils::tail(w, k), collapse = ""), "")
         }))
  }
  # which cited people does record surname x (given name g) match? With
  # `swapped`, a name whose parts are swapped on one side matches too: the
  # record's given name is the cited surname, and the record's surname starts
  # with the cited initial ("Wu, K." for given "Wu", family "Kui"). Such a
  # name is not a mismatch, but it is noted.
  person_matches <- \(x, cs, g = NA, swapped = FALSE) {
    full <- letters_only(x)
    last <- last_part(x)
    record_one_word <- !grepl("[[:space:] ]", trimws(x))
    g <- if (is.na(g)) "" else letters_only(g)
    cs$name == full |
      (cs$one_word & cs$name == last) |
      (record_one_word & !cs$given_first & cs$last == full) |
      (cs$given_first & vapply(cs$ends, \(e) full %in% e, logical(1))) |
      (swapped & nzchar(g) & nzchar(full) & cs$name == g & nzchar(cs$given) &
         substr(cs$given, 1, 1) == substr(full, 1, 1))
  }
  # is record surname x one or more consecutive words of a printed list?
  words_match <- \(x, w) {
    full <- letters_only(x)
    wl <- letters_only(w)
    joined <- unlist(lapply(1:3, \(k) {
      if (length(wl) < k) return(character())
      vapply(seq_len(length(wl) - k + 1), \(s) paste(wl[s:(s + k - 1)], collapse = ""), "")
    }))
    full %in% joined || last_part(x) %in% wl || full %in% last_part(w)
  }
  printed_words <- \(o) {
    w <- strsplit(o, "[[:space:] ,;&]+")[[1]]
    w[nzchar(letters_only(w))]
  }
  bibr <- table$paper_id %in% .bibr12_paper_ids(paper)
  # A list truncated with "et al." (or "and others", as BibTeX gives it) is
  # a citation style: only as many record authors as were cited are required.
  # The PDF reader may drop "et al." from the authors, so the reference text
  # before the cited title is read too.
  etal <- "(?i)\\bet\\.?\\s*al\\b|(^|[;,&]\\s*|\\band\\s+)others\\b"
  truncated <- \(o, text, title) {
    # compared after clean(), so a title read with other capitals than the
    # reference text ("The Origins of" in "The origins of") is still found
    before <- if (is.na(text)) "" else {
      text <- clean(text)
      at <- if (is.na(title) || !nzchar(title)) -1L else
        regexpr(substr(clean(title), 1, 20), text, fixed = TRUE)
      if (at > 0) substr(text, 1, at - 1) else ""
    }
    grepl(etal, paste(o, collapse = "; "), perl = TRUE) ||
      grepl(etal, before, perl = TRUE)
  }
  # for each reference, a note on what disagrees, or NA
  author_check <- \(record, cited, as_printed, text, title) mapply(\(l, o, as_printed, text, title) {
    if (length(l) == 0 || all(is.na(l))) return(NA_character_)  # nothing to check
    # no cited authors were read from the reference: unknown, not a mismatch
    if (length(o) == 0 || all(is.na(o)) || !nzchar(trimws(paste(o, collapse = ""))))
      return(NA_character_)
    g <- attr(l, "given") %||% rep(NA_character_, length(l))
    first <- if (!is.na(l[1]) && nzchar(letters_only(l[1]))) l[1] else NA
    first_g <- g[1]
    keep <- !is.na(l) & nzchar(letters_only(l))
    l <- utils::head(l[keep], max_authors)
    g <- utils::head(g[keep], max_authors)
    cut <- truncated(o, text, title)
    o <- gsub(etal, "", paste(o, collapse = "; "), perl = TRUE)
    if (as_printed) {
      w <- printed_words(o)
      if (cut) l <- utils::head(l, 1)
      found <- vapply(l, \(x) words_match(x, w), logical(1))
      first_ok <- is.na(first) || words_match(first, printed_words(sub(",.*", "", o)))
    } else {
      cs <- cited_surnames(o)
      if (cut) l <- utils::head(l, max(1, sum(nzchar(cs$name))))
      found <- vapply(l, \(x) any(person_matches(x, cs)), logical(1))
      swap <- !found & vapply(seq_along(l), \(k)
        any(person_matches(l[k], cs, g[k], swapped = TRUE)), logical(1))
      found <- found | swap
      first_ok <- is.na(first) || !length(cs$name) ||
        person_matches(first, cs, first_g, swapped = TRUE)[1]
    }
    note <- c(
      if (!all(found)) sprintf("%s not found among the cited authors",
                               paste(l[!found], collapse = ", ")),
      if (all(found) && !first_ok) sprintf("the first author is %s", first))
    if (length(note)) note
    else if (!as_printed && any(swap)) paste0("SWAP:", paste(l[swap], collapse = ", "))
    else NA_character_
  }, record, cited, as_printed, text, title, USE.NAMES = FALSE)
  # a note of swapped names is split from the mismatch notes
  split_swap <- \(note) {
    swap <- startsWith(note, "SWAP:") %in% TRUE
    list(note = ifelse(swap, NA_character_, note),
         swapped = ifelse(swap, sprintf(
           "given and family names are swapped in the record or the citation (%s)",
           sub("SWAP:", "", note, fixed = TRUE)), NA_character_))
  }
  an <- split_swap(author_check(last_names, table$authors.orig, bibr,
                                table$text, table$title.orig))
  table$author_note <- an$note
  table$name_note <- an$swapped
  table$author_mismatch <- !is.na(table$author_note)

  # tier: how did we get the record we are checking against?
  #  "provided"   - the reference printed its own DOI and CrossRef returned a
  #                 record for it; we compare the cited details against that
  #                 exact record. Firm.
  #  "unresolved" - the reference printed a DOI, but there is no record for
  #                 it. Flagged as a DOI that could not be found. bib_match
  #                 does not record why a lookup found nothing, so this also
  #                 catches a lookup that failed for network reasons (which
  #                 add_bib_match() only reports as a message at the time) and
  #                 a DOI that is not valid as printed and whose title search
  #                 found nothing. doi.org is then asked whether the DOI
  #                 exists; only a DOI it reports as not existing stays here.
  #  "registered" - an unresolved DOI that doi.org knows: no record was
  #                 retrieved for it (a lookup that failed, or an agency whose
  #                 records are not looked up), so it is not checked.
  #  "unconfirmed" - an unresolved DOI that doi.org could not be asked about
  #                 (offline, a timeout, a server error): not checked.
  #  "not_checked" - the reference printed a DOI, but its paper has no
  #                 bib_match rows at all: it was not looked up.
  #  "crossref"   - the reference had no DOI and CrossRef supplied one via fuzzy
  #                 title/author search; the match may be wrong, so it is only
  #                 compared when its title agrees and the search was confident.
  #  "none"       - no DOI at all.
  #  "search"     - no DOI, and a title search (below) found a record with
  #                 the cited title whose authors or year differ: flagged.
  #  "unreadable" - a reading problem (see read_problem): listed, not compared.
  #  "fragment"   - a DOI read as an entry of its own and given to the
  #                 reference before it; not counted.
  has_own_doi <- !blank(table$doi.orig)
  has_record  <- !blank(table$title.match)
  looked_up   <- table$paper_id %in% bib_match$paper_id
  table$tier <- dplyr::case_when(
    table$read_problem %in% "fragment" ~ "fragment",
    !is.na(table$read_problem) ~ "unreadable",
    has_own_doi & has_record   ~ "provided",
    has_own_doi & looked_up    ~ "unresolved",
    has_own_doi                ~ "not_checked",
    has_record                 ~ "crossref",
    .default                   = "none"
  )
  # an unresolved DOI is checked at doi.org: one that does not exist stays
  # flagged; one that is registered (a lookup that failed, or an agency such as
  # mEDRA whose records are not looked up) is listed as not checked
  table$doi_exists <- NA
  table$doi_ra <- NA_character_
  unres <- which(table$tier == "unresolved")
  if (length(unres)) {
    ra <- doi_ra(table$doi.orig[unres])
    table$doi_exists[unres] <- ra$exists
    table$doi_ra[unres] <- ra$ra
    table$tier[unres[ra$exists %in% TRUE]] <- "registered"
    # a failed doi.org request says nothing about the DOI
    table$tier[unres[is.na(ra$exists)]] <- "unconfirmed"
  }
  # no_match: the reference could not be matched to a retrieved record (kept for
  # downstream modules such as ref_summary that group on it)
  table$no_match <- !has_record & table$tier != "fragment"

  # incoherence: cited details disagree with the record the reference's OWN DOI
  # points to (tier "provided"), the exact record the author cited. A reference
  # with no DOI is compared with the record a CrossRef title search found only
  # when that record would be suggested: a confident match with the same title.
  # A less certain match is often another paper, so a "mismatch" would be
  # CrossRef's error, not the citation's. The title is not compared then, as it
  # agrees by construction, and a record with the same title but other authors,
  # journal or year is flagged instead of suggested: a citation error, another
  # version of the work (an abstract, a reprint), or an AI-generated reference
  # that borrows a real title.
  # A DOI, journal or year mismatch flags on its own; title and author
  # mismatches only count when at least `min_mismatches` of them disagree. In
  # the validation, however, the genuine errors were author mismatches, and the
  # journal and year flags came from reading or registry differences.
  strong <- (table$doi_mismatch %in% TRUE) |
            (table$year_mismatch %in% TRUE) |
            (table$container_mismatch %in% TRUE)
  n_parsing_mismatch <- (table$title_mismatch %in% TRUE) +
                        (table$author_mismatch %in% TRUE)
  # a reference is incoherent when it printed its own DOI and either that DOI
  # could not be found (tier "unresolved") or the retrieved record disagrees
  # with the cited details (tier "provided"), or when it printed none and the
  # record that would be suggested disagrees (see below)
  table$incoherent <- (table$tier == "unresolved") |
    ((table$tier == "provided") &
       (strong | n_parsing_mismatch >= min_mismatches))

  # summary_table ----
  # references that printed a DOI (tiers "provided" and "unresolved") are
  # checked; references that printed no DOI (tiers "crossref" and "none") are
  # listed so the user can add one. A DOI is suggested when the CrossRef
  # title search found a match that scored high enough to be trustworthy (a
  # low score is usually the wrong paper) and whose title agrees with the
  # cited title: a match with another title is another work. bibr 12.x
  # exports score their matches 0-1; a CrossRef score that low never passes
  # add_bib_match()'s minimum, so the scale can be read from the score itself.
  table$no_doi <- table$tier %in% c("crossref", "none")
  min_score <- ifelse(table$score %in% NA | table$score > 1,
                      suggest_score, suggest_score / 100)
  table$doi_suggested <- table$tier == "crossref" & !is.na(table$score) &
    table$score >= min_score & !blank(table$doi.match) &
    (table$title_agrees | table$title_starts_same)
  # does CrossRef's record have the cited title, whatever its score?
  cr_same_title <- table$tier == "crossref" & !blank(table$doi.match) &
    (table$title_agrees | table$title_starts_same)
  table$title_mismatch[table$tier == "crossref"] <- FALSE
  # A record with the cited title is compared with the citation when the
  # match is confident, or, below `suggest_score`, when the titles are almost
  # the same (a wrong year or author lowers CrossRef's score, so these matches
  # were neither compared nor suggested). Unless both are articles, only a
  # confident match is compared, and only on its authors: books and reports
  # have editions and reprints with the same title in other years and with
  # other series names. One that disagrees is flagged, with the record shown,
  # and not suggested; a DOI is not suggested either for a book or report
  # whose record has another year.
  article_set <- c("article", "journal_article", "inproceedings")
  article_pair <- (is.na(table$bib_type.match) | table$bib_type.match %in% article_set) &
    (is.na(table$bib_type.orig) | table$bib_type.orig %in% article_set)
  near_same <- !is.na(title_charsim) & title_charsim >= 0.9
  compared <- cr_same_title & article_pair & (table$doi_suggested | near_same)
  authors_compared <- cr_same_title & !article_pair & table$doi_suggested
  # a cited preprint whose match is a published version: authors only
  preprint_pub <- (compared | authors_compared) & cited_preprint &
    table$bib_type.match %in% article_set
  table$year_mismatch[preprint_pub] <- FALSE
  table$container_mismatch[preprint_pub] <- FALSE
  # (the title is not compared, so authors alone reach min_mismatches only at 1)
  nodoi_strong <- (table$year_mismatch %in% TRUE) | (table$container_mismatch %in% TRUE)
  nodoi_authors <- (table$author_mismatch %in% TRUE) & min_mismatches <= 1
  # a cited journal article whose same-title match is a preprint
  preprint_only <- cr_same_title & (table$doi_suggested | near_same) &
    journal_cited & table$bib_type.match %in% c("misc", "preprint")
  table$preprint_only <- preprint_only
  table$container_mismatch[preprint_only] <- TRUE
  table$incoherent <- table$incoherent | (compared & (nodoi_strong | nodoi_authors)) |
    (authors_compared & nodoi_authors) | preprint_only
  other_year <- table$year_mismatch %in% TRUE
  table$year_mismatch[authors_compared] <- FALSE
  table$container_mismatch[authors_compared] <- FALSE
  table$doi_suggested <- table$doi_suggested & !table$incoherent &
    !(!compared & other_year) & !preprint_pub
  pub <- preprint_pub & !table$incoherent
  table$published_doi[pub] <- table$doi.match[pub]
  # a year note stands only for a record that was compared
  note_record[!(table$tier %in% "provided" | compared) | preprint_pub] <- NA

  # A reference without a DOI whose title is not that of CrossRef's match is
  # searched by its title alone, in CrossRef (whose title search for
  # add_bib_match() also uses the authors and journal, and keeps a match only
  # above a minimum score, which short titles do not reach) and then in
  # DataCite (arXiv, Zenodo, OSF, data repositories), and then in Semantic
  # Scholar (conference papers without DOIs). The titles of the first five
  # records (Semantic Scholar's best match) are compared with the cited
  # title. A reference found in none is listed as not found: a work these
  # sources do not hold (a
  # book, a report, a web page), a title misread from the PDF, or a reference
  # that does not exist. Titles of fewer than three words, and references in
  # papers that were not looked up, are not searched.
  n_words <- lengths(strsplit(trimws(clean(table$title.orig)), "\\s+"))
  searched <- which(table$tier %in% c("crossref", "none") & !cr_same_title &
                      !blank(table$title.orig) & n_words >= 3 & looked_up)
  table$not_found <- FALSE
  table$search_failed <- FALSE
  search_named <- rep(FALSE, nrow(table))
  # For each title q[i], the first record with the same title (a row of
  # hits), NA when there is none, and NA_integer_ - 1 (-1) when the search
  # failed.
  title_found <- \(hits, q, text) {
    first <- rep(NA_integer_, length(q))
    first[unique(hits$query[hits$error])] <- -1L
    ok_rows <- which(!hits$error & !blank(hits$title))
    if (length(ok_rows)) {
      h <- hits[ok_rows, ]
      ok <- title_check(q[h$query], h$title, text[h$query])
      same <- ok_rows[ok$agrees | ok$starts_same]
      first[unique(hits$query[same])] <- same[!duplicated(hits$query[same])]
    }
    first
  }
  table$record_source <- ifelse(table$tier %in% c("provided", "crossref"),
                                dplyr::coalesce(table$service, "crossref"),
                                NA_character_)
  # the Semantic Scholar page of a record found there
  table$record_url <- NA_character_
  if (length(searched)) {
    # each title is searched once, and its result given to every reference
    # with that title (the same work cited twice, or in several papers)
    q_ref <- table$title.orig[searched]
    q <- unique(q_ref)
    qi <- match(q_ref, q)
    q_text <- table$text[searched][match(q, q_ref)]
    cr <- crossref_query(as.list(q), min_score = 0, rows = 5,
                         select = c("DOI", "title", "score", "author", "year", "type",
                                    "container-title"))
    cr <- if (is.null(cr$ref)) {
      # CrossRef could not be reached
      data.frame(query = seq_along(q), doi = NA_character_,
                 title = NA_character_, year = NA_integer_,
                 type = NA_character_, container = NA_character_, error = TRUE)
    } else {
      x <- data.frame(query = match(cr$ref, q), doi = cr$DOI %||% NA_character_,
                      title = cr$title %||% NA_character_,
                      year = suppressWarnings(as.integer(cr$year %||% NA)),
                      type = cr$type %||% NA_character_,
                      container = cr$`container-title` %||% NA_character_,
                      error = !is.na(cr$error %||% NA_character_))
      x$authors <- lapply(cr$author %||% vector("list", nrow(x)), \(a)
        if (is.data.frame(a)) structure(a$family, given = if ("given" %in% names(a)) a$given else rep(NA, nrow(a)))
        else NA_character_)
      x
    }
    first <- title_found(cr, q, q_text)
    rec <- data.frame(source = ifelse(first > 0, "crossref", NA),
                      doi = NA_character_, title = NA_character_, year = NA_integer_,
                      type = NA_character_, container = NA_character_,
                      url = NA_character_)
    rec$authors <- vector("list", nrow(rec))
    got <- which(first > 0)
    rec[got, c("doi", "title", "year", "type", "container")] <-
      cr[first[got], c("doi", "title", "year", "type", "container")]
    rec$authors[got] <- cr$authors[first[got]]
    # a title CrossRef could not be searched for is still searched in DataCite
    # "Family, Given; ..." names as surnames with their given names
    split_names <- \(a) {
      p <- trimws(strsplit(a, ";", fixed = TRUE)[[1]])
      structure(trimws(sub(",.*", "", p)),
                given = ifelse(grepl(",", p), trimws(sub("^[^,]*,", "", p)), NA))
    }
    rest <- which(is.na(first) | first < 0)
    if (length(rest)) {
      dc <- datacite_query(q[rest])
      for (col in c("doi", "title", "year", "authors", "type"))
        if (is.null(dc[[col]])) dc[[col]] <- rep(NA, nrow(dc))
      dfirst <- title_found(dc, q[rest], q_text[rest])
      # not found when neither search found it, failed when either failed
      first[rest] <- ifelse(is.na(dfirst) & first[rest] %in% -1L, -1L, dfirst)
      got <- which(dfirst > 0)
      rec$source[rest[got]] <- "datacite"
      rec[rest[got], c("doi", "title", "year", "type")] <- dc[dfirst[got], c("doi", "title", "year", "type")]
      rec$authors[rest[got]] <- lapply(dc$authors[dfirst[got]], split_names)
    }
    # a title found in neither is searched in Semantic Scholar, which holds
    # conference papers without DOIs; its requests are paced
    rest <- which(is.na(first) | first < 0)
    if (length(rest)) {
      s2 <- semanticscholar_query(q[rest])
      sfirst <- title_found(s2, q[rest], q_text[rest])
      first[rest] <- ifelse(is.na(sfirst) & first[rest] %in% -1L, -1L, sfirst)
      got <- which(sfirst > 0)
      rec$source[rest[got]] <- "semanticscholar"
      rec[rest[got], c("doi", "title", "year", "type", "container")] <-
        s2[sfirst[got], c("doi", "title", "year", "type", "venue")]
      rec$url[rest[got]] <- s2$url[sfirst[got]]
      rec$authors[rest[got]] <- lapply(s2$authors[sfirst[got]], split_names)
    }
    table$not_found[searched[is.na(first[qi])]] <- TRUE
    table$search_failed[searched[first[qi] %in% -1L]] <- TRUE
    rec <- rec[qi, , drop = FALSE]
    rec$i <- searched

    # A record found with the cited title is compared like CrossRef's
    # confident match: when its authors, year or (for a CrossRef journal
    # article) journal disagree, the reference is flagged with that record. Only an article is compared with an article
    # or a preprint of almost the same title: books, software, reports and
    # standard titles ("Dyadic data analysis") have editions, versions,
    # reprints, chapters and reviews with the same title by other authors
    # or in other years.
    rec <- rec[!is.na(rec$source), ]
    article_types <- c("journal-article", "proceedings-article", "posted-content",
                       "JournalArticle", "Conference", "Preprint")
    cited_type <- table$bib_type.orig[rec$i]
    a <- norm_title(table$title.orig[rec$i])
    b <- norm_title(rec$title)
    near_same <- vapply(seq_along(a), \(k)
      1 - utils::adist(a[k], b[k])[1, 1] / max(nchar(a[k]), nchar(b[k]), 1) >= 0.9,
      logical(1))
    rec <- rec[rec$type %in% article_types & near_same &
                 (is.na(cited_type) | cited_type %in% c("article", "journal_article", "inproceedings")), ]
    if (nrow(rec)) {
      i <- rec$i
      an <- split_swap(author_check(rec$authors, table$authors.orig[i], bibr[i],
                                    table$text[i], table$title.orig[i]))
      note <- an$note
      ydiff <- abs(table$year.orig[i] - rec$year)
      amis <- !is.na(note) & min_mismatches <= 1
      # a preprint and a published version of the work appear in different
      # years, and only the published version has a journal
      rec_preprint <- rec$type %in% c("posted-content", "Preprint") |
        grepl("^10\\.48550/", rec$doi, ignore.case = TRUE)
      # a cited preprint is not compared on its year with a published
      # version; a cited published version may appear up to a year more
      # than `year_tolerance` after its preprint
      pub_of_preprint <- !cited_preprint[i] & rec_preprint
      later <- table$year.orig[i] - rec$year
      # Semantic Scholar gives the year of a work's earliest version
      early <- pub_of_preprint | rec$source == "semanticscholar"
      ymis <- !is.na(ydiff) & ydiff > year_tolerance &
        !(cited_preprint[i] & !rec_preprint) &
        !(early & later > 0 & later <= year_tolerance + 1)
      ychk <- which(ymis & rec$source == "crossref")
      if (length(ychk)) {
        src <- year_source(rec$doi[ychk], as.integer(table$year.orig[i[ychk]]))
        ymis[ychk[!is.na(src)]] <- FALSE
        soft <- !is.na(src) & src != "published"
        table$year_note[i[ychk[soft]]] <- year_note_text(
          src[soft], table$year.orig[i[ychk[soft]]], rec$year[ychk[soft]])
        note_record[i[ychk[soft]]] <- rec$doi[ychk[soft]]
      }
      # DataCite records have no journal; Semantic Scholar's venue is its
      # full name ("International Conference on Machine Learning")
      cmis <- mapply(\(a, b, text, check) {
        check && !is.na(a) && !is.na(b) && nzchar(trimws(a)) && nzchar(trimws(b)) &&
          !journal_coherent(a, b, text)
      }, table$container.orig[i], rec$container, table$text[i],
      (rec$type %in% "journal-article" |
         (rec$source == "semanticscholar" & !rec$type %in% "Preprint")) &
        !article_number[i] & !cited_preprint[i],
      USE.NAMES = FALSE)
      pmis <- pub_of_preprint & journal_cited[i]
      flag <- amis | ymis | cmis | pmis
      named <- !is.na(an$swapped)
      table$name_note[i[named]] <- an$swapped[named]
      search_named[i[named]] <- TRUE
      note_record[i[named & is.na(note_record[i])]] <- rec$doi[named & is.na(note_record[i])]
      table$record_url[i[named]] <- rec$url[named]
      # a published version without a DOI (a conference paper) is not noted
      pub <- !flag & cited_preprint[i] & !rec_preprint & !is.na(rec$doi)
      table$published_doi[i[pub]] <- rec$doi[pub]
      if (any(flag)) {
        f <- i[flag]
        table$tier[f] <- "search"
        table$no_match[f] <- FALSE
        table$record_source[f] <- rec$source[flag]
        table$doi.match[f] <- rec$doi[flag]
        table$record_url[f] <- rec$url[flag]
        table$title.match[f] <- rec$title[flag]
        table$year.match[f] <- rec$year[flag]
        table$container.match[f] <- rec$container[flag]
        table$author_note[f] <- note[flag]
        table$author_mismatch[f] <- amis[flag]
        table$year_mismatch[f] <- ymis[flag]
        table$container_mismatch[f] <- cmis[flag] | pmis[flag]
        table$preprint_only[f] <- pmis[flag]
        table$doi_mismatch[f] <- FALSE
        table$incoherent[f] <- TRUE
      }
    }
  }
  # the field mismatches are those of flagged references, so that ref_summary
  # reports the same references as this module
  for (col in grep("_mismatch$", names(table), value = TRUE)) {
    table[[col]] <- table[[col]] %in% TRUE & table$incoherent &
      table$tier %in% c("provided", "crossref", "search")
  }
  table$author_note[!table$author_mismatch] <- NA_character_
  table$year_note[is.na(note_record)] <- NA_character_
  table$name_note[!(table$tier %in% "provided" | compared | authors_compared |
                      search_named)] <- NA_character_
  summary_table <- dplyr::summarise(table,
    .by = paper_id,
    refs_checked  = sum(tier %in% c("provided", "unresolved"), na.rm = TRUE),
    incoherent    = sum(incoherent, na.rm = TRUE),
    no_doi        = sum(no_doi, na.rm = TRUE),
    doi_suggested = sum(doi_suggested, na.rm = TRUE),
    not_found     = sum(not_found, na.rm = TRUE),
    unreadable    = sum(tier == "unreadable", na.rm = TRUE)
  )

  # summary_text
  n_checked  <- sum(summary_table$refs_checked)
  n_inc      <- sum(table$incoherent & !table$tier %in% c("crossref", "search"))
  n_inc_nodoi <- sum(table$incoherent & table$tier %in% c("crossref", "search"))
  n_nodoi    <- sum(summary_table$no_doi)
  n_suggest  <- sum(summary_table$doi_suggested)
  n_unread   <- sum(summary_table$unreadable)
  n_unlooked <- sum(table$tier == "not_checked")
  n_reg      <- sum(table$tier == "registered")
  n_unconf   <- sum(table$tier == "unconfirmed")
  n_nf       <- sum(table$not_found)
  n_sfail    <- sum(table$search_failed)
  n_pub      <- sum(!is.na(table$published_doi))
  n_ynote    <- sum(!is.na(table$year_note))
  n_nnote    <- sum(!is.na(table$name_note))
  summary_text <- paste0(
    if (!any(looked_up))
      "The references were not looked up at Crossref, so their accuracy was not checked."
    else sprintf(
      "We checked the %d reference%s that printed a DOI and found %d incoherent reference%s.%s",
      n_checked, plural(n_checked), n_inc, plural(n_inc),
      if (n_inc > 0) " Most are errors in reading the PDF, but check each against the original source." else ""),
    sprintf(" %d reference%s had no DOI%s.",
            n_nodoi, plural(n_nodoi),
            if (n_suggest > 0) sprintf("; the report suggests a DOI for %d of them", n_suggest) else ""),
    if (n_nf > 0) sprintf(" No work with the cited title was found in CrossRef, DataCite or Semantic Scholar for %d of them; check that %s.",
                          n_nf, if (n_nf == 1) "it exists" else "they exist") else "",
    if (n_sfail > 0) sprintf(" The title search failed for %d of them, so %s not checked; run the module again.",
                             n_sfail, if (n_sfail == 1) "it was" else "they were") else "",
    if (n_inc_nodoi > 0) sprintf(" For %d reference%s without a DOI, a title search found a work with the same title whose authors, journal or year differ from the citation; %s listed with the incoherent references.",
                                 n_inc_nodoi, plural(n_inc_nodoi),
                                 if (n_inc_nodoi == 1) "it is" else "they are") else "",
    if (n_pub > 0) sprintf(" %d cited preprint%s %s a published version.",
                           n_pub, plural(n_pub), if (n_pub == 1) "has" else "have") else "",
    if (n_ynote > 0) sprintf(" %d cited year%s %s the year the record was created or accepted, not published.",
                             n_ynote, plural(n_ynote), if (n_ynote == 1) "is" else "are") else "",
    if (n_nnote > 0) sprintf(" %d reference%s cite%s an author with given and family names swapped, or the record does.",
                             n_nnote, plural(n_nnote), if (n_nnote == 1) "s" else "") else "",
    if (n_unread > 0) sprintf(" %d entr%s could not be read reliably from the PDF and %s listed in the report.",
                              n_unread, if (n_unread == 1) "y" else "ies",
                              if (n_unread == 1) "is" else "are") else "",
    if (n_reg > 0)
      sprintf(" %d cited DOI%s %s registered, but no record was retrieved for %s, so %s not checked.",
              n_reg, plural(n_reg), if (n_reg == 1) "is" else "are",
              if (n_reg == 1) "it" else "them",
              if (n_reg == 1) "the reference was" else "the references were") else "",
    if (n_unconf > 0)
      sprintf(" %d cited DOI%s had no record, and doi.org could not be reached to ask whether %s, so %s not checked.",
              n_unconf, plural(n_unconf),
              if (n_unconf == 1) "it exists" else "they exist",
              if (n_unconf == 1) "the reference was" else "the references were") else "",
    if (n_unlooked > 0 && any(looked_up))
      sprintf(" %d reference%s with a DOI %s not checked, because %s paper was not looked up at Crossref.",
              n_unlooked, plural(n_unlooked),
              if (n_unlooked == 1) "was" else "were",
              if (n_unlooked == 1) "its" else "their") else ""
  )

  # traffic_light ----
  # nothing to check when no reference supplied a DOI. Reading problems are
  # listed but do not change the light.
  tl <- if (any(table$incoherent %in% TRUE)) "yellow" else if (n_checked == 0) "na" else "green"

  guidance <- "Check each flagged reference against the original source. A flag may come from an error in reading the PDF, a citation mistake, or an AI-generated reference."

  if (n_inc + n_inc_nodoi == 0) guidance <- ""

  # report ----

  # text for the report: HTML special characters escaped (a SICI DOI such as
  # "...<183::AID-BDM318>..." would be read as a tag), white space collapsed
  # (CrossRef titles can hold line breaks)
  esc <- \(x) {
    x <- gsub("&amp;", "&", as.character(x), fixed = TRUE)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", gsub(">", "&gt;", x, fixed = TRUE), fixed = TRUE)
    trimws(gsub("\\s+", " ", x))
  }
  # the reference as printed; a reference without text (a bibr 12.x export
  # can have none) is shown by its parsed details
  ref_text <- \(r) ifelse(is.na(r$text),
    paste0(r$authors.orig, " (", r$year.orig, "). ", r$title.orig, ". ", r$container.orig),
    r$text)

  # for one reference, build the "what is wrong" cell: each mismatching field is
  # shown as the cited value struck through in red followed by the value from
  # the record, so the discrepancy is visible at a glance.
  strike <- function(x) paste0(
    "<span style=\"color:#c00;text-decoration:line-through\">", esc(x), "</span>")
  correction <- function(label, cited, record) {
    if (is.na(cited) || !nzchar(as.character(cited))) cited <- "(missing)"
    sprintf("<b>%s:</b> %s &rarr; %s", label, strike(cited), esc(record))
  }
  discrepancies <- function(r) {
    # an unresolved cited DOI has no record to compare against
    if (r$tier == "unresolved") {
      return(sprintf(
        "<b>DOI:</b> the cited DOI %s %s",
        strike(r$doi.orig),
        if (isFALSE(r$doi_exists)) "does not exist (doi.org)" else "could not be found"))
    }
    parts <- c(
      if (r$tier == "crossref")
        "No DOI cited; the work with the same title differs:",
      if (r$tier == "search")
        sprintf("No DOI cited; the work with the same title in %s differs:",
                switch(r$record_source, datacite = "DataCite",
                       semanticscholar = "Semantic Scholar", "CrossRef")),
      if (isTRUE(r$title_mismatch))
        correction("title", r$title.orig, r$title.match),
      # the record surnames that are missing, rather than the whole list
      if (isTRUE(r$author_mismatch))
        sprintf("<b>authors:</b> %s", esc(r$author_note)),
      if (isTRUE(r$preprint_only))
        sprintf("<b>journal:</b> cited in %s, but only a preprint was found",
                esc(r$container.orig))
      else if (isTRUE(r$container_mismatch))
        correction("journal", r$container.orig, r$container.match),
      if (isTRUE(r$year_mismatch))
        correction("year", r$year.orig, r$year.match),
      if (isTRUE(r$doi_mismatch))
        correction("DOI", r$doi.orig, r$doi.match)
    )
    paste(parts, collapse = "<br>")
  }

  # a record's DOI, or its Semantic Scholar page when it has none
  record_link <- \(doi, url) ifelse(
    !is.na(doi) & nzchar(doi),
    link(paste0("https://doi.org/", doi_clean(doi)), esc(doi)),
    ifelse(is.na(url), "", link(url, "Semantic Scholar")))

  ## incoherent references ----
  inc_rows <- table[table$incoherent %in% TRUE, ]
  incoherent_report <- NULL
  if (nrow(inc_rows) > 0) {
    # link to the retrieved record; for an unresolved DOI there is no record, so
    # show the cited (non-resolving) DOI instead
    rec_doi <- ifelse(is.na(inc_rows$doi.match) | !nzchar(inc_rows$doi.match),
                      inc_rows$doi.orig, inc_rows$doi.match)
    out <- data.frame(
      Reference = esc(ref_text(inc_rows)),
      `What is wrong (cited → record)` =
        vapply(seq_len(nrow(inc_rows)), \(i) discrepancies(inc_rows[i, ]),
               character(1)),
      # a cited DOI written as a URL is cleaned for the link target only
      Record = record_link(rec_doi, inc_rows$record_url),
      check.names = FALSE
    )
    incoherent_report <- scroll_table(out, 5, colwidths = c(.45, .4, .15))
  }

  ## cited DOIs that are aliases of the record's DOI ----
  alias_rows <- table[table$doi_alias %in% TRUE, ]
  alias_report <- NULL
  if (nrow(alias_rows) > 0) {
    out <- data.frame(
      Reference = esc(ref_text(alias_rows)),
      `Cited DOI` = esc(alias_rows$doi.orig),
      `Current DOI` = link(paste0("https://doi.org/", alias_rows$doi.match),
                           esc(alias_rows$doi.match)),
      check.names = FALSE
    )
    alias_report <- scroll_table(out, 5, colwidths = c(.6, .2, .2))
  }

  ## registered DOIs without a record ----
  reg_rows <- table[table$tier %in% c("registered", "unconfirmed"), ]
  reg_report <- NULL
  if (nrow(reg_rows) > 0) {
    out <- data.frame(
      Reference = esc(ref_text(reg_rows)),
      DOI = link(paste0("https://doi.org/", doi_clean(reg_rows$doi.orig)),
                 esc(reg_rows$doi.orig)),
      `Registered with` = ifelse(reg_rows$tier == "unconfirmed",
                                 "unknown (doi.org could not be reached)",
                                 reg_rows$doi_ra),
      check.names = FALSE
    )
    reg_report <- scroll_table(out, 5, colwidths = c(.6, .25, .15))
  }

  ## entries that could not be read reliably ----
  unread_rows <- table[table$tier == "unreadable", ]
  unread_report <- NULL
  if (nrow(unread_rows) > 0) {
    out <- data.frame(
      Entry = esc(ref_text(unread_rows)),
      Problem = unread_rows$read_problem,
      check.names = FALSE
    )
    unread_report <- scroll_table(out, 5, colwidths = c(.6, .4))
  }

  ## references found in no registry ----
  nf_rows <- table[table$not_found, ]
  nf_report <- NULL
  if (nrow(nf_rows) > 0) {
    out <- data.frame(Reference = esc(ref_text(nf_rows)), check.names = FALSE)
    nf_report <- scroll_table(out, 5)
  }

  ## preprints with a published version, years of another date, swapped names ----
  note_rows <- which(!is.na(table$published_doi) | !is.na(table$year_note) |
                       !is.na(table$name_note))
  notes_report <- NULL
  if (length(note_rows)) {
    r <- table[note_rows, ]
    rec_doi <- dplyr::coalesce(r$published_doi, note_record[note_rows], r$doi.match)
    notes <- vapply(seq_len(nrow(r)), \(j) paste(c(
      if (!is.na(r$published_doi[j])) "Cites a preprint; a published version was found.",
      if (!is.na(r$year_note[j])) paste0("Year: ", esc(r$year_note[j]), "."),
      if (!is.na(r$name_note[j])) paste0("Authors: ", esc(r$name_note[j]), ".")),
      collapse = "<br>"), "")
    out <- data.frame(
      Reference = esc(ref_text(r)),
      Note = notes,
      Record = record_link(rec_doi, r$record_url),
      check.names = FALSE
    )
    notes_report <- scroll_table(out, 5, colwidths = c(.5, .3, .2))
  }

  ## references without a DOI (could not be checked) ----
  # (those flagged above are listed there, and preprints with a published
  # version in the notes)
  nodoi_rows <- table[table$no_doi %in% TRUE & !table$incoherent & !table$not_found &
                        is.na(table$published_doi), ]
  nodoi_report <- NULL
  if (nrow(nodoi_rows) > 0) {
    sugg <- nodoi_rows$doi_suggested
    # the record a suggested DOI points to, so that it can be compared with
    # the citation before it is added
    record <- sprintf("%s (%s). <i>%s</i>", esc(nodoi_rows$title.match),
                      nodoi_rows$year.match, esc(nodoi_rows$container.match))
    record <- gsub(" (NA)", "", gsub(" <i>NA</i>", "", record, fixed = TRUE), fixed = TRUE)
    out <- data.frame(
      Reference = esc(ref_text(nodoi_rows)),
      `Suggested DOI` = ifelse(
        sugg,
        paste0(link(paste0("https://doi.org/", nodoi_rows$doi.match),
                    esc(nodoi_rows$doi.match)), "<br>", record),
        ""),
      check.names = FALSE
    )
    # suggestions first
    out <- out[order(!sugg), , drop = FALSE]
    nodoi_report <- scroll_table(out, 5, colwidths = c(.6, .4))
  }

  report <- c(
    guidance,
    if (!is.null(incoherent_report))
      c("### Incoherent references\n",
        "These references cite a DOI that does not exist, or details that differ from the record. For a reference without a DOI, the record is a work with the same title whose authors, journal or year differ; its DOI is not suggested.\n",
        incoherent_report),
    if (!is.null(notes_report))
      c("### Preprints, years and names to check\n",
        "These references are not flagged, but differ from the record. A cited preprint has a published version, which a reader may prefer to cite. A cited year is the year in which the record was created or the work accepted, not the year it was published. An author's given and family names are swapped in the citation or in the record.\n",
        notes_report),
    if (!is.null(alias_report))
      c("### DOIs that have a newer form\n",
        "These references cite a DOI that the registry lists as an alias of another DOI, for example after the journal moved to a new publisher. The cited DOI still leads to the right work, so this is not an error; the DOI the registry now uses is given for reference.\n",
        alias_report),
    if (!is.null(reg_report))
      c("### DOIs that could not be checked\n",
        "No record was retrieved for these cited DOIs, so the references were not checked. For a DOI registered with Crossref the lookup probably failed: run `add_bib_match()` again. `add_bib_match()` looks up Crossref records only, so DOIs of other registration agencies, such as DataCite, are not checked. When doi.org could not be reached, it is not known whether the DOI exists: run the check again.\n",
        reg_report),
    if (!is.null(unread_report))
      c("### Entries that could not be read reliably\n",
        "These entries were not read correctly from the PDF, so they were not checked. This is usually a limitation of the PDF reading, not an error in the reference list.\n",
        unread_report),
    if (!is.null(nf_report))
      c("### References not found\n",
        "These references have no DOI, and no work with the cited title was found in CrossRef, DataCite (which includes arXiv, Zenodo and OSF) or Semantic Scholar (which includes conference papers without DOIs). Books, reports, theses, software and web pages are often missing from these sources, and a title misread from the PDF is not found either. For a journal article or a preprint, check the title and that the work exists.\n",
        nf_report),
    if (!is.null(nodoi_report))
      c("### References without a DOI\n",
        "Where a CrossRef title search found a confident match with the same title, and the comparison found no disagreement, its DOI is suggested with the record it points to: check that it is the cited work before adding it. The retraction, PubPeer and replication checks also use the DOI CrossRef found, so for these references they are only as reliable as that search. Adding a DOI where one exists makes the cited work easier to find and verify.\n",
        nodoi_report)
  )

  # return a list ----
  list(
    table = table,
    summary_table = summary_table,
    na_replace = 0,
    traffic_light = tl,
    report = report,
    summary_text = summary_text
  )
}

