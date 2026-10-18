# Offline tests: run the scrapers against tests/fixture_server.py
# (start it first: python tests/fixture_server.py)
source("R/hfrs_scraper.R")
source("R/schools_scraper.R")
source("R/regions_districts.R")

base <- "http://127.0.0.1:8765"

f <- scrape_hfrs(paste0(base, "/hfrs?r=portal%2Fquick-search"))
stopifnot(nrow(f) == 25, !"#" %in% names(f), !any(grepl("Region$", f$Region)))
cat("HFRS:", nrow(f), "facilities OK\n")

s <- scrape_schools(base)
stopifnot(nrow(s) == 6, all(s$region == "DODOMA"), all(grepl("^P01", s$reg_number)))
cat("Schools:", nrow(s), "schools OK\n")

r <- polite_request(paste0(base, "/regions")) |> req_perform() |> resp_body_html() |> parse_regions()
stopifnot(nrow(r) == 4, setequal(r$region, c("Arusha", "Dodoma")), !any(grepl("\\[", r$district)))
cat("Regions:", nrow(r), "districts OK\n")
