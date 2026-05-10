# Modules — full reference

TransXplorer is organised as nine analytical modules grouped into three branches: **Functional**, **Regulatory**, and **Translational**, plus a shared **Input / QC** layer.

---

## Input / QC layer

### FASTQ processing

Paired-end and single-end reads are accepted from seven reference genomes (hg38, mm10, rn6, dm6, danRer11, wbcel235, R64) plus user-supplied custom genomes (FASTA + GTF).

Two independent quantification strategies are available:

- **Salmon pseudo-alignment** with `tximport` aggregation to gene level (~10× faster than genomic alignment, recommended default)
- **HISAT2 → featureCounts** for traditional genomic alignment (preferred when you need splice-aware mapping for variant or fusion analysis)

Quality control is integrated: `FastQC` reports before and after `Trimmomatic` adapter removal. Processing runs asynchronously in the background; a job queue manages concurrent analyses and intermediate results are downloadable.

### Direct GEO import

Users enter a GEO Series accession (e.g., `GSE164073`) and the platform:

1. Downloads NCBI-precomputed RNA-seq counts where available (via the standardized HISAT2/featureCounts pipeline NCBI provides)
2. Falls back to GEO supplementary count files if precomputed data is unavailable
3. Falls back to the GEO expression matrix as a last resort
4. Parses sample metadata from GEO's structured fields and presents an interactive variable-selection panel

Eliminates the manual download → format-parse → metadata-build sequence required by most other platforms.

### Differential expression

Three statistical frameworks selectable per run:

- **DESeq2** — negative-binomial GLM with empirical-Bayes shrinkage
- **edgeR** — quasi-likelihood F-tests with robust dispersion estimation
- **limma-voom** — precision-weighted linear models on log-CPM

Normalization options: TMM, RLE, VST, CPM, TPM (each guided by the chosen framework's recommendations).

### Quantitative batch-effect detection

This is one of TransXplorer's distinguishing capabilities. Every metadata column in the uploaded sample annotation is evaluated by three complementary metrics:

| Metric | What it measures | Flag threshold |
|---|---|---|
| **PVCA** (Principal Variance Component Analysis) | Fraction of variance attributable to each metadata variable, via linear mixed-model on leading PCs | > 15% of total variance |
| **kBET** (k-nearest-neighbour Batch Entropy Test) | Whether samples from different batch categories mix locally in expression space | rejection rate > 0.3 |
| **Silhouette coefficient** | Whether samples cluster by batch label rather than biological state | normalized score > 0.15 |

These three are combined into a composite score:

```
score = 0.4 × PVCA + 0.4 × kBET + 0.2 × Silhouette
```

PVCA and kBET receive equal higher weight because they probe complementary aspects of confounding (global variance structure vs local sample mixing); Silhouette is down-weighted because clustering geometry is sensitive to unbalanced group sizes.

When the composite exceeds **0.25**, `limma::removeBatchEffect` is automatically applied and the variable is incorporated as a covariate in subsequent DEG models. PCA and UMAP projections are generated before and after correction for visual confirmation.

The 0.25 threshold was empirically calibrated on benchmark datasets with known batch structure (GSE49712, GSE115736).

---

## Functional branch

### Pathway enrichment

`clusterProfiler` 4.0 over GO (BP/MF/CC), KEGG, Reactome, WikiPathways, and MSigDB Hallmark gene sets. Both ORA (over-representation) and GSEA (gene-set enrichment) modes are available. The full set of tested genes is used as the statistical background — important for honest enrichment statistics.

Outputs: dot plots, lollipop plots, cnetplots (bipartite pathway-gene networks for cross-database overlap detection), and downloadable enrichment tables.

### Protein-protein interaction (PPI) networks

STRING-based PPI assembly with locally cached human and mouse data (no API rate limits). Hub identification uses **Louvain clustering plus 11 CytoHubba algorithms** for consensus hub ranking:

> Degree, MNC, MCC, DMNC, EPC, BottleNeck, EcCentricity, Closeness, Radiality, Betweenness, Stress

A consensus rank across all 11 algorithms reduces single-metric artefacts. Druggability annotation overlays ChEMBL bioactivity counts onto each hub.

### Auto-optimized WGCNA

Soft-power selection automated per the **Langfelder–Horvath sample-size table**:

| Sample size | Default power |
|---|---|
| n < 20 | 9 |
| 20 ≤ n < 30 | 8 |
| 30 ≤ n < 40 | 7 |
| n ≥ 40 | 6 |

The platform iterates `pickSoftThreshold` over powers 1–20 and picks the smallest power achieving R² ≥ 0.8 scale-free fit; falls back to the canonical sample-size value when no power achieves the target.

Modules are identified via hierarchical clustering with dynamic tree cutting. Module eigengenes are correlated with sample traits; functional categorization assigns each module to evidence-based categories (Cell Cycle, DNA/RNA/Protein Homeostasis, Immune, Signaling, etc.).

### Cell-type deconvolution

Three complementary methods, each suited to a distinct biological setting:

| Method | Output | Best for |
|---|---|---|
| **MCP-counter** | Absolute abundance of 10 immune + 2 stromal populations | Tumour microenvironment, immune profiling |
| **EPIC** | Cell-type fractions optimized for tumour samples | Cancer studies |
| **xCell** | Gene-signature enrichment scores for 64 cell types | Broad tissue characterization |

Outputs: per-sample stacked bars, per-cell-type box plots, group-level Wilcoxon comparisons with Benjamini-Hochberg correction.

---

## Regulatory branch

### Hybrid gene regulatory network inference

This is the platform's signature regulatory capability. Two databases are integrated:

- **DoRothEA** (human, mouse) — curated TF-target interactions with confidence levels A (ChIP-seq-validated direct binding), B (≥2 evidence types), C (single computational method), D (lower confidence). TransXplorer uses A–C by default.
- **TFLink** (rat, zebrafish, *Drosophila*, *C. elegans*, *S. cerevisiae*, *Arabidopsis*, chicken, pig, bovine) — predicted associations from literature mining and computational inference

Master regulators are ranked by a **composite influence score**:

```
score = target_count × evidence_confidence × ChEMBL_druggability_factor
```

Mode-of-regulation (activation = +1, repression = −1) propagates through the network rendering: edges are coloured **green for activation** and **red for repression** in the master-regulator subnetwork (DoRothEA-only — TFLink does not carry mode-of-regulation).

### TF activity inference

When expression data is available, viper computes per-sample TF activity scores via gene-set enrichment of each TF's regulon. Activity heatmaps cluster TFs by differential activity across conditions, surfacing condition-specific regulatory rewiring beyond simple expression-level shifts.

---

## Translational branch

### Drug-target discovery and prioritization

Two complementary databases are queried in real time:

- **DGIdb 4.0** — aggregates drug-target relationships from 40+ sources including ChEMBL, DrugBank, PharmGKB, Therapeutic Target Database, CIViC
- **OpenTargets** — clinical trial data, disease associations, target tractability scores

Three analysis modes:

| Mode | Focus |
|---|---|
| **Drug Discovery** | DGIdb / ChEMBL bioactivity-centric |
| **Disease Context** | OpenTargets clinical-evidence-centric |
| **Comprehensive** | Cross-validated against both databases |

Results are ranked by a **TransXplorer Priority Score** combining clinical development phase, source-database concordance, target coverage, and evidence quality. Targets appearing in both databases are flagged as high-confidence candidates.

### TCGA integration and clinical validation

Pre-computed expression matrices across **all 33 TCGA cancer cohorts** enable sub-second:

- Tumour-vs-normal differential expression
- Gene-level boxplots (log₂(TPM+1))
- Kaplan-Meier survival curves with log-rank test, dichotomized at median or quartile
- Cox proportional hazards regression with hazard ratios and 95% CIs

The pre-computation eliminates the slow live-API round-trip that affects platforms relying on TCGAbiolinks queries at runtime.

---

## Universal organism support

| Organism class | Support level | Modules |
|---|---|---|
| **Pre-installed (11 organisms)** | Full | All modules |
| Human, mouse, rat, *Drosophila*, zebrafish, *C. elegans*, yeast, *Arabidopsis*, chicken, pig, cow | | |
| **AnnotationHub on-demand (~1,800 species)** | Functional enrichment + GO + KEGG | DEG, pathway enrichment, basic functional analysis |
| **Unsupported** | DEG and basic stats only | DEG, basic plots; deconvolution / drug-target / DoRothEA-GRN auto-disabled with explanatory UI message |

KEGG pathway analysis is available for the ~8,000 organisms in the KEGG database. GO enrichment is supported for any organism with an OrgDb entry.

---

## Output formats

Every module supports:

- **CSV / TSV / XLSX** for tables
- **PNG / PDF / SVG** for plots
- **HTML** for interactive networks (visNetwork, plotly)
- **HTML report** — comprehensive analysis summary with all stats, top regulators, top edges, enrichment tables (see [`Summary & Export`](#) tab on the GRN module)
- **TXT summary** — plain-text recap for notes / Slack / git commits

Session save / restore is universal: every module's results are stored under a unique Run ID and recoverable across browsers for 7 days.
