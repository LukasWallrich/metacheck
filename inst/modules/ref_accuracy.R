#' Reference Accuracy
#'
#' @description
#' This module checks whether each reference with a DOI is internally coherent: it compares the details the paper cites for a reference against the authoritative record that the reference's DOI points to, and flags any reference whose cited details do not match.
#'
#' @details
#' This module looks for *incoherent* references: a reference is incoherent when the title, authors, journal, or year that the paper cites disagree with the record that the reference's own DOI points to. Currently, it will most often be a parsing error where the reference list from the PDF is not extracted perfectly accurately, but the module can point out AI-generated references or mistakes in citations. You will need to check the original source.
#'
#' The module uses the `bib_match` table, which holds the metadata retrieved from CrossRef for each reference (added or refreshed with `add_bib_match()`, which makes live network calls).
#'
#' **Only references that supply their own DOI are checked.** For these, we compare what the paper cites field by field against the record found for that DOI. `add_bib_match()` looks up a cited DOI directly when it is valid as printed; a DOI that is not (for example one broken by a space from the PDF) is matched by a title search instead. A cited DOI with no record at all is flagged as a DOI that could not be found: `bib_match` does not record why a lookup found nothing, so this includes lookups that failed for network reasons (`add_bib_match()` reports those when it runs) and DOIs registered outside CrossRef. References in papers that were not looked up at all are not checked. A reference with no DOI is *not* checked: the only record we could find for it comes from a CrossRef title search, which often returns the wrong paper, so any "mismatch" would be CrossRef's error rather than the citation's. References without a DOI are instead listed separately, with a recommendation to add a DOI where one exists. For those, a suggested DOI is offered only when CrossRef found a high-confidence match (controlled by `suggest_score`).
#'
#' For each checked reference we compare five fields against the DOI's record:
#'
#' - **DOI** — flagged only when the reference printed a DOI that differs from the record (a blank cited DOI is never a mismatch). DOIs are compared after removing URL wrappers (`https://doi.org/`, journal article URLs), spaces and trailing punctuation left by the PDF, and the old double slash after the prefix (`10.1037//`). When the record was found by looking up the cited DOI (it has no search score), a record with a different DOI means the registry lists the cited DOI as an alias (for example after a journal moved publisher); this is reported as a note with the current DOI, not as an incoherence. A DOI mismatch is therefore only flagged when the record came from a title search. Papers read from bibr 12.x exports do not record how a record was found, so for them a different DOI is always a mismatch.
#' - **Year** — flagged when the cited year is more than `year_tolerance` years from the record (online-first and print years routinely differ by one year, so this is allowed by default).
#' - **Journal** — flagged when the cited journal disagrees with the record. Journal names are matched tolerantly: standard ISO-4 abbreviations (e.g. "J. Pers. Soc. Psychol." for "Journal of Personality and Social Psychology"), "&"/"and", and "the" are treated as equivalent, and the words of the shorter name only need to appear in order in the longer one, because words are often lost in reading the PDF. A one-word name must match the other name exactly ("Nature" is not "Nature Neuroscience"), but a longer name contained in another journal's name is accepted ("Journal of Experimental Psychology" for "Journal of Experimental Social Psychology"). The journal is only compared when the record is a journal article: for book chapters, proceedings and reports the registry often gives a series or platform name ("Oxford Handbooks Online"). A cited "journal" that is an article number ("Article e17018"), which comes from reading the PDF, is not compared either.
#' - **Title** — flagged when the cited title is too different from the record's title, judged by character-level similarity (`title_similarity`) after stripping case, punctuation, footnote markers and diacritics. This ignores cosmetic differences (colons, question marks, em-dash spacing, line-break word splits) while still catching a genuinely different title. A title is also accepted when the record's title appears in the reference text as whole words ending at a title delimiter, for references whose title was not read correctly from the PDF. A cited title that begins with the record's title, followed by a title delimiter (":", "?", "." or "!"), is accepted, because the record often holds only the main title without the subtitle; the cited subtitle is then not checked.
#' - **Authors** — flagged when the leading author surnames (the first `max_authors`) from the record are not all present in the cited author list. Only the leading authors are required because author lists are routinely truncated with "et al.". The cited authors are read one person at a time, and each record surname must equal one cited surname, compared on its letters only, so diacritics, spacing and case are ignored ("Gredebäck" and "Gredeback", "Le Doux" and "LeDoux" match). When one of the two is a single word, it may also match the other's last word, for shortened compound surnames and particles ("Vafaei Shooshtari" cited as "Shooshtari", "Gelder" cited as "De Gelder"). A cited name without a comma is read as given name first, and the record surname must equal its last word or words. Papers read from bibr 12.x exports keep each author list as printed ("Adam, H., Shirako, A., & Maddux, W. W"), so for them each record surname only needs to appear somewhere in the cited list. A reference whose authors could not be read is not flagged. A cited list truncated with "et al." before `max_authors` authors is flagged.
#'
#' A mismatched DOI, journal or year flags a reference on its own, although journal and year flags also often come from imperfect PDF parsing (an article number read as the journal, two references merged) or from the registry naming or dating the same work differently (a renamed journal, a handbook's series name, an online-first year). Title and author mismatches are governed by `min_mismatches`: the default (1) flags a reference when either the title or the authors disagree. Set `min_mismatches = 2` to be more conservative and require both to disagree (fewer false positives, lower recall).
#'
#' The report lists each incoherent reference with the specific cited value struck through and the record's value beside it, so the discrepancy is visible at a glance.
#'
#' <validation>In an evaluation on 30 randomly sampled Psychological Science papers (October 2026; 1,269 references, 554 of which printed their own DOI), the module flagged 14 references in 11 papers (2.5% of the checked references; 8 at min_mismatches = 2). Checked by hand, 2 were genuine citation errors (a misspelled and a wrong author name), 2 were unclear, and the rest came from imperfect reading of the reference from the PDF (two references merged, "O'Connell" read as "Connell", a DOI cut short, a note read as the journal), from the registry naming or dating the same work differently (a renamed journal, an online-first year), or from a correct data DOI registered with DataCite rather than CrossRef, which therefore could not be found. A flag should therefore be read as "check this reference against the original source", not as a confirmed error. This evaluation cannot show how many citation errors the module misses. The package tests change one field of a correct reference at a time (year, journal, title, authors, another paper's DOI, a DOI that does not resolve) and the module flags each of these, but that does not establish a detection rate for real errors. An earlier validation of a previous version reported that about 8% of checked references were flagged at min_mismatches = 1 and 3% at min_mismatches = 2, and that 96-100% of deliberately corrupted journals and years were caught. In the 30 papers, CrossRef found a match confident enough to suggest its DOI for 525 of the 715 references that printed no DOI.</validation>
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
#'   mismatch, which catches more genuine errors; the extra false positives this
#'   adds are minor compared with those that already come from imperfect PDF
#'   parsing. Set to 2 to be more conservative and require two of these fields
#'   to disagree. A mismatched DOI, journal or year always flags on its own,
#'   regardless of this setting.
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

  # no Crossref lookup (convert() without crossref, no add_bib_match()): the
  # references were not checked, which is not a fault of the paper
  if (nrow(bib_match) == 0) {
    norefs <- list(
      traffic_light = "na",
      summary_text = "The references were not looked up at Crossref, so their accuracy was not checked."
    )
    return(norefs)
  }

  cols <- c("paper_id", "bib_id", "doi", "title", "year", "authors",
            "container", "bib_type")
  if (!"bib_type" %in% names(bib)) bib$bib_type <- NA_character_
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

  # fold accented Latin letters to plain ASCII so that e.g. "Gredebäck" and
  # "Gredeback" are treated as the same name and diacritics never cause a
  # mismatch on their own. Done in base R (no locale-dependent iconv): multi-
  # character cases first, then a 1:1 chartr table built so the from/to strings
  # cannot drift out of sync.
  accent_map <- c(
    a = "àáâãäåāăą",
    c = "çćčĉċ", d = "ďð",
    e = "èéêëēėęě",
    g = "ğĝġģ", i = "ìíîïįĩ",
    l = "ĺļľ", n = "ñńňņ",
    o = "òóôõöōőŏ",
    r = "ŕřŗ", s = "śšşŝș",
    t = "ťţț", u = "ùúûüūůűŭ",
    y = "ýÿŷ", z = "źżž"
  )
  accent_from <- paste(accent_map, collapse = "")
  accent_to <- paste(mapply(\(base, ch) strrep(base, nchar(ch)),
                            names(accent_map), accent_map), collapse = "")
  deaccent <- \(x) {
    x <- gsub("ß", "ss", x)   # eszett
    x <- gsub("æ", "ae", x)   # ae ligature
    x <- gsub("œ", "oe", x)   # oe ligature
    x <- gsub("đ", "d", x)    # d with stroke
    x <- gsub("ł", "l", x)    # l with stroke
    x <- gsub("ø", "o", x)    # o with stroke
    x <- gsub("ı", "i", x)    # dotless i
    chartr(accent_from, accent_to, x)
  }

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
  # over-flags. We drop stop-words, then accept a name as coherent if its
  # significant tokens match the other name's tokens in sequence, allowing each
  # abbreviated token to be a prefix of the full token. Skipped words allow for
  # words lost in reading the PDF ("Identity & Education" for "Journal of
  # Language, Identity & Education"), but a one-word name does not match a
  # longer one: "Nature" is not "Nature Neuroscience". A two-word name that
  # another journal's name contains ("Psychological Science" in "Current
  # Directions in Psychological Science") is still accepted.
  journal_tokens <- \(x) {
    x <- clean(x)
    x <- gsub("&amp;|&", " and ", x)
    x <- gsub("[^a-z ]", " ", x)
    toks <- strsplit(trimws(gsub("\\s+", " ", x)), " ")[[1]]
    toks[!toks %in% c("of","and","the","for","in","on","a","an","de","") &
           nchar(toks) > 0]
  }
  journal_coherent <- \(a, b) {
    ta <- journal_tokens(a); tb <- journal_tokens(b)
    if (!length(ta) || !length(tb)) return(TRUE)        # unknown, don't flag
    if (length(ta) > length(tb)) { tmp <- ta; ta <- tb; tb <- tmp }
    if (length(ta) == 1 && length(tb) > 1) return(FALSE)
    j <- 1L
    for (tok in ta) {
      hit <- FALSE
      while (j <= length(tb)) {
        if (startsWith(tb[j], tok) || startsWith(tok, tb[j])) {
          hit <- TRUE; j <- j + 1L; break
        }
        j <- j + 1L
      }
      if (!hit) return(FALSE)
    }
    TRUE
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
  table$container_mismatch <- mapply(\(a, b, check) {
    if (!check || is.na(a) || is.na(b) || !nzchar(trimws(a)) || !nzchar(trimws(b)))
      return(FALSE)
    !journal_coherent(a, b)
  }, table$container.orig, table$container.match, is_article & !article_number,
  USE.NAMES = FALSE)

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
    # "misbehavior") and ending at a title delimiter, so that a cited title
    # that continues ("Origins" in "The origins of ...") or a journal name
    # followed by its volume is not taken for the title.
    clean_text <- clean(table$text)
    match_clean <- clean(table$title.match)
    escape <- \(x) gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)
    in_text <- mapply(\(pattern, x) !is.na(pattern) && nzchar(pattern) &&
                        grepl(pattern, x, fixed = TRUE) &&
                        grepl(paste0("(^|[^a-z0-9])", escape(pattern),
                                     if (grepl("[:?.!]$", pattern)) "" else "\\s*($|[:?.!])"),
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
    main_title <- mapply(\(cited, record) {
      if (is.na(cited) || is.na(record) || nchar(record) < 20 ||
          !startsWith(cited, record)) return(FALSE)
      grepl("[:?.!]$", record) ||
        grepl("^ ?[:?.!]", substring(cited, nchar(record) + 1))
    }, delimited(table$title.orig), delimited(table$title.match),
    USE.NAMES = FALSE)

    !is.na(charsim) & charsim < title_similarity & !in_text & !main_title
  }

  # author check: do the leading author surnames from the retrieved record
  # appear in the cited author list? Only the first `max_authors` are required,
  # because author lists are commonly truncated with "et al." (and GROBID often
  # drops the tail of long lists), so a missing trailing author is not evidence
  # of an incoherent citation. Diacritics are ignored (handled by clean()).
  table$author_mismatch <- {
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
     # people reliably, so there each record surname is looked for anywhere in
     # the cited list.
     letters_only <- \(x) gsub("[^a-z]", "", clean(x))
     cited_surnames <- \(o) {
       people <- trimws(strsplit(paste(o, collapse = ";"), ";", fixed = TRUE)[[1]])
       people <- people[nzchar(people)]
       family <- trimws(sub(",.*", "", people))
       has_comma <- grepl(",", people, fixed = TRUE)
       list(name = letters_only(family),
            last = letters_only(sub(".*[[:space:]\u00a0]", "", family)),
            one_word = has_comma & !grepl("[[:space:]\u00a0]", family),
            given_first = !has_comma,
            # "Alice Brown Jones" ends in "jones", "brownjones", ...
            ends = lapply(family, \(f) {
              w <- letters_only(strsplit(f, "[[:space:]\u00a0]+")[[1]])
              w <- w[nzchar(w)]
              vapply(seq_along(w), \(k) paste(utils::tail(w, k), collapse = ""), "")
            }))
     }
     bibr <- table$paper_id %in% .bibr12_paper_ids(paper)
     mapply(\(l, o, as_printed) {
       if (length(l) == 0 || all(is.na(l))) return(FALSE)  # nothing to check
       # no cited authors were read from the reference: unknown, not a mismatch
       if (length(o) == 0 || all(is.na(o)) || !nzchar(trimws(paste(o, collapse = "")))) return(FALSE)
       l <- utils::head(l[!is.na(l)], max_authors)
       if (as_printed) {
         cited <- letters_only(paste(o, collapse = " "))
         return(!all(vapply(l, \(x) grepl(letters_only(x), cited, fixed = TRUE),
                            logical(1))))
       }
       cs <- cited_surnames(o)
       found <- vapply(l, \(x) {
         full <- letters_only(x)
         last <- letters_only(sub(".*[[:space:]\u00a0]", "", x))
         if (!nzchar(full)) return(TRUE)
         record_one_word <- !grepl("[[:space:]\u00a0]", trimws(x))
         any(cs$name == full) ||
           any(cs$one_word & cs$name == last) ||
           (record_one_word && any(!cs$given_first & cs$last == full)) ||
           any(cs$given_first & vapply(cs$ends, \(e) full %in% e, logical(1)))
       }, logical(1))
       !all(found)
     }, last_names, table$authors.orig, bibr)
  }

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
  #                 title/author search; the match may be wrong, so we do not
  #                 flag it.
  #  "none"       - no DOI at all.
  has_own_doi <- !is.na(table$doi.orig) & nzchar(table$doi.orig)
  has_record  <- !is.na(table$title.match) & nzchar(table$title.match)
  looked_up   <- table$paper_id %in% bib_match$paper_id
  table$tier <- dplyr::case_when(
    has_own_doi & has_record   ~ "provided",
    has_own_doi & looked_up    ~ "unresolved",
    has_own_doi                ~ "not_checked",
    has_record                 ~ "crossref",
    .default                   = "none"
  )
  # no_match: the reference could not be matched to a retrieved record (kept for
  # downstream modules such as ref_summary that group on it)
  table$no_match <- !has_record
  # only a reference that printed its own DOI is compared with its record, so
  # the field mismatches are FALSE for the others (ref_summary reports them)
  for (col in grep("_mismatch$", names(table), value = TRUE)) {
    table[[col]] <- table[[col]] %in% TRUE & table$tier == "provided"
  }

  # incoherence: cited details disagree with the record the reference's OWN DOI
  # points to. We only flag references in the "provided" tier (the reference
  # printed its own DOI), because then we are comparing against the exact record
  # the author cited. References with no DOI are not flagged: the only record we
  # have for them was found by a CrossRef title search, which is often the wrong
  # paper, so a "mismatch" would be CrossRef's error, not the citation's. Those
  # are reported separately as references that could not be checked.
  # Journal, year and DOI are reliable signals and flag on their own; title and
  # author mismatches also come from PDF parsing noise, so they only count when
  # at least `min_mismatches` of them disagree.
  strong <- (table$doi_mismatch %in% TRUE) |
            (table$year_mismatch %in% TRUE) |
            (table$container_mismatch %in% TRUE)
  n_parsing_mismatch <- (table$title_mismatch %in% TRUE) +
                        (table$author_mismatch %in% TRUE)
  # a reference is incoherent when it printed its own DOI and either that DOI
  # could not be found (tier "unresolved") or the retrieved record disagrees
  # with the cited details (tier "provided").
  table$incoherent <- (table$tier == "unresolved") |
    ((table$tier == "provided") &
       (strong | n_parsing_mismatch >= min_mismatches))

  # summary_table ----
  # references that printed a DOI (tiers "provided" and "unresolved") are
  # checked; every other reference printed no DOI (tiers "crossref" and
  # "none") and is listed so the user can add one. A DOI is suggested when the
  # CrossRef title search found a match that scored high enough to be
  # trustworthy; a low score is usually the wrong paper. bibr 12.x exports
  # score their matches 0-1; a CrossRef score that low never passes
  # add_bib_match()'s minimum, so the scale can be read from the score itself.
  table$no_doi <- table$tier %in% c("crossref", "none")
  min_score <- ifelse(table$score %in% NA | table$score > 1,
                      suggest_score, suggest_score / 100)
  table$doi_suggested <- table$tier == "crossref" & !is.na(table$score) &
    table$score >= min_score & !is.na(table$doi.match) & nzchar(table$doi.match)
  summary_table <- dplyr::summarise(table,
    .by = paper_id,
    refs_checked  = sum(tier %in% c("provided", "unresolved"), na.rm = TRUE),
    incoherent    = sum(incoherent, na.rm = TRUE),
    no_doi        = sum(no_doi, na.rm = TRUE),
    doi_suggested = sum(doi_suggested, na.rm = TRUE)
  )

  # summary_text
  n_checked  <- sum(summary_table$refs_checked)
  n_inc      <- sum(summary_table$incoherent)
  n_nodoi    <- sum(summary_table$no_doi)
  n_suggest  <- sum(summary_table$doi_suggested)
  n_unlooked <- sum(table$tier == "not_checked")
  summary_text <- sprintf(
    "We checked the %d reference%s that supplied a DOI against the record that DOI points to, and found %d incoherent reference%s to check for parsing errors or mistakes.%s %d reference%s had no DOI and could not be checked%s.%s",
    n_checked, plural(n_checked), n_inc, plural(n_inc),
    if (n_inc > 0) " Incoherent references are mostly PDF parsing errors (we are working on improving reference parsing)." else "",
    n_nodoi, plural(n_nodoi),
    if (n_suggest > 0) sprintf("; for %d of them CrossRef found a likely DOI, suggested in the report", n_suggest) else "",
    if (n_unlooked > 0) sprintf(" %d reference%s with a DOI %s not checked, because %s paper was not looked up at Crossref.",
                                n_unlooked, plural(n_unlooked),
                                if (n_unlooked == 1) "was" else "were",
                                if (n_unlooked == 1) "its" else "their") else ""
  )

  # traffic_light ----
  # nothing to check when no reference supplied a DOI
  tl <- if (n_checked == 0) "na" else if (any(table$incoherent %in% TRUE)) "yellow" else "green"

  guidance <- "The references below supplied a DOI, but either that DOI could not be found, or one or more of the cited details (title, authors, journal, or year) does not match the record that DOI points to. Such an incoherence is most often an error in reading the reference from the PDF, but it could be a mistake, or an AI-generated reference. Check each against the original source."

  if (n_inc == 0) guidance <- ""

  # report ----

  # render the surname list of a CrossRef author record (a data.frame of
  # given/family) as a plain "Family1, Family2, ..." string
  author_string <- function(a) {
    if (is.null(a) || !is.data.frame(a) || nrow(a) == 0) return(NA_character_)
    fam <- a$family[!is.na(a$family)]
    if (!length(fam)) return(NA_character_)
    paste(utils::head(fam, max_authors), collapse = ", ")
  }

  # for one reference, build the "what is wrong" cell: each mismatching field is
  # shown as the cited value struck through in red followed by the value from
  # the record, so the discrepancy is visible at a glance.
  strike <- function(x) paste0(
    "<span style=\"color:#c00;text-decoration:line-through\">", x, "</span>")
  correction <- function(label, cited, record) {
    if (is.na(cited) || !nzchar(as.character(cited))) cited <- "(missing)"
    sprintf("<b>%s:</b> %s &rarr; %s", label, strike(cited), record)
  }
  discrepancies <- function(r) {
    # an unresolved cited DOI has no record to compare against
    if (r$tier == "unresolved") {
      return(sprintf(
        "<b>DOI:</b> the cited DOI %s could not be found",
        strike(r$doi.orig)))
    }
    parts <- c(
      if (isTRUE(r$title_mismatch))
        correction("title", r$title.orig, r$title.match),
      if (isTRUE(r$author_mismatch))
        correction("authors", r$authors.orig, author_string(r$authors.match[[1]])),
      if (isTRUE(r$container_mismatch))
        correction("journal", r$container.orig, r$container.match),
      if (isTRUE(r$year_mismatch))
        correction("year", r$year.orig, r$year.match),
      if (isTRUE(r$doi_mismatch))
        correction("DOI", r$doi.orig, r$doi.match)
    )
    paste(parts, collapse = "<br>")
  }

  ## incoherent references (each printed its own DOI) ----
  inc_rows <- table[table$incoherent %in% TRUE, ]
  incoherent_report <- NULL
  if (nrow(inc_rows) > 0) {
    # link to the retrieved record; for an unresolved DOI there is no record, so
    # show the cited (non-resolving) DOI instead
    rec_doi <- ifelse(is.na(inc_rows$doi.match) | !nzchar(inc_rows$doi.match),
                      inc_rows$doi.orig, inc_rows$doi.match)
    out <- data.frame(
      Reference = inc_rows$text,
      `What is wrong (cited → record)` =
        vapply(seq_len(nrow(inc_rows)), \(i) discrepancies(inc_rows[i, ]),
               character(1)),
      # a cited DOI written as a URL is cleaned for the link target only
      Record = link(paste0("https://doi.org/", doi_clean(rec_doi)), rec_doi),
      check.names = FALSE
    )
    incoherent_report <- scroll_table(out, 5, colwidths = c(.45, .4, .15))
  }

  ## cited DOIs that are aliases of the record's DOI ----
  alias_rows <- table[table$doi_alias %in% TRUE, ]
  alias_report <- NULL
  if (nrow(alias_rows) > 0) {
    out <- data.frame(
      Reference = alias_rows$text,
      `Cited DOI` = alias_rows$doi.orig,
      `Current DOI` = link(paste0("https://doi.org/", alias_rows$doi.match),
                           alias_rows$doi.match),
      check.names = FALSE
    )
    alias_report <- scroll_table(out, 5, colwidths = c(.6, .2, .2))
  }

  ## references without a DOI (could not be checked) ----
  nodoi_rows <- table[table$no_doi %in% TRUE & !is.na(table$text), ]
  nodoi_report <- NULL
  if (nrow(nodoi_rows) > 0) {
    suggested <- ifelse(
      nodoi_rows$doi_suggested & !is.na(nodoi_rows$doi.match) & nzchar(nodoi_rows$doi.match),
      link(paste0("https://doi.org/", nodoi_rows$doi.match), nodoi_rows$doi.match),
      ""
    )
    out <- data.frame(
      Reference = nodoi_rows$text,
      `Suggested DOI` = suggested,
      check.names = FALSE
    )
    nodoi_report <- scroll_table(out, 5, colwidths = c(.7, .3))
  }

  report <- c(
    guidance,
    if (!is.null(incoherent_report))
      c("### Incoherent references\n",
        "The DOI of these references could not be found, or their cited details do not match the record their DOI points to.\n",
        incoherent_report),
    if (!is.null(alias_report))
      c("### DOIs that have a newer form\n",
        "These references cite a DOI that the registry now lists as an alias of another DOI, for example after the journal moved to a new publisher. The cited DOI still leads to the right work, so this is not an error, but citing the current DOI is more robust.\n",
        alias_report),
    if (!is.null(nodoi_report))
      c("### References without a DOI\n",
        "These references have no DOI, so they could not be checked here. We searched CrossRef for each of them; where it found a confident match, the DOI is suggested below. The other reference checks (retraction, PubPeer, and replication) use the DOI CrossRef found, so for these references they are only as reliable as that search. We recommend adding a DOI to every reference that has one: it makes each cited work easier to find and verify.\n",
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
