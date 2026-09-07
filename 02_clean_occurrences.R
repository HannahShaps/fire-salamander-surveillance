# 02_clean_occurrences.R
# Fire salamander surveillance — clean GBIF occurrences, split by source,
# and map survey coverage (sampling gaps) for the Mosel/Eifel.

# --- packages (install once if needed) ---
# install.packages(c("rgbif","dplyr","ggplot2","sf","rnaturalearth",
#                     "rnaturalearthdata","CoordinateCleaner","usethis"))
library(rgbif)
library(dplyr)
library(ggplot2)
library(sf)
library(rnaturalearth)
library(CoordinateCleaner)

# --- 1. pull all records in the Mosel/Eifel box ---
gbif <- occ_data(
  scientificName   = "Salamandra salamandra",
  decimalLongitude = "6.0,7.6",
  decimalLatitude  = "49.4,50.9",
  hasCoordinate    = TRUE,
  limit            = 4000
)

occ <- gbif$data |>
  select(
    gbifID          = key,
    scientificName,
    decimalLongitude,
    decimalLatitude,
    coordinateUncertaintyInMeters,
    year,
    basisOfRecord,
    datasetKey,
    institutionCode,
    publisher       = publishingOrgKey
  )

# --- 2. clean ---
occ_clean <- occ |>
  distinct(gbifID, .keep_all = TRUE) |>
  filter(decimalLongitude != 0, decimalLatitude != 0) |>
  filter(is.na(coordinateUncertaintyInMeters) | coordinateUncertaintyInMeters <= 1000)

flags <- clean_coordinates(
  x       = occ_clean,
  lon     = "decimalLongitude",
  lat     = "decimalLatitude",
  species = "scientificName",
  tests   = c("centroids", "equal", "gbif", "institutions", "zeros")
)
occ_clean <- occ_clean[flags$.summary, ]

# --- 3. label sources ---
occ_clean <- occ_clean |>
  mutate(source = case_when(
    grepl("iNaturalist",      institutionCode, ignore.case = TRUE) ~ "iNaturalist",
    grepl("naturgucker|NABU", institutionCode, ignore.case = TRUE) ~ "naturgucker/NABU",
    grepl("artenfinder",      institutionCode, ignore.case = TRUE) ~ "Artenfinder",
    grepl("observation",      institutionCode, ignore.case = TRUE) ~ "Observation.org",
    is.na(institutionCode)                                         ~ "Unknown/other",
    TRUE                                                           ~ "Other"
  ))
print(count(occ_clean, source, sort = TRUE))


#3b. Checking sampling spread
summary(full_grid$records[full_grid$records > 0])
max(full_grid$records)


# --- 4. grid (~5 km cells), clip to Germany, band records (skew-aware) ---
germany <- ne_countries(scale = "medium", country = "Germany", returnclass = "sf")

cell <- 0.05

grid_counts <- occ_clean |>
  mutate(
    lon_bin = floor(decimalLongitude / cell) * cell + cell / 2,
    lat_bin = floor(decimalLatitude  / cell) * cell + cell / 2
  ) |>
  count(lon_bin, lat_bin, name = "records")

full_grid <- expand.grid(
  lon_bin = seq(6.0 + cell/2, 7.6, by = cell),
  lat_bin = seq(49.4 + cell/2, 50.9, by = cell)
) |>
  left_join(grid_counts, by = c("lon_bin", "lat_bin")) |>
  mutate(records = ifelse(is.na(records), 0, records))

grid_pts  <- st_as_sf(full_grid, coords = c("lon_bin", "lat_bin"),
                      crs = 4326, remove = FALSE)
inside    <- lengths(st_within(grid_pts, germany)) > 0
full_grid <- full_grid[inside, ] |>
  mutate(
    records_band = cut(
      records,
      breaks = c(-1, 0, 2, 5, 10, 20, 40, Inf),
      labels = c("0 (none)", "1-2", "3-5", "6-10", "11-20", "21-40", "41+")
    )
  )

# --- 5. map: survey coverage (skew-aware blue scale) ---
cities <- data.frame(
  name = c("Trier", "Koblenz", "Cochem", "Bitburg"),
  lon  = c(6.64, 7.59, 7.17, 6.53),
  lat  = c(49.76, 50.36, 50.15, 49.97)
)

band_cols <- c(
  "0 (none)" = "#deebf7",
  "1-2"      = "#c6dbef",
  "3-5"      = "#9ecae1",
  "6-10"     = "#6baed6",
  "11-20"    = "#4292c6",
  "21-40"    = "#2171b5",
  "41+"      = "#084594"
)

gap_map <- ggplot() +
  geom_tile(data = full_grid, aes(lon_bin, lat_bin, fill = records_band)) +
  geom_sf(data = germany, fill = NA, color = "grey40", linewidth = 0.3) +
  geom_point(data = cities, aes(lon, lat), color = "red", size = 1.6) +
  geom_text(data = cities, aes(lon, lat, label = name),
            color = "red", size = 3, hjust = -0.15, vjust = 0.3) +
  scale_fill_manual(values = band_cols, name = "records per\n~5 km cell", drop = FALSE) +
  coord_sf(xlim = c(6, 7.6), ylim = c(49.4, 50.9)) +
  labs(
    title    = "Fire salamander survey coverage — Mosel/Eifel",
    subtitle = paste(nrow(occ_clean), "cleaned records · light blue = unsampled"),
    caption  = "Open citizen-science data via GBIF. Bands are finer at low counts (where most cells sit)."
  ) +
  theme_minimal()

gap_map

# --- 6. save outputs ---
dir.create("figs",       showWarnings = FALSE)
dir.create("data-clean", showWarnings = FALSE)
ggsave("figs/sampling_density_mosel.png", gap_map, width = 7, height = 6, dpi = 150)
write.csv(occ_clean, "data-clean/salamander_occ_clean.csv", row.names = FALSE)
usethis::use_git_ignore("data-clean/")

