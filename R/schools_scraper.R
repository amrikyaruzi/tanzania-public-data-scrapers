# Primary schools in Tanzania (from the public directory at shulezetu.com)
# Two levels: listing pages give each school's link; each school page gives
# its registration number, region, district and level.
#
# Usage: Rscript R/schools_scraper.R  ->  data/primary_schools_<date>.csv

source("R/utils.R")

SCHOOLS_BASE <- "https://shulezetu.com"

last_listing_page <- function(html) {
  html |>
    html_element("li.MarkupPagerNavLast a span") |>
    html_text() |>
    as.integer()
}

school_links <- function(html, base = SCHOOLS_BASE) {
  a <- html |> html_elements("div#content ul.nav li p a")
  tibble(school = html_text(a), url = paste0(base, html_attr(a, "href")))
}

# School pages are "Label: value" lines; pull each field by its label
parse_school <- function(html) {
  text <- html |> html_element("div#bodycopy") |> html_text2()
  field <- function(label) str_trim(str_match(text, paste0(label, ":\\s*([^\\n]*)"))[, 2])
  tibble(
    school_name   = field("School name"),
    reg_number    = field("School number"),
    region        = field("School Region"),
    district      = field("School District"),
    category      = field("School Category"),
    level         = field("School Level")
  )
}

scrape_schools <- function(base = SCHOOLS_BASE) {
  first <- polite_request(paste0(base, "/primary-schools/")) |> req_perform() |> resp_body_html()
  pages <- sprintf("%s/primary-schools/page%d/", base, seq_len(last_listing_page(first)))
  message("Fetching ", length(pages), " listing pages")
  links <- fetch_all(pages, rate = 5) |>
    map(~ school_links(resp_body_html(.x), base)) |>
    list_rbind() |>
    distinct(url, .keep_all = TRUE)
  message("Fetching ", nrow(links), " school pages")
  fetch_all(links$url, rate = 5) |>
    map(~ parse_school(resp_body_html(.x))) |>
    list_rbind()
}

if (sys.nframe() == 0) {
  schools <- scrape_schools()
  out <- sprintf("data/primary_schools_%s.csv", Sys.Date())
  readr::write_csv(schools, out)
  message(nrow(schools), " schools written to ", out)
}
