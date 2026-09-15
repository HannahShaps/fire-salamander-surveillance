# fire-salamander-surveillance
### Mapping and modelling the fire salamander (*Salamandra salamandra*) in the German Mosel/Eifel

A reproducible R workflow mapping *Salamandra salamandra* reported occurrences across
the German Mosel/Eifel region and modelling its habitat suitability, built toward a
survey-prioritisation tool for the salamander-plague pathogen
*Batrachochytrium salamandrivorans* (Bsal).

**Status:** work in progress — a learning / portfolio project, not a published result.

## What this is (and isn't)

The occurrence data are presence-only citizen-science records, so each cell shows the
number of fire-salamander records there — not survey effort, and not true abundance. A
busy cell may mean many salamanders or many recorders; a blank cell is not confirmed
absence (it may be unsurveyed, or surveyed but unrecorded). These maps show where the
species has been reported, and their purpose is to flag where records are sparse —
candidates for verification, not confirmed gaps. A future step could effort-correct
these counts by dividing them by total recording activity per cell.

## Study area

Scoped to the German portion of a Mosel/Eifel bounding box (≈ 6.0–7.6°E, 49.4–50.9°N).
Records, grid, protected-area and predictor layers are all clipped to Germany for
consistency — a deliberate national scope, not an ecological boundary.

## Maps

* **M1 — occurrences** (`figs/salamander_occurrences_mosel.png`): every cleaned German
  record as a point.
* **M2 — reported occurrences** (`figs/reported_occurrences_mosel.png`): records binned
  into ~5 km cells; pale = few, dark = many, light-blue = none reported.
* **M3 — records vs protected areas** (`figs/reported_occurrences_protected_mosel.png`):
  reported occurrences over protected-area boundaries — are records concentrated in
  reserves?
* **M4 — modelled habitat suitability** (`figs/suitability_mosel.png`): random-forest
  suitability surface from climate + terrain.
* **M5 — habitat suitability, smoothed** (`figs/suitability_mosel_smoothed.png`): a 3×3
  moving-window mean of M4 that highlights coherent hotspots.

## Habitat suitability model

A first species-distribution model for *S. salamandra* on the German portion of the
study area. Cleaned GBIF presence records (n ≈ 2,570 on valid cells) are contrasted with
10,000 random background points, using six predictors: mean annual temperature,
temperature seasonality, annual precipitation and precipitation seasonality (WorldClim,
~1 km), plus elevation and slope (SRTM-derived). A random forest (`ranger`, probability
forest, 500 trees) is compared against logistic regression on an 80/20 train/test split.

The random forest reaches **AUC ≈ 0.85** on held-out data, clearly ahead of logistic
regression (≈ 0.69) — the gap points to non-linear species–environment relationships
(e.g. a preference for mid elevations). Elevation and mean temperature are the most
important predictors, with slope and precipitation close behind.

**Honest limits.** Suitability is *relative habitat preference*, not occupancy or
abundance. Because the records are presence-only, the model partly reflects *where people
record* as well as where salamanders are. The random (non-spatial) train/test split makes
AUC somewhat optimistic under spatial autocorrelation; a spatial cross-validation would be
stricter. Recording bias is not yet corrected.

## Data & ethics

Occurrence records come from open, openly-licensed sources via GBIF (aggregating
iNaturalist, Observation.org, naturgucker/NABU, Artenfinder and national atlases).
Predictor layers are open data downloaded fresh by the scripts (WorldClim climate;
SRTM-derived elevation/slope), and protected-area boundaries come from the WDPA.
Sensitive-species coordinates can be obscured at source; no precise sensitive locations
are added or shared, outputs are gridded, and raw/large data stays out of the repo
(`data-raw/` and `data-clean/` are git-ignored). Cite the GBIF download when reusing.

## Scripts

* `01_get_occurrences.R` — pull records from GBIF, map occurrences.
* `02_clean_occurrences.R` — clean (`CoordinateCleaner`), scope to Germany, split by
  source, map reported occurrences.
* `03_protected_areas.R` — read WDPA protected areas (low-memory, spatially indexed) and
  overlay them on the reported-occurrence map.
* `04_predictors.R` — download and crop climate + terrain predictor layers to the box.
* `05_suitability_model.R` — build the modelling table, fit logistic regression and
  random forest, map raw and smoothed suitability.

## Progress

* [x] Pull occurrences from GBIF and map them
* [x] Clean records, scope to Germany, count reported occurrences per ~5 km cell
* [x] Overlay protected areas (are records concentrated in reserves?)
* [x] Model habitat suitability from climate + terrain (random forest)
* [ ] Survey-priority layer (suitable habitat + few records = where to verify)
