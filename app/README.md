# Application code

The single-file Shiny application that powers TransXplorer.

## File structure

- `app.R` — the entire Shiny application (UI + server + analytical functions). Single-file architecture is a deliberate choice for atomic deployment; see [`docs/architecture.md`](../docs/architecture.md) for the rationale.

## Running locally

From the repository root:

```bash
# Via Docker (recommended)
docker compose up -d --build

# Native R Shiny
Rscript -e 'options(shiny.maxRequestSize = 15000 * 1024^2); shiny::runApp("app/app.R", port = 3838, host = "0.0.0.0")'
```

The 15 GB upload size limit is required for FASTQ inputs.

## Code organization within `app.R`

The file is organized as roughly:

| Section | What it contains |
|---|---|
| **Lines 1-300** | Custom CSS for the homepage and all module styling |
| **Header functions** | Lazy-loading helpers (`load_network_packages`, `load_export_packages`, etc.) for keeping idle memory low |
| **UI scaffold** | `bslib::page_navbar` with one `tabPanel` per analytical branch |
| **Pipeline functions** | Standalone analytical functions (`run_grn_analysis_corrected`, `build_regulatory_network_fixed_final`, `identify_master_regulators_fixed`, etc.) |
| **Server function** | All `observeEvent`, `reactiveValues`, `renderUI` blocks. Per-tab namespaces (`grn_standalone_rv`, `wgcna_rv`, `ppi_rv`, etc.) |
| **Bottom (line ~120000+)** | App initialization, `shinyApp(ui, server)` |

## Searching the code

The single-file approach makes `grep` your primary navigation tool. Useful search patterns:

```bash
# Find a function definition
grep -n "^[a-z_]*  *<- function" app/app.R | head

# Find all observers for a specific input
grep -n "observeEvent(input\$<input_id>" app/app.R

# Find all reactiveValues namespaces
grep -n "<- reactiveValues(" app/app.R

# Find all download handlers
grep -n "downloadHandler" app/app.R
```

## Conventions

- **Reactive namespaces.** Each tab's state lives under its own `reactiveValues` (e.g., `grn_standalone_rv$grn_results`). Don't mutate cross-tab state.
- **Mode awareness.** GRN, WGCNA, and PPI standalone tabs all support quick (gene list only) and full (DEG file) modes. Mode is tracked via an `*_active` flag on the per-tab reactiveValues. New features must check the mode and behave accordingly.
- **Lazy package loading.** Heavy packages (visNetwork, plotly, openxlsx, etc.) are loaded inside `observeEvent` blocks via the `load_*` helpers, not at top-of-file. This keeps the idle Shiny worker under 1 GB RAM.
- **Defensive validation.** `req()` early in every renderer; explicit `if (is.null(...) || length(...) == 0)` guards before any `intersect`, `merge`, or `select`.
- **Tracked changes for legend / methods edits.** When the GRN, PPI, or WGCNA pipelines change in ways that affect the manuscript, update both the code AND the corresponding figure legends in the manuscript folder.

## Testing

There is no formal test suite. Manual verification is performed against the example datasets (GSE151427 for human / DoRothEA path; TCGA-KIRP for TCGA path). Future work: programmatic golden-file tests via shinytest2.
