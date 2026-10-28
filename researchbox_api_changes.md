# ResearchBox API: change log (branch `ap_api`)

ResearchBox functions moved from reading the box's web page to ResearchBox's
API (`https://researchbox.org/api_call.php`), with the web page kept as the
fallback. Version 0.4.1.10.

## Preexisting bugs fixed

| Bug | Introduced | Fix |
|---|---|---|
| `rbox_info()` stopped at the first box that failed; every later box got no information | Lisa DeBruine, 7c19ffe4 (2025-06-24, "resaerchbox functions") | every box is looked up, as in `zenodo_info()` |
| `RB_authors` read from the web page held the rest of the page (footer, JavaScript) for a box without an abstract (box 10485) | Lisa DeBruine, 7c19ffe4 (2025-06-24): each section was cut only at the next heading in the list | each section is cut at the first later heading that is present |
| `repo_check` lost the files of one failed box among several without a message; only all boxes failing was reported | the check `is.null(rb_file_list)`, Daniel Lakens, a26ba76d (2026-10-20) | each failed box gets its own `repo_error` |

## What was and was not changed

| Part | Changed | Not changed |
|---|---|---|
| `rbox_token()` (new) | gets or sets the key; reads `RESEARCHBOX_API_KEY` | |
| `rbox_info()` / `.rbox_info()` | API first (2 requests per box), web page as fallback; new columns `RB_title`, `RB_status`, `RB_paper_doi`, `RB_paper_authors`, `RB_zenodo_doi`, `RB_license_url`, `RB_last_modified`; `RB_license` as SPDX id and `RB_public` as ISO date from both routes; `cache` argument | same columns from both routes |
| `rbox_files()` (new) | file list with section, type, size, MD5; 1 request per box; `cache` | |
| `rbox_search()` (new) | data, code or paper search; 1 request per 100 hits; `total` attribute | |
| `rbox_file_download()` | API download (1 request); MD5 check against the zip's table of contents (`checksum_ok`), `list_files` only for a zip without one; table of contents kept beside the zip, not listed as a box file; `"failed"` attribute; `file_ids`, `subfolders`, `cache`; empty table instead of `NULL` | the zip layout (folders by type) and the cache folder of a full download |
| Peer-review links | passcode sent to the API as `code` (`.rbox_code()`) | web page still the fallback |
| `.rbox_api()` | requests 6 s apart (`req_throttle`); `Retry-After` header read; waits over 60 s reported, not waited out; "unfound" answers without a passcode recorded for 10 days, and after 8 no box without a passcode is sent (`.rbox_unfound_limit`) | |
| `.rbox_info_page()` | "There is no ResearchBox" page is `"unfound"`; captcha page is `"not public: ..."` (both were read as a box without files) | |
| "unfound" from the API | the web page is read, and its answer reported | |
| `repo_check` | licence of each downloaded box in `repo_metadata` (`.rbox_license()`, one `box_meta` request) | |
| `rbox_links()` | passcode kept in text matches; within a paper a plain link to a box takes its peer-review link | |
| `rbox_file_download()` | several links to one box: one download, through the link with a passcode; download folder named by box number | |
| ResearchBox app | `normalize_rbox_url()` keeps a passcode | |
| `repo_check` | one `repo_error` per failed box | everything else |
| `rbox_links()` | | unchanged |
| Tests | recorded API replies in `tests/testthat/apis/researchbox.org/api_call.php-*.json`; page tests run without a key | |

## How ResearchBox's API behaves (checked 2026-10-28, after their changes)

Limits as listed on https://researchbox.org/api:

| Action | Limit | When exceeded |
|---|---|---|
| any | one request at a time | 5-minute block |
| `list_files` / `box_meta` | 5 s between calls; 100 per hour, 500 per day | 429 + Retry-After |
| `list_files` / `box_meta` | same box more than 10 per hour or 20 per day | 429 + Retry-After |
| `list_files` / `box_meta` | 10 requests in 10 days for non-public boxes without `code` | 10-day block of the key |
| `search` | 5 s between calls; 30 per hour, 100 per day | 429 + Retry-After |
| `download_files` | 30 s between calls; 10 GB or 200 per day | 429 + Retry-After |
| `download_files` | same file 10 times in 30 days | 2-day block of the key |

What our feedback changed (tested 2026-10-28):

- Fixed: `box_meta` gives `license_id` ("CC-BY-4.0"), `license_url`,
  `public_since` and `last_modified`.
- Fixed: every download is a zip (also for one file) with
  `Table of Contents Box #<id>.json` and `.csv` at the top level, giving each
  file's name, file_id, type, section, description, size and MD5. All
  checksums matched. (Their page shows a "ResearchBox <id>/" top folder; the
  real zip has none.)
- Fixed: `paper_reference` is plain text.
- Fixed: the "too soon" 429 sends a `Retry-After` header as well.
- Documented: `code=` for a private box (shown for `list_files`; also
  accepted by `box_meta` for a public box). Not tested on a box that is
  still private, and not documented for `download_files`.
- A box that is not public, asked for without `code` (box 10480,
  `box_meta`), gives HTTP 500 with an empty body, the same as a box that does
  not exist, and no count of requests left. Its web page sends the browser to
  `captcha_wall.php`; a missing box's page says "There is no ResearchBox".
- Not fixed: no file list in `box_meta` (`include_files=1` is ignored).
- Not fixed: a box that does not exist gives HTTP 500 with an empty body.
- Not fixed: `box_title` is cut at 40 characters.
- `search` returns at most 100 hits per request; an empty query is refused
  ("query too short").
- The web page's download asks for a captcha after several downloads.
