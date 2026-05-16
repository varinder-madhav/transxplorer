# TransXplorer

**From raw reads to drug-target hypotheses, in one browser tab.**

Most RNA-seq web platforms stop at a list of differentially expressed genes. **TransXplorer continues — through regulatory networks, druggability, and clinical validation — and integrates the entire workflow into a single, free, no-login service.**

🌐 **Live service:** [https://transxplorer.org](https://transxplorer.org)

---

## Why this tool exists

Translational RNA-seq research routinely stalls at the same five gaps:

| Gap | What's typically required | What TransXplorer does |
|---|---|---|
| **Raw-to-counts processing** | Command-line HISAT2 / Salmon, manual GTFs | Built-in FASTQ pipeline, dual quantification, 7 reference genomes + custom |
| **Public-data access** | Manual GEO download, metadata wrangling | Direct GEO Series accession import with auto-metadata parsing |
| **Batch-effect detection** | Manual variable identification, optional correction | **Quantitative composite score** (PVCA + kBET + Silhouette) with automatic limma correction at threshold 0.25 |
| **Multi-organism regulatory inference** | Human/mouse-only databases, separate per-species pipelines | **Hybrid DoRothEA + TFLink** across 11 model organisms with curated activation/repression modes |
| **Translational mapping** | Manual database queries, no clinical context | **Real-time DGIdb + OpenTargets cross-validation** with priority scoring and clinical-phase annotation |

These five gaps, which existing tools (iDEP, NetworkAnalyst, GEPIA2, DEBrowser) only partially address, are the reason TransXplorer exists.

---

## What it does that nothing else does

- **End-to-end in one environment.** FASTQ → QC → DEG → enrichment → PPI → WGCNA → GRN → drug-target → TCGA validation. No data export, no format conversion between tools.
- **Quantitative batch-effect scoring.** PVCA (variance-attribution), kBET (local-mixing), Silhouette (cluster-geometry) combined into a single composite metric with empirically calibrated 0.25 threshold. No other tool flags batch confounders this rigorously.
- **Real-time drug-target query engine.** DGIdb (40+ source databases) cross-validated against OpenTargets clinical evidence; ranked by a priority score that combines bioactivity, clinical phase, and target-coverage. Surfaces FDA-approved cardiac drugs (e.g., Mavacamten) directly from a CMEC-vs-PMEC differential expression run.
- **Hybrid regulatory network inference across 11 organisms.** DoRothEA confidence-graded TF-target relationships for human/mouse, TFLink-derived networks for rat, zebrafish, *Drosophila*, *C. elegans*, *S. cerevisiae*, *Arabidopsis*, chicken, pig, bovine. Master regulators identified by composite influence score (target count × evidence × ChEMBL druggability).
- **CytoHubba-style consensus PPI hubs.** 11 algorithms (MCC, MNC, DMNC, EPC, BottleNeck, EcCentricity, Closeness, Radiality, Betweenness, Stress, Degree) for robust hub detection, replacing single-metric ranking.
- **Auto-optimized WGCNA.** Soft-power selection follows the Langfelder–Horvath sample-size table; module-trait correlations and evidence-based functional categorization are automated.
- **Universal organism support.** 11 pre-installed annotation databases plus on-demand AnnotationHub integration covering ~1,800 species.
- **TCGA integration.** Pre-computed expression matrices across all 33 TCGA cohorts with sub-second boxplots, Kaplan-Meier survival, Cox regression — no waiting on slow API queries.
- **Free, no login, no usage cap.**

---

## Two demonstration use cases

The accompanying manuscript validates TransXplorer on:

1. **Cardiac vs paraxial-mesoderm-derived endothelial differentiation** (GSE151427, n = 22). Demonstrates the full functional + regulatory + translational stack: composite batch-score detection of the differentiation-day confounder, 212 DEGs at |log₂FC| > 2, PPI hub identification (CCND1, GATA4), 7-module WGCNA with cardiac-mesoderm-anchored magenta module (PLN, TECRL, MYOM1), hybrid GRN identifying MYC, E2F1, EGR1, ETS2, SMAD3 as master regulators, and translational mapping recovering Mavacamten (FDA-approved cardiac myosin inhibitor) from the CMEC-vs-PMEC contrast.

2. **TCGA-KIRP (kidney renal papillary cell carcinoma)** (584 samples, 41,553 genes). Demonstrates the clinical-validation arm: 2,447 DEGs, immune-infiltration and ECM-remodelling enrichment, with CCL18 surfaced as the most over-expressed gene (Wilcoxon *P* = 6.57 × 10⁻³⁶) and validated as a prognostic survival marker (HR = 1.86, log-rank *P* = 0.03) — recapitulating CCL18's published role as a tumour-associated-macrophage marker.

---

## Quick start

### Use the free hosted service (recommended)

Just visit [https://transxplorer.org](https://transxplorer.org). No installation, no login.

### Run locally with Docker

```bash
git clone https://github.com/varinder-madhav/transxplorer.git
cd transxplorer
docker compose up -d
# App is now at http://localhost:3838
```

Required: Docker + Docker Compose. The first build downloads reference data (~50 GB if you want all organisms; can be selectively configured — see [`docs/installation.md`](docs/installation.md)).

### Build from source (R Shiny)

```bash
# Install R 4.4+, dependencies in scripts/check_packages.R
Rscript scripts/check_packages.R
# Then run the app
Rscript -e 'shiny::runApp("app/app.R", port = 3838)'
```

See [`docs/installation.md`](docs/installation.md) for full details, reference-data acquisition, and dependency notes.

---

## Documentation

- **[`docs/installation.md`](docs/installation.md)** — Local install, Docker, reference-data setup
- **[`docs/quickstart.md`](docs/quickstart.md)** — 5-minute walkthrough using GSE151427 example
- **[`docs/modules.md`](docs/modules.md)** — Detailed module-by-module reference
- **[`docs/architecture.md`](docs/architecture.md)** — System architecture and design choices
- **[`docs/faq.md`](docs/faq.md)** — Common questions and troubleshooting

---

## How to cite

If you use TransXplorer in your research, please cite the bioRxiv preprint:

> Verma VM, Oler E, Syed H, Han S, Berjanskii M, Mason AL, Wishart DS, Wong GK. TransXplorer: An automated translational discovery platform for RNA-seq data. *bioRxiv*. 2026. doi:[10.64898/2026.05.15.724657](https://doi.org/10.64898/2026.05.15.724657)

A versioned source-code snapshot corresponding to the preprint is tagged at [`v0.1.0-preprint`](https://github.com/varinder-madhav/transxplorer/releases/tag/v0.1.0-preprint).

---

## License

MIT License — see [`LICENSE`](LICENSE). Free for academic and commercial use with attribution.

---

## Reference databases and external resources

TransXplorer integrates the following community resources. Please cite the underlying tools when using TransXplorer for analyses involving each module:

| Module | Underlying resource | Reference |
|---|---|---|
| Differential expression | DESeq2, edgeR, limma | Love 2014; Robinson 2010; Ritchie 2015 |
| Pathway enrichment | clusterProfiler, Reactome, KEGG, MSigDB | Wu 2021; Gillespie 2022 |
| Regulatory networks | DoRothEA, TFLink | Garcia-Alonso 2019; Liska 2022 |
| Co-expression | WGCNA | Langfelder & Horvath 2008 |
| Cell-type deconvolution | xCell, MCP-counter, EPIC | Aran 2017; Becht 2016; Racle 2017 |
| PPI networks | STRING, CytoHubba | Szklarczyk 2023; Chin 2014 |
| Drug-target mapping | DGIdb, OpenTargets, ChEMBL | Freshour 2021; Ochoa 2021; Mendez 2019 |
| TCGA integration | TCGAbiolinks | Colaprico 2016 |
| FASTQ processing | HISAT2, Salmon, FastQC, Trimmomatic | Kim 2019; Patro 2017; Andrews 2010; Bolger 2014 |
| Annotation | AnnotationHub | Bioconductor |

---

## Authors and contact

Developed by **Varinder Madhav Verma**, **Eponine Oler**, **Hussain Syed**, **Scott Han**, **Mark Berjanskii**, **Andrew L. Mason**, **David Scott Wishart**, and **Gane Ka-Shu Wong** at the University of Alberta.

Contact: [varinde2@ualberta.ca](mailto:varinde2@ualberta.ca)

Bug reports / feature requests: [GitHub Issues](https://github.com/varinder-madhav/transxplorer/issues)

---

## Status

Live production service since 2025. Manuscript under final-author review; bioRxiv preprint forthcoming. Active development.
