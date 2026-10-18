# Summaries and figures from the scraped data.
# Usage: Rscript analysis/summaries.R  ->  figures/*.png

suppressPackageStartupMessages({ library(tidyverse); library(scales) })

theme_set(theme_minimal(base_size = 12) +
  theme(plot.title.position = "plot", plot.title = element_text(face = "bold"),
        panel.grid.minor = element_blank(), legend.position = "top"))
own_cols <- c(Public = "#1F4E79", Private = "#E07B39")

facilities <- read_csv("data/hfrs_facilities_2026-09-24.csv", show_col_types = FALSE)
message(sum(is.na(facilities$Region)), " facilities have no region and are left out of the regional charts")
schools    <- read_csv("data/primary_schools_geocoded.csv", show_col_types = FALSE)

# 1. Facilities per region, public vs private
by_region <- facilities |>
  filter(!is.na(Region)) |>
  count(Region, `Ownership Category`) |>
  group_by(Region) |> mutate(total = sum(n), private_share = sum(n[`Ownership Category` == "Private"]) / total) |>
  ungroup()

p1 <- ggplot(by_region, aes(n, fct_reorder(Region, total), fill = `Ownership Category`)) +
  geom_col(width = 0.75) +
  scale_fill_manual(values = own_cols, name = NULL) +
  scale_x_continuous(expand = expansion(c(0, 0.05)), labels = comma) +
  labs(title = "Registered health facilities by region",
       subtitle = sprintf("%s facilities in the Health Facility Registry, scraped 24 Sep 2026", comma(nrow(facilities))),
       x = "Facilities", y = NULL)
ggsave("figures/facilities_by_region.png", p1, width = 9, height = 9, dpi = 160, bg = "white")

# 2. Where the private sector is concentrated
p2 <- by_region |> distinct(Region, total, private_share) |>
  ggplot(aes(total, private_share, label = Region)) +
  geom_point(colour = "#1F4E79", size = 2.6) +
  ggrepel::geom_text_repel(size = 3, max.overlaps = 20, colour = "grey25") +
  scale_y_continuous(labels = percent) + scale_x_continuous(labels = comma) +
  labs(title = "Private share of facilities vs number of facilities",
       subtitle = "Each point is a region", x = "Facilities in region", y = "Privately owned")
ggsave("figures/private_share.png", p2, width = 9, height = 6, dpi = 160, bg = "white")

# 3. Facility types by ownership
types <- facilities |>
  mutate(type = fct_lump_n(`Facility Type`, 7, other_level = "Other")) |>
  count(type, `Ownership Category`)
p3 <- ggplot(types, aes(n, fct_reorder(type, n, sum), fill = `Ownership Category`)) +
  geom_col(position = "dodge", width = 0.75) +
  scale_fill_manual(values = own_cols, name = NULL) +
  scale_x_continuous(labels = comma, expand = expansion(c(0, 0.05))) +
  labs(title = "Facility types: dispensaries dominate, and most are public", x = "Facilities", y = NULL)
ggsave("figures/facility_types.png", p3, width = 9, height = 5, dpi = 160, bg = "white")

# 4. Map of geocoded primary schools
tz <- map_data("world", region = c("Tanzania"))
pts <- schools |> filter(between(lat, -12, -0.9), between(lon, 29.3, 40.5))
p4 <- ggplot() +
  geom_polygon(data = tz, aes(long, lat, group = group), fill = "grey95", colour = "grey60", linewidth = 0.3) +
  geom_point(data = pts, aes(lon, lat), size = 0.25, alpha = 0.35, colour = "#1F4E79") +
  coord_quickmap(xlim = c(29.3, 40.6), ylim = c(-11.8, -0.9)) +
  labs(title = "Primary schools in Tanzania",
       subtitle = sprintf("%s schools geocoded with OpenStreetMap Nominatim", comma(nrow(pts))),
       x = NULL, y = NULL) +
  theme(axis.text = element_blank(), panel.grid = element_blank())
ggsave("figures/schools_map.png", p4, width = 8, height = 8, dpi = 160, bg = "white")

# Console summary
facilities |> count(`Ownership Category`) |> mutate(share = percent(n / sum(n), 0.1)) |> print()
cat(sprintf("Schools: %s, geocoded: %s\n", comma(nrow(schools)), comma(sum(!is.na(schools$lat)))))
