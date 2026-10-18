# Shared helpers: polite requests, parallel fetching with retries.

suppressPackageStartupMessages({
  library(httr2)
  library(rvest)
  library(dplyr)
  library(purrr)
  library(stringr)
})

# Identify the scraper honestly and keep the request rate modest.
USER_AGENT <- "tanzania-public-data-scrapers (https://github.com/amrikyaruzi/tanzania-public-data-scrapers)"

polite_request <- function(url, rate = 10) {
  request(url) |>
    req_user_agent(USER_AGENT) |>
    req_throttle(rate = rate) |>                 # requests per second
    req_retry(max_tries = 5, backoff = ~ min(2^.x, 30)) |>
    req_timeout(60)
}

# Fetch many URLs in parallel; re-run only the failures, up to `rounds` times.
fetch_all <- function(urls, rate = 10, max_active = 20, rounds = 3) {
  reqs <- map(urls, polite_request, rate = rate)
  perform <- function(r) {
    if (packageVersion("httr2") >= "1.1.0") {
      req_perform_parallel(r, max_active = max_active, on_error = "continue", progress = TRUE)
    } else {
      req_perform_parallel(r, pool = curl::new_pool(total_con = max_active),
                           on_error = "continue", progress = TRUE)
    }
  }
  resps <- perform(reqs)
  for (i in seq_len(rounds)) {
    failed <- map_lgl(resps, ~ inherits(.x, "error"))
    if (!any(failed)) break
    message(sum(failed), " request(s) failed; retry round ", i)
    resps[failed] <- perform(reqs[failed])
  }
  failed <- map_lgl(resps, ~ inherits(.x, "error"))
  if (any(failed)) warning(sum(failed), " URL(s) still failed: ", paste(head(urls[failed], 3), collapse = ", "))
  set_names(resps[!failed], urls[!failed])
}
