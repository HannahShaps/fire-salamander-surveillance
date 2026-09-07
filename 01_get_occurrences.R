# 01_get_occurrences.R
# Fire salamander — first GBIF pull and occurrence map (Mosel/Eifel, German portion).

library(rgbif)
library(dplyr)
library(sf)
library(ggplot2)
library(rnaturalearth)

gbif <- occ_data(
  scientificName   = "Salamandra salamandra",
  decimalLongitude = "6.0,7.6",
  decimalLatitude  = "49.4,50.9",
  hasCoordinate    = TRUE,
  limit            = 4000
)
occ <- gbif$data

# turn records into points and keep only those inside Germany
germany <- ne_countries(scale = "medium", country = "Germany", returnclass = "sf")
occ_sf  <- st_as_sf(occ, coords = c("decimalLongitude", "decimalLatitude"),
                    crs = 4326, remove = FALSE)
occ_de  <- occ_sf[lengths(st_within(occ_sf, germany)) > 0, ]

ggplot() +
  geom_sf(data = germany, fill = "grey97", color = "grey70") +
  geom_sf(data = occ_de, color = "darkorange", alpha = 0.5, size = 1) +
  coord_sf(xlim = c(6, 7.6), ylim = c(49.4, 50.9)) +
  labs(
    title    = "Fire salamander occurrences (GBIF) — Mosel/Eifel (Germany)",
    subtitle = paste(nrow(occ_de), "recorded occurrences"),
    caption  = "GBIF citizen-science records. Presence-only: shows where recorded, not where surveyed."
  ) +
  theme_minimal()

dir.create("figs", showWarnings = FALSE)
ggsave("figs/salamander_occurrences_mosel.png", width = 7, height = 6, dpi = 150)