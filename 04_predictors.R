# 04_predictors.R
# M3 Stage A — download + crop predictor rasters (climate + terrain)
# Runs standalone. Kept low-memory: crop to the box straight away.

# --- packages (installs terra/geodata only if missing) ---
for (p in c("terra", "geodata")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
library(terra)
library(geodata)

# --- study box (same as the occurrence scripts) ---
# xmin, xmax, ymin, ymax  in EPSG:4326
box <- ext(6.0, 7.6, 49.4, 50.9)

dir.create("data-raw",   showWarnings = FALSE)  # big downloads live here
dir.create("data-clean", showWarnings = FALSE)  # cropped outputs live here

# --- CLIMATE: WorldClim bioclim, ~1 km (30 arc-sec) ---
# Download just the one tile covering the region, then crop.
wc_tile <- worldclim_tile(var = "bio", lon = 6.8, lat = 50.1, path = "data-raw")

# Pick a lean, low-overlap subset (not all 19 — avoids overfitting):
#   bio1  = annual mean temperature
#   bio4  = temperature seasonality
#   bio12 = annual precipitation
#   bio15 = precipitation seasonality
# Select by trailing number so it works regardless of layer order/prefix.
want <- c(1, 4, 12, 15)
idx  <- sapply(want, function(n) which(grepl(paste0("bio_?", n, "$"), names(wc_tile))))
wc   <- crop(wc_tile[[idx]], box)
names(wc) <- c("temp_mean", "temp_seasonality", "precip_annual", "precip_seasonality")

# --- TERRAIN: elevation ~1 km, then slope ---
elev  <- crop(elevation_30s(country = "DEU", path = "data-raw"), box)
slope <- terrain(elev, v = "slope", unit = "degrees")
names(elev) <- "elevation"; names(slope) <- "slope"

# align terrain onto the climate grid so all layers stack cleanly
elev  <- resample(elev,  wc, method = "bilinear")
slope <- resample(slope, wc, method = "bilinear")

# --- stack + save the cropped predictors for the modelling step ---
predictors <- c(wc, elev, slope)
writeRaster(predictors, "data-clean/predictors_mosel.tif", overwrite = TRUE)

# --- quick check ---
print(predictors)
plot(predictors)
