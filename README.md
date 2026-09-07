# fire-salamander-surveillance

A reproducible R workflow mapping fire salamander (*Salamandra salamandra*)
**reported occurrences** across the German Mosel/Eifel region, built toward a
survey-prioritisation tool for the salamander-plague pathogen
*Batrachochytrium salamandrivorans* (Bsal).

**Status:** work in progress — a learning / portfolio project, not a published result.

## What this is (and isn't)

The data are **presence-only** citizen-science records, so each cell shows the
**number of fire-salamander records** there — not survey effort, and not true
abundance. A busy cell may mean many salamanders *or* many recorders; a blank
cell is **not** confirmed absence (it may be unsurveyed, or surveyed but
unrecorded). These maps show *where the species has been reported*, and their
purpose is to flag where records are sparse — candidates for verification, not
confirmed gaps. A future step could effort-correct these counts by dividing them
by total recording activity per cell.

## Study area
Scoped to the **German portion** of a Mosel/Eifel bounding box
(≈ 6.0–7.6°E, 49.4–50.9°N). Records, grid and (upcoming) protected-area layers are
all clipped to Germany for consistency — a deliberate national scope, not an
ecological boundary.

## Maps
- **M1 — occurrences** (`figs/salamander_occurrences_mosel.png`): every cleaned
  German record as a point.
- **M2 — reported occurrences** (`figs/reported_occurrences_mosel.png`): records
  binned into ~5 km cells; pale = few, dark = many, light-blue = none reported.

## Data & ethics
Records come from open, openly-licensed sources via **GBIF** (aggregating
iNaturalist, Observation.org, naturgucker/NABU, Artenfinder and national atlases).
Sensitive-species coordinates can be obscured at source; no precise sensitive
locations are added or shared, outputs are gridded, and raw data stays out of the
repo (`data-clean/` is git-ignored). Cite the GBIF download when reusing.

## Scripts
- `01_get_occurrences.R` — pull records from GBIF, map occurrences.
- `02_clean_occurrences.R` — clean (`CoordinateCleaner`), scope to Germany,
  split by source, map reported occurrences.

## Progress
- [x] Pull occurrences from GBIF and map them
- [x] Clean records, scope to Germany, count reported occurrences per ~5 km cell
- [ ] Overlay protected areas (are records concentrated in reserves?)
- [ ] Survey-priority layer (suitable habitat + few records = where to verify)
