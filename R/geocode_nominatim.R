# Geocoding with OpenStreetMap's Nominatim, following its usage policy:
# at most 1 request per second, an identifying user agent, and a local cache
# so no address is ever looked up twice.
# Policy: https://operations.osmfoundation.org/policies/nominatim/

source("R/utils.R")

NOMINATIM <- "https://nominatim.openstreetmap.org/search"
CACHE <- "data/geocode_cache.csv"

geocode_one <- function(address) {
  hits <- request(NOMINATIM) |>
    req_url_query(q = address, format = "json", limit = 1, countrycodes = "tz") |>
    req_user_agent(USER_AGENT) |>
    req_throttle(rate = 1) |>
    req_retry(max_tries = 3) |>
    req_perform() |>
    resp_body_json()
  if (length(hits) == 0) return(tibble(address, lat = NA_real_, lon = NA_real_))
  tibble(address, lat = as.numeric(hits[[1]]$lat), lon = as.numeric(hits[[1]]$lon))
}

geocode <- function(addresses) {
  cache <- if (file.exists(CACHE)) readr::read_csv(CACHE, show_col_types = FALSE)
           else tibble(address = character(), lat = double(), lon = double())
  todo <- setdiff(unique(addresses), cache$address)
  if (length(todo)) {
    message("Geocoding ", length(todo), " new address(es) at 1 per second")
    new <- map(todo, possibly(geocode_one, NULL), .progress = TRUE) |> list_rbind()
    cache <- bind_rows(cache, new)
    readr::write_csv(cache, CACHE)
  }
  tibble(address = addresses) |> left_join(cache, by = "address")
}
