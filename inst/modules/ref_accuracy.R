#' Reference Accuracy
#'
#' @description
#' This module checks whether each reference with a DOI is internally coherent: it compares the details the paper cites for a reference against the authoritative record that the reference's DOI points to, and flags any reference whose cited details do not match. For a reference without a DOI, it suggests the DOI of a work with the same title, or flags the reference when that work's authors, journal or year differ.
#'
#' @details
#' This module looks for *incoherent* references: a reference is incoherent when the title, authors, journal, or year that the paper cites disagree with the record that the reference's own DOI points to. This is often an error in reading the reference list from the PDF, but the module also finds mistakes in citations and can point out AI-generated references. You will need to check the original source.
#'
#' The module uses the `bib_match` table, which holds the metadata retrieved from CrossRef for each reference (added or refreshed with `add_bib_match()`, which makes live network calls).
#'
#' **Only references that supply their own DOI are checked.** For these, we compare what the paper cites field by field against the record found for that DOI. `add_bib_match()` looks up a cited DOI directly when it is valid as printed; a DOI that is not (for example one broken by a space from the PDF) is matched by a title search instead. A DOI printed in the reference text that the PDF reader did not take as the reference's DOI (a link with "%2F" for "/", or a malformed DOI such as "doi.org/1073191116659134") counts as the cited DOI when it is the DOI the title search found, apart from lost punctuation or prefix; a malformed one is then a DOI mismatch. A cited DOI with no record at all is flagged as a DOI that could not be found: `bib_match` does not record why a lookup found nothing, so this includes lookups that failed for network reasons (`add_bib_match()` reports those when it runs) and DOIs registered outside CrossRef. References in papers that were not looked up at all are not checked. References without a DOI are listed separately, with a recommendation to add a DOI where one exists. The only record for them comes from a CrossRef title search, which often returns the wrong paper, so they are compared only with a high-confidence match (controlled by `suggest_score`) whose title agrees with the cited title. When that match's authors, journal or year disagree with the citation (by the rules below), the reference is flagged with the match, and its DOI is not suggested: the citation may be wrong, the match may be another version of the work (an abstract or a reprint), or an AI-generated reference may borrow a real title. Otherwise its DOI is suggested, and the report shows the record it points to.
#'
#' Entries that were not read correctly from the PDF are listed separately and not compared: two references read as one entry (a second APA author-year start, as in "... Bar, M. (2004). ..."), an entry of which only the DOI was read, and a reference whose printed DOI was not read and so not looked up. When only the DOI was read and the entry before it has no DOI but its title search found that DOI, the DOI is given to that reference. These entries do not change the traffic light.
#'
#' For each checked reference we compare five fields against the DOI's record (for a reference without a DOI, the authors, journal and year):
#'
#' - **DOI** — flagged only when the reference printed a DOI that differs from the record (a blank cited DOI is never a mismatch). DOIs are compared after removing URL wrappers (`https://doi.org/`, journal article URLs), spaces and trailing punctuation left by the PDF, and the old double slash after the prefix (`10.1037//`). When the record was found by looking up the cited DOI (it has no search score), a record with a different DOI means the registry lists the cited DOI as an alias (for example after a journal moved publisher); this is reported as a note with the current DOI, not as an incoherence. A DOI mismatch is therefore only flagged when the record came from a title search. Papers read from bibr 12.x exports do not record how a record was found, so for them a different DOI is always a mismatch.
#' - **Year** — flagged when the cited year is more than `year_tolerance` years from the record (online-first and print years routinely differ by one year, so this is allowed by default).
#' - **Journal** — flagged when the cited journal disagrees with the record. Journal names are matched tolerantly: standard ISO-4 abbreviations (e.g. "J. Pers. Soc. Psychol." for "Journal of Personality and Social Psychology"), "&"/"and", "the", "WIREs" for "Wiley Interdisciplinary Reviews", an acronym before the full name ("MMWR. Morbidity and Mortality Weekly Report"), and British and American spellings ("Behaviour" and "Behavior") are treated as equivalent. The words of the shorter name must appear in order in the longer one, starting with its first word, so a subtitle or section may be left out, but a name that starts inside another is another journal ("Psychological Science" is not "Current Directions in Psychological Science"), and a one-word name must match the other name exactly ("Nature" is not "Nature Neuroscience"). Words that the parsed journal lost are accepted when the record's name is in the reference text ("Perception, & Psychophysics" for "Attention, Perception, & Psychophysics"), also when a word in it is hyphenated at a line break. A name that continues another is still accepted ("Journal of Experimental Psychology" for "Journal of Experimental Social Psychology"). The journal is only compared when the record is a journal article: for book chapters, proceedings and reports the registry often gives a series or platform name ("Oxford Handbooks Online"). A cited "journal" that is an article number ("Article e17018"), which comes from reading the PDF, is not compared either.
#' - **Title** — flagged when the cited title is too different from the record's title, judged by character-level similarity (`title_similarity`) after stripping case, punctuation, footnote markers and diacritics. This ignores cosmetic differences (colons, question marks, em-dash spacing, line-break word splits), but also a change of one or two words in a long title. A title is also accepted when the record's title appears in the reference text as whole words ending at a title delimiter, for references whose title was not read correctly from the PDF. A title that begins with the other one followed by a title delimiter (":", "?", "." or "!") is accepted, because the record or the citation often holds only the main title; the subtitle is then not checked. A translated title in square brackets, as APA gives for a work in another language, is compared too.
#' - **Authors** — flagged when the leading author surnames (the first `max_authors`) from the record are not all present in the cited author list, or when the record's first author is not cited first. Only the leading authors are required because author lists are routinely truncated with "et al.". The cited authors are read one person at a time, and each record surname must equal one cited surname, compared on its letters only, so diacritics, spacing and case are ignored ("Gredebäck" and "Gredeback", "Le Doux" and "LeDoux" match). When one of the two is a single word, it may also match the other's last word, for shortened compound surnames and particles ("Vafaei Shooshtari" cited as "Shooshtari", "Gelder" cited as "De Gelder"); the last word is also taken after a hyphen or an elided particle ("Purdie-Vaughns" cited as "Vaughns", "O'Connell" read from the PDF as "Connell"). A cited name without a comma is read as given name first, and the record surname must equal its last word or words. Papers read from bibr 12.x exports keep each author list as printed ("Adam, H., Shirako, A., & Maddux, W. W"), so for them each record surname must equal one or more consecutive whole words of the list, with the same tolerance for compound surnames. A reference whose authors could not be read is not flagged. Extra cited authors after the first and given names are not checked. A cited list truncated with "et al." before `max_authors` authors is flagged, which affects citation styles that truncate early.
#'
#' A mismatched DOI, journal or year flags a reference on its own. Title and author mismatches are governed by `min_mismatches`: the default (1) flags a reference when either the title or the authors disagree. For a reference without a DOI the title is not compared, so its authors alone flag it only at the default. In the validation below, all genuine author errors were single author mismatches, so `min_mismatches = 2` removed them while keeping most flags that were not errors; it is not recommended.
#'
#' The report lists each incoherent reference with the specific cited value struck through and the record's value beside it, or the record's author surnames missing from the citation, so the discrepancy is visible at a glance.
#'
#' <validation>In an evaluation on 30 randomly sampled Psychological Science papers (October 2026; 1,269 references, 556 of which printed their own DOI), the module flagged 8 of the references that printed a DOI, in 6 papers (1.4%). Checked by hand, 5 were citation errors: a misspelled and a wrong author name ("Bernsten" for Berntsen, "Lund" for Yund), and three printed DOIs that do not work ("doi.org/1073191116659134" without its prefix, "doi.org/101016/jcomppsych201006008" without its dots, and "10.1037//0033-2909.1261.7" for 10.1037//0033-2909.126.1.78; all three appear so in the reference lists the publishers deposited at CrossRef). 1 was unclear (a diacritic in "Teder-Sälejärvi"). 2 were not errors: an online-first year two years before the print year, and a data DOI registered with DataCite rather than CrossRef, which therefore could not be found (the DataCite lookup in `add_bib_match()` now finds it). Among the 706 references that printed no DOI, CrossRef found a confident match with the same title for 518; for 508 its DOI is suggested, and 10 were flagged because the match disagrees. Checked by hand, 5 were citation errors (four misspelled author names, such as "Sonuga-Burke" for Sonuga-Barke, and "Nature Neuroscience Reviews" for Nature Reviews Neuroscience), 1 was a different version of the work (the 1897 abstract in the Proceedings of the Royal Society of a 1898 Philosophical Transactions paper, whose DOI would have been suggested before), 1 was unclear (a compound surname cited by its first part), and 3 were not errors (authors misread from the PDF, an online-first year, and a journal that has since been renamed). At min_mismatches = 2, the 9 author flags drop, leaving 9 flags, 4 of them errors. A further 6 entries were two references read as one and were listed as not read reliably. A flag should be read as "check this reference against the original source", not as a confirmed error. This evaluation cannot show how many citation errors the module misses. The package tests change one field of a correct reference at a time and check that each change is flagged, and record known misses (a one-word change in a long title, a cited journal name that continues the record's), but that does not establish a detection rate for real errors. </validation>
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
#' @returns report list
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
  bib_match <- bib_match[order(-bib_match$score), , drop = FALSE]
  bib_match <- bib_match[!duplicated(bib_match[, c("paper_id", "bib_id")]), , drop = FALSE]
  ref_table <- ref_table[!duplicated(ref_table[, c("paper_id", "bib_id")]), , drop = FALSE]
  # left join so every reference is kept, including those with no CrossRef
  # record. A reference that printed a DOI which does not resolve produces no
  # bib_match row; an inner join would silently drop it (and lose its cited
  # DOI), mislabelling it as a reference without a DOI.
  # The CrossRef relevance score comes along: only a title search gives one.
  table <- dplyr::left_join(
    bib[, cols], bib_match[, c(cols, "score")],
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
    m <- gsub("%2F", "/", m, ignore.case = TRUE)
    sub("[.,;]+$", "", sub("(?i)^.*?(doi\\.org/|doi:\\s*)", "", m, perl = TRUE))
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
  # Spaces and trailing punctuation from the PDF ("10.1037/0003-066x.54.6.4 08",
  # "...408.") are dropped too.
  norm_doi <- \(x) {
    x <- sub("[.,;]+$", "", gsub("[[:space:]]+", "", doi_clean(x)))
    tolower(sub("^(10\\.\\d+)//", "\\1/", x))
  }
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
    x <- gsub("[^a-z0-9]", "", x)                 # keep only alphanumerics
    x
  }
  table$title_mismatch <- {
    a <- norm_title(table$title.orig)
    b <- norm_title(table$title.match)
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
    clean_text <- clean(table$text)
    match_clean <- clean(table$title.match)
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
    cited_d <- delimited(table$title.orig)
    record_d <- delimited(table$title.match)
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
    }, ifelse(is.na(table$title.orig), "", table$title.orig), b, USE.NAMES = FALSE)

    # For a suggested DOI, a title that only adds or drops words at the end
    # (a subtitle without its colon, a footnote CrossRef appended to the
    # title) is close enough: the suggestion is checked by the user.
    table$title_starts_same <- mapply(\(x, y) {
      if (is.na(x) || is.na(y)) return(FALSE)
      short <- if (nchar(x) < nchar(y)) x else y
      nchar(short) >= 20 && startsWith(if (nchar(x) < nchar(y)) y else x, short)
    }, a, b, USE.NAMES = FALSE)

    !is.na(charsim) & charsim < title_similarity & !in_text & !main_title &
      !translated
  }

  # author check: do the leading author surnames from the retrieved record
  # appear in the cited author list, and is the record's first author cited
  # first? Only the first `max_authors` are required, because author lists are
  # commonly truncated with "et al." (and GROBID often drops the tail of long
  # lists), so a missing trailing author is not evidence of an incoherent
  # citation. Diacritics are ignored (handled by clean()).
  last_names <- lapply(table$authors.match, \(a) {
    tryCatch({
      if (is.data.frame(a)) {
        a$family
      } else {
        names <- strsplit(a, "; ")[[1]]
        sapply(names, \(x) strsplit(x, ", ")[[1]][[1]])
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
         # "Alice Brown Jones" ends in "jones", "brownjones", ...
         ends = lapply(family, \(f) {
           w <- letters_only(strsplit(f, "[[:space:] ]+")[[1]])
           w <- w[nzchar(w)]
           vapply(seq_along(w), \(k) paste(utils::tail(w, k), collapse = ""), "")
         }))
  }
  # which cited people does record surname x match?
  person_matches <- \(x, cs) {
    full <- letters_only(x)
    last <- last_part(x)
    record_one_word <- !grepl("[[:space:] ]", trimws(x))
    cs$name == full |
      (cs$one_word & cs$name == last) |
      (record_one_word & !cs$given_first & cs$last == full) |
      (cs$given_first & vapply(cs$ends, \(e) full %in% e, logical(1)))
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
  # for each reference, a note on what disagrees, or NA
  table$author_note <- mapply(\(l, o, as_printed) {
    if (length(l) == 0 || all(is.na(l))) return(NA_character_)  # nothing to check
    # no cited authors were read from the reference: unknown, not a mismatch
    if (length(o) == 0 || all(is.na(o)) || !nzchar(trimws(paste(o, collapse = ""))))
      return(NA_character_)
    first <- if (!is.na(l[1]) && nzchar(letters_only(l[1]))) l[1] else NA
    l <- utils::head(l[!is.na(l) & nzchar(letters_only(l))], max_authors)
    o <- paste(o, collapse = "; ")
    if (as_printed) {
      w <- printed_words(o)
      found <- vapply(l, \(x) words_match(x, w), logical(1))
      first_ok <- is.na(first) || words_match(first, printed_words(sub(",.*", "", o)))
    } else {
      cs <- cited_surnames(o)
      found <- vapply(l, \(x) any(person_matches(x, cs)), logical(1))
      first_ok <- is.na(first) || !length(cs$name) || person_matches(first, cs)[1]
    }
    note <- c(
      if (!all(found)) sprintf("%s not found among the cited authors",
                               paste(l[!found], collapse = ", ")),
      if (all(found) && !first_ok) sprintf("the first author is %s", first))
    if (length(note)) note else NA_character_
  }, last_names, table$authors.orig, bibr, USE.NAMES = FALSE)
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
  #                 found nothing.
  #  "not_checked" - the reference printed a DOI, but its paper has no
  #                 bib_match rows at all: it was not looked up.
  #  "crossref"   - the reference had no DOI and CrossRef supplied one via fuzzy
  #                 title/author search; the match may be wrong, so it is only
  #                 compared when its title agrees and the search was confident.
  #  "none"       - no DOI at all.
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
    (!table$title_mismatch | table$title_starts_same)
  # a would-be suggestion whose record disagrees with the citation is flagged,
  # with the record shown, and not suggested
  table$title_mismatch[table$tier == "crossref"] <- FALSE
  # (the title is not compared, so authors alone reach min_mismatches only at 1)
  nodoi_strong <- (table$year_mismatch %in% TRUE) | (table$container_mismatch %in% TRUE)
  nodoi_authors <- (table$author_mismatch %in% TRUE) & min_mismatches <= 1
  table$incoherent <- table$incoherent |
    (table$doi_suggested & (nodoi_strong | nodoi_authors))
  table$doi_suggested <- table$doi_suggested & !table$incoherent
  # the field mismatches are those of flagged references, so that ref_summary
  # reports the same references as this module
  for (col in grep("_mismatch$", names(table), value = TRUE)) {
    table[[col]] <- table[[col]] %in% TRUE & table$incoherent &
      table$tier %in% c("provided", "crossref")
  }
  table$author_note[!table$author_mismatch] <- NA_character_
  summary_table <- dplyr::summarise(table,
    .by = paper_id,
    refs_checked  = sum(tier %in% c("provided", "unresolved"), na.rm = TRUE),
    incoherent    = sum(incoherent, na.rm = TRUE),
    no_doi        = sum(no_doi, na.rm = TRUE),
    doi_suggested = sum(doi_suggested, na.rm = TRUE),
    unreadable    = sum(tier == "unreadable", na.rm = TRUE)
  )

  # summary_text
  n_checked  <- sum(summary_table$refs_checked)
  n_inc      <- sum(table$incoherent & table$tier != "crossref")
  n_inc_nodoi <- sum(table$incoherent & table$tier == "crossref")
  n_nodoi    <- sum(summary_table$no_doi)
  n_suggest  <- sum(summary_table$doi_suggested)
  n_unread   <- sum(summary_table$unreadable)
  n_unlooked <- sum(table$tier == "not_checked")
  summary_text <- paste0(
    if (!any(looked_up))
      "The references were not looked up at Crossref, so their accuracy was not checked."
    else sprintf(
      "We checked the %d reference%s that supplied a DOI against the record that DOI points to, and found %d incoherent reference%s to check for reading errors or mistakes.%s",
      n_checked, plural(n_checked), n_inc, plural(n_inc),
      if (n_inc > 0) " Incoherent references are often errors in reading the PDF (we are working on improving reference parsing)." else ""),
    sprintf(" %d reference%s had no DOI%s.",
            n_nodoi, plural(n_nodoi),
            if (n_suggest > 0) sprintf("; for %d of them CrossRef found a likely DOI, suggested in the report", n_suggest) else ""),
    if (n_inc_nodoi > 0) sprintf(" For %d reference%s without a DOI, CrossRef found a work with the same title whose authors, journal or year differ from the citation; %s listed with the incoherent references.",
                                 n_inc_nodoi, plural(n_inc_nodoi),
                                 if (n_inc_nodoi == 1) "it is" else "they are") else "",
    if (n_unread > 0) sprintf(" %d entr%s could not be read reliably from the PDF and %s listed in the report.",
                              n_unread, if (n_unread == 1) "y" else "ies",
                              if (n_unread == 1) "is" else "are") else "",
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

  guidance <- "For the references below, either the cited DOI could not be found, or one or more of the cited details (title, authors, journal, or year) does not match the record of the cited DOI or, for a reference without a DOI, of the work with the same title. This is often an error in reading the reference from the PDF, but it could be a citation mistake, or an AI-generated reference. Check each against the original source."

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
        "<b>DOI:</b> the cited DOI %s could not be found",
        strike(r$doi.orig)))
    }
    parts <- c(
      if (r$tier == "crossref")
        "No DOI cited; the work with the same title differs:",
      if (isTRUE(r$title_mismatch))
        correction("title", r$title.orig, r$title.match),
      # the record surnames that are missing, rather than the whole list
      if (isTRUE(r$author_mismatch))
        sprintf("<b>authors:</b> %s", esc(r$author_note)),
      if (isTRUE(r$container_mismatch))
        correction("journal", r$container.orig, r$container.match),
      if (isTRUE(r$year_mismatch))
        correction("year", r$year.orig, r$year.match),
      if (isTRUE(r$doi_mismatch))
        correction("DOI", r$doi.orig, r$doi.match)
    )
    paste(parts, collapse = "<br>")
  }

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
      Record = link(paste0("https://doi.org/", doi_clean(rec_doi)), esc(rec_doi)),
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

  ## references without a DOI (could not be checked) ----
  # (those flagged above are listed there)
  nodoi_rows <- table[table$no_doi %in% TRUE & !table$incoherent, ]
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
        "The DOI of these references could not be found, or their cited details do not match the record their DOI points to. A reference without a DOI is listed here when a work with the same title differs from it; its DOI is not suggested.\n",
        incoherent_report),
    if (!is.null(alias_report))
      c("### DOIs that have a newer form\n",
        "These references cite a DOI that the registry lists as an alias of another DOI, for example after the journal moved to a new publisher. The cited DOI still leads to the right work, so this is not an error; the DOI the registry now uses is given for reference.\n",
        alias_report),
    if (!is.null(unread_report))
      c("### Entries that could not be read reliably\n",
        "These entries were not read correctly from the PDF, so they were not checked. This is usually a limitation of the PDF reading, not an error in the reference list.\n",
        unread_report),
    if (!is.null(nodoi_report))
      c("### References without a DOI\n",
        "These references have no DOI. Where a CrossRef title search found a confident match with the same title, and its authors, journal and year agree with the citation, its DOI is suggested with the record it points to: check that it is the same work before adding it. The other reference checks (retraction, PubPeer, and replication) use the DOI CrossRef found, so for these references they are only as reliable as that search. We recommend adding a DOI to every reference that has one: it makes each cited work easier to find and verify.\n",
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

