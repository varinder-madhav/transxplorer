# Examples

Reference datasets used in the manuscript and validated end-to-end through the platform.

## GSE151427 — cardiac vs paraxial-mesoderm endothelial differentiation

iPSC-derived **cardiac mesoderm-derived endothelial cells (CMEC)** vs **paraxial mesoderm-derived endothelial cells (PMEC)** sampled at differentiation days 6 and 8 (n = 22, 11 per condition).

This is the headline use case demonstrating the full Functional + Regulatory + Translational stack:

- **Batch detection** — composite score 0.559 flags differentiation-day as a confounder; `limma::removeBatchEffect` automatic correction
- **Differential expression** — 212 DEGs at |log₂FC| > 2, adjusted P < 0.05
- **Pathway enrichment** — Heart Development (GO:0007507) is the top term
- **PPI** — 158 proteins, 884 interactions; CCND1, GATA4 as cardiac hubs
- **WGCNA** — 7 modules, magenta module (PLN, TECRL, MYOM1) anchors the cardiac-mesoderm signature
- **GRN** — MYC, E2F1, EGR1, ETS2, SMAD3 as master regulators across 2,758 regulatory edges
- **Drug-target** — Mavacamten (FDA-approved cardiac myosin inhibitor) recovered from the contrast

To reproduce: open the platform → **GEO Import** → enter `GSE151427` → follow the workflow described in [`docs/quickstart.md`](../docs/quickstart.md).

## TCGA-KIRP — kidney renal papillary cell carcinoma

The TCGA Kidney Renal Papillary Cell Carcinoma cohort (n = 584 samples; 41,553 genes) demonstrates the clinical-validation arm of the platform:

- **Differential expression** (tumour vs normal) — 2,447 DEGs at |log₂FC| ≥ 2
- **Pathway enrichment** — immune cell infiltration, ECM remodelling, metabolic reprogramming
- **Clinical validation** — CCL18 surfaces as the most over-expressed gene (Wilcoxon *P* = 6.57 × 10⁻³⁶), Kaplan-Meier survival shows worse outcomes at high CCL18 (HR = 1.86, log-rank *P* = 0.03)

CCL18's published role as a tumour-associated-macrophage marker (Chen 2011, Xu 2020) provides external biological validation for the platform's unbiased target-discovery output.

To reproduce: open the platform → **TCGA** tab → search `KIRP` → run differential expression on tumour vs normal → drill into CCL18 boxplot and survival.

## Adding your own examples

Pull requests welcome. Please include:

- The accession or data source (publicly available preferred)
- A short narrative of the analytical question
- Expected key outputs (top DEGs, master regulators, etc.)
- Approximate runtime
