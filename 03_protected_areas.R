# 03_protected_areas.R
# Overlay WDPA protected areas on the reported-occurrences map (Mosel/Eifel, Germany).
# Reads ONLY the in-box polygons from a spatial-indexed geodatabase (low-memory).

source("02_clean_occurrences.R")   # rebuilds occ_de, full_grid, germany, cities, n_de
library(ggplot2)

# --- protected areas: read only the Mosel/Eifel box from the zipped .gdb ---
sf::sf_use_s2(FALSE)

zip_path <- normalizePath("data-clean/WDPA_Sep2026_DEU-shapefile.zip", winslash = "/")
gdb      <- paste0("/vsizip/", zip_path, "/WDPA_WDOECM_Sep2026_Public_DEU.gdb")

box_wkt <- st_as_text(st_as_sfc(st_bbox(
  c(xmin = 6, xmax = 7.6, ymin = 49.4, ymax = 50.9), crs = 4326)))

lyr        <- st_layers(gdb)
poly_layer <- lyr$name[grepl("poly", lyr$name, ignore.case = TRUE)][1]

pa_box <- st_read(gdb, layer = poly_layer, wkt_filter = box_wkt, quiet = TRUE)
pa_box <- st_make_valid(pa_box)

# --- map: records (warm) over protected areas (pale green) ---
warm_cols <- c(
  "1-2" = "#ffffb2", "3-5" = "#fed976", "6-10" = "#feb24c",
  "11-20" = "#fd8d3c", "21-40" = "#f03b20", "41+" = "#bd0026"
)

full_grid_rec <- subset(full_grid, records > 0)

pa_map <- ggplot() +
  geom_sf(data = germany, fill = "#c7e9c0", color = "grey70", linewidth = 0.3) +
  geom_sf(data = pa_box, fill = "#a1d99b", color = NA) +
  geom_tile(data = full_grid_rec, aes(lon_bin, lat_bin, fill = records_band)) +
  geom_point(data = cities, aes(lon, lat), color = "black", size = 1.6) +
  geom_text_repel(data = cities, aes(lon, lat, label = name),
                  color = "black", size = 3, min.segment.length = 0, seed = 1) +
  scale_fill_manual(values = warm_cols, name = "records per\n~5 km cell", drop = FALSE) +
  coord_sf(xlim = c(6, 7.6), ylim = c(49.4, 50.9)) +
  labs(
    title    = "Fire salamander records vs protected areas — Mosel/Eifel (Germany)",
    subtitle = paste(n_de, "reported occurrences · green = land, darker green = protected"),
    caption  = "Green: WDPA protected areas. Records presence-only; blank = no records, NOT confirmed absence."
  ) +
  theme_minimal()

pa_map

ggsave("figs/reported_occurrences_protected_mosel.png", pa_map, width = 7, height = 6, dpi = 150)