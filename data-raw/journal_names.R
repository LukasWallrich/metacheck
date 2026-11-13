# Journal names that look like conferences
#
# ref_accuracy flags a reference cited in a journal whose work is found only
# as a preprint, but not one cited from a conference, because many
# proceedings have no DOIs. A venue is taken as a conference when its name
# has an acronym ("ICML") or a conference word ("Proceedings"). This list
# holds the journals with such names ("IEEE Transactions on ...", "PLoS
# ONE", "Proceedings of the National Academy of Sciences"), so that they are
# still treated as journals. It is built from the SCImago Journal Rank titles
# in the sjrdata package (https://github.com/ikashnitsky/sjrdata, MIT
# licence), pinned to a commit, keeping sources SCImago types as journals.
# SCImago also types many conference series as journals ("IEEE International
# Conference on Robotics and Biomimetics, ROBIO"); a name with an event word
# and no journal word, or ending with an acronym after a comma, is left out.

sha <- "f7ed8273edd350cfd36db0a4832a5ce1542cf77f"
tmp <- tempfile(fileext = ".rda")
download.file(sprintf(
  "https://raw.githubusercontent.com/ikashnitsky/sjrdata/%s/data/sjr_journals.rda", sha),
  tmp, mode = "wb")
load(tmp)
titles <- unique(sjr_journals$title[sjr_journals$type == "journal"])

# the module's test for a conference-like venue
conference_words <- "(?i)\\b(proc|proceedings|conference|conf|workshops?|symposium|meeting|congress|colloquium|summit|track)\\b"
acronym_word <- "(^|[^[:alnum:]])[[:alnum:]]*[A-Z][[:alnum:]]*[A-Z][[:alnum:]]*($|[^[:alnum:]])"
looks_like_conference <- grepl(conference_words, titles, perl = TRUE) |
  grepl(acronym_word, titles)

event <- "(?i)\\b(conferences?|conferencia|congreso|symposium|workshops?|meetings?|congress|colloquium|summit|digest|convention|forum)\\b"
journal_word <- "(?i)\\b(journal|review|letters|transactions|bulletin|annals|quarterly|magazine)\\b"
is_event <- grepl(event, titles, perl = TRUE) & !grepl(journal_word, titles, perl = TRUE)
ends_with_acronym <- grepl(",\\s*[[:alnum:] -]*[A-Z]{2,}[[:alnum:] -]*$", titles)

journal_titles <- sort(titles[looks_like_conference & !is_event & !ends_with_acronym])

# journals often cited by their acronym alone
journal_acronyms <- c("PNAS", "JAMA", "BMJ", "NEJM", "PLoS ONE", "PLOS ONE",
                      "JMLR", "TMLR", "TACL", "JAIR", "TPAMI", "IJCV")

saveRDS(list(titles = journal_titles, acronyms = journal_acronyms, sjrdata = sha),
        "inst/databases/journal_names.Rds", compress = "xz")
