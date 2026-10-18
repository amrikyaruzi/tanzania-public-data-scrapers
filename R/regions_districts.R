# Regions and districts of Tanzania, from a public reference page, tidied
# into one row per district and geocoded with Nominatim.
#
# Usage: Rscript R/regions_districts.R  ->  data/regions_districts.csv

source("R/geocode_nominatim.R")

SOURCE_URL <- "https://mabumbe.com/list-of-districts-in-tanzania-region-wise/"

parse_regions <- function(html) {
  regions <- html |> html_elements("h2") |> html_text() |> str_remove(" Region$") |> str_trim()
  districts <- html |> html_elements("p ~ ul") |> map(~ html_text(html_elements(.x, "li")))
  tibble(region = regions[seq_along(districts)], district = districts) |>
    tidyr::unnest_longer(district) |>
    tidyr::separate_longer_delim(district, stringr::regex("\\s*[&;]\\s*")) |>
    mutate(district = district |>
             str_remove_all("\\[\\d+\\]") |>
             str_replace("Council.*", "Council") |>
             str_squish()) |>
    filter(district != "") |>
    distinct()
}

if (sys.nframe() == 0) {
  rd <- polite_request(SOURCE_URL) |> req_perform() |> resp_body_html() |> parse_regions()
  geo <- geocode(paste(rd$district, rd$region, "Tanzania", sep = ", "))
  out <- bind_cols(rd, select(geo, lat, lon))
  readr::write_csv(out, "data/regions_districts.csv")
  message(nrow(out), " districts written; ", sum(is.na(out$lat)), " not geocoded")
}
