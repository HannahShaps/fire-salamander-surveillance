# 05_suitability_model.R
# M3 — fire salamander habitat-suitability model (Mosel/Eifel, Germany)
# Stage B: modelling table | Stage C: fit + AUC | Stage D: predict + maps

library(terra)

# ============================================================
# Stage B — build the modelling table
# ============================================================

# --- predictors from Stage A ---
predictors <- rast("data-clean/predictors_mosel.tif")

# --- presence points: cleaned German occurrences from 02_ ---
occ     <- read.csv("data-clean/salamander_occ_de.csv")
pres_xy <- as.matrix(occ[, c("decimalLongitude", "decimalLatitude")])

# --- background points ---
complete <- sum(is.na(predictors)) == 0
complete[complete == 0] <- NA

set.seed(42)
bg_pts <- spatSample(complete, size = 10000, method = "random",
                     as.points = TRUE, na.rm = TRUE, values = FALSE)
bg_xy  <- crds(bg_pts)

# --- extract predictor values, keep the 6 predictor columns by name ---
keep      <- names(predictors)
pres_vals <- as.data.frame(extract(predictors, pres_xy))[, keep, drop = FALSE]
bg_vals   <- as.data.frame(extract(predictors, bg_xy))[,  keep, drop = FALSE]

# --- assemble the modelling table ---
dat <- rbind(
  data.frame(present = 1, pres_vals),
  data.frame(present = 0, bg_vals)
)
dat <- dat[complete.cases(dat), ]

table(dat$present)
summary(dat)

# ============================================================
# Stage C — fit models + score AUC
# ============================================================

for (p in c("ranger", "pROC")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
library(ranger)
library(pROC)

# train / test split (80/20, stratified by present)
set.seed(123)
idx_pres <- which(dat$present == 1)
idx_bg   <- which(dat$present == 0)
train_id <- c(sample(idx_pres, floor(0.8 * length(idx_pres))),
              sample(idx_bg,   floor(0.8 * length(idx_bg))))
train <- dat[train_id, ]
test  <- dat[-train_id, ]

# Model 1: logistic regression
glm_fit <- glm(present ~ ., data = train, family = binomial)
glm_p   <- predict(glm_fit, test, type = "response")
glm_auc <- as.numeric(auc(roc(test$present, glm_p, quiet = TRUE)))

# Model 2: random forest (probability forest; target as a factor)
rf_fit <- ranger(present ~ ., data = transform(train, present = factor(present)),
                 probability = TRUE, num.trees = 500,
                 importance = "permutation", seed = 123)
rf_p   <- predict(rf_fit, test)$predictions[, "1"]
rf_auc <- as.numeric(auc(roc(test$present, rf_p, quiet = TRUE)))

cat(sprintf("Logistic regression AUC: %.3f\n", glm_auc))
cat(sprintf("Random forest AUC:       %.3f\n", rf_auc))
sort(rf_fit$variable.importance, decreasing = TRUE)

# ============================================================
# Stage D — predict suitability surface + maps
# ============================================================

library(ggplot2); library(sf); library(rnaturalearth)
library(rnaturalearthhires); library(ggrepel)
# install.packages("rnaturalearthhires", repos = "https://ropensci.r-universe.dev")

# refit RF on ALL data for the final prediction surface
rf_full <- ranger(present ~ ., data = transform(dat, present = factor(present)),
                  probability = TRUE, num.trees = 500, seed = 123)

# predict suitability across the raster (prob. of class "1"; NA outside Germany)
pred_fun    <- function(model, data) predict(model, data)$predictions[, "1"]
suitability <- predict(predictors, rf_full, fun = pred_fun, na.rm = TRUE)
names(suitability) <- "suitability"
writeRaster(suitability, "data-clean/suitability_mosel.tif", overwrite = TRUE)

# --- context layers (needed by both maps) ---
germany <- ne_countries(scale = "large", country = "Germany", returnclass = "sf")
cities  <- data.frame(
  name = c("Trier", "Koblenz", "Cochem", "Bitburg"),
  lon  = c(6.64, 7.59, 7.17, 6.53),
  lat  = c(49.76, 50.36, 50.15, 49.97))

# skew-tuned breaks (shared by both maps so they read on the same scale)
suit_breaks <- c(-Inf, 0.05, 0.10, 0.20, 0.35, Inf)
suit_labels <- c("Very low", "Low", "Moderate", "High", "Very high")

# --- RAW suitability map ---
suit_df <- as.data.frame(suitability, xy = TRUE, na.rm = TRUE)
suit_df$band <- cut(suit_df$suitability, breaks = suit_breaks, labels = suit_labels)

p_raw <- ggplot() +
  geom_raster(data = suit_df, aes(x, y, fill = band)) +
  geom_sf(data = germany, fill = NA, color = "grey30", linewidth = 0.3) +
  geom_point(data = cities, aes(lon, lat), size = 1.8,
             color = "black", fill = "white", shape = 21, stroke = 0.6) +
  geom_text_repel(data = cities, aes(lon, lat, label = name),
                  size = 3.4, fontface = "bold", color = "black",
                  bg.color = "white", bg.r = 0.18,
                  min.segment.length = 0, box.padding = 0.4) +
  scale_fill_viridis_d(name = "Predicted\nsuitability", drop = FALSE) +
  coord_sf(xlim = c(6, 7.6), ylim = c(49.4, 50.9), expand = FALSE) +
  labs(
    title = "Fire salamander — modelled habitat suitability (Mosel/Eifel, Germany)",
    subtitle = "Random forest on climate + terrain; AUC \u2248 0.85 (held-out test)",
    caption = paste0(
      "Presence-only GBIF records vs 10,000 background points.\n",
      "Climate: WorldClim; terrain: SRTM-derived. Relative preference, not occupancy.\n",
      "Learning/portfolio build; recording bias not corrected."),
    x = NULL, y = NULL) +
  theme_minimal() +
  theme(plot.title = element_text(size = 12),
        plot.caption = element_text(hjust = 0, size = 8),
        panel.background = element_rect(fill = "grey96", color = NA))

ggsave("figs/suitability_mosel.png", plot = p_raw, width = 9, height = 6, dpi = 150)

# --- SMOOTHED companion map ---
suit_smooth <- focal(suitability, w = matrix(1, 3, 3), fun = mean, na.rm = TRUE)
suit_smooth <- mask(suit_smooth, suitability)   # don't bleed past Germany
names(suit_smooth) <- "suitability"
writeRaster(suit_smooth, "data-clean/suitability_mosel_smoothed.tif", overwrite = TRUE)

sm_df <- as.data.frame(suit_smooth, xy = TRUE, na.rm = TRUE)
sm_df$band <- cut(sm_df$suitability, breaks = suit_breaks, labels = suit_labels)

p_smooth <- ggplot() +
  geom_raster(data = sm_df, aes(x, y, fill = band)) +
  geom_sf(data = germany, fill = NA, color = "grey30", linewidth = 0.3) +
  geom_point(data = cities, aes(lon, lat), size = 1.8,
             color = "black", fill = "white", shape = 21, stroke = 0.6) +
  geom_text_repel(data = cities, aes(lon, lat, label = name),
                  size = 3.4, fontface = "bold", color = "black",
                  bg.color = "white", bg.r = 0.18,
                  min.segment.length = 0, box.padding = 0.4) +
  scale_fill_viridis_d(name = "Predicted\nsuitability", drop = FALSE) +
  coord_sf(xlim = c(6, 7.6), ylim = c(49.4, 50.9), expand = FALSE) +
  labs(
    title = "Fire salamander — modelled habitat suitability (Mosel/Eifel, Germany)",
    subtitle = "Random forest; 3\u00d73 moving-window mean (smoothed); AUC \u2248 0.85",
    caption = paste0(
      "Presence-only GBIF records vs 10,000 background points.\n",
      "Climate: WorldClim; terrain: SRTM-derived. Smoothed for regional readability.\n",
      "Relative preference, not occupancy. Portfolio build; recording bias not corrected."),
    x = NULL, y = NULL) +
  theme_minimal() +
  theme(plot.title = element_text(size = 12),
        plot.caption = element_text(hjust = 0, size = 8),
        panel.background = element_rect(fill = "grey96", color = NA))

ggsave("figs/suitability_mosel_smoothed.png", plot = p_smooth, width = 9, height = 6, dpi = 150)
