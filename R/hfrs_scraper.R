# Tanzania Health Facility Registry (HFRS, Ministry of Health)
# Scrapes the public quick-search listing: every public and private facility
# with its code, type, region, council and ownership.
#
# Usage: Rscript R/hfrs_scraper.R   ->  data/hfrs_facilities_<date>.csv

source("R/utils.R")

HFRS_BASE <- "https://hfrs.moh.go.tz/web/index.php?r=portal%2Fquick-search"

# The pager's "last" link holds the number of the final page
last_page <- function(html) {
  html |>
    html_element(".page-item.last .page-link") |>
    html_attr("href") |>
    str_extract("page=(\\d+)", group = 1) |>
    as.integer()
}

listing_urls <- function(filter, base = HFRS_BASE) {
  first <- polite_request(paste0(base, "&filters=", filter)) |> req_perform() |> resp_body_html()
  n <- last_page(first)
  sprintf("%s&filters=%s&page=%d", base, filter, seq_len(n))
}

parse_listing <- function(html) {
  html |>
    html_element("table") |>
    html_table() |>
    select(-any_of(c("#", ""))) |>
    mutate(across(everything(), as.character))
}

scrape_hfrs <- function(base = HFRS_BASE) {
  urls <- c(listing_urls("publ", base), listing_urls("priv", base))
  message("Fetching ", length(urls), " listing pages")
  fetch_all(urls) |>
    map(~ parse_listing(resp_body_html(.x))) |>
    list_rbind() |>
    distinct(`Facility Code`, .keep_all = TRUE) |>
    mutate(Region = str_remove(Region, " Region$"))
}

if (sys.nframe() == 0) {
  facilities <- scrape_hfrs()
  out <- sprintf("data/hfrs_facilities_%s.csv", Sys.Date())
  readr::write_csv(facilities, out)
  message(nrow(facilities), " facilities written to ", out)
}
