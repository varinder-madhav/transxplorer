# Examples

Reference datasets used in the manuscript and validated end-to-end through the platform.

## GSE151427 — cardiac vs paraxial-mesoderm endothelial differentiation

iPSC-derived **cardiac mesoderm-derived endothelial cells (CMEC)** vs **paraxial mesoderm-derived endothelial cells (PMEC)**, 11 samples each from six independent differentiations, harvested at day 6 and day 8 (n = 22). Data: GEO [GSE151427](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE151427); study: Cao et al. 2025, *iScience* 28:113611, [doi:10.1016/j.isci.2025.113611](https://doi.org/10.1016/j.isci.2025.113611).

The bundled example (`app/data/example_counts_GSE151427.csv`, `example_metadata_GSE151427.csv`) holds **raw read counts produced by TransXplorer's own FASTQ pipeline** from the 22 public runs (SRR11873825–SRR11873846): HISAT2 alignment to hg38, featureCounts with GENCODE v47 (68.9% of reads assigned to genes, median). Genes are named by GENCODE gene name, genes sharing a name are summed, and only genes with at least 5 reads in at least 2 samples are kept (27,785 genes, 99.96% of reads). Earlier versions bundled the authors' RPKM table instead.

With the default settings (edgeR, TMM, adjusted P < 0.05, |log₂FC| > 2):

- **Batch detection** flags the differentiation timepoint (PVCA 32.7%, silhouette 0.188); it is included as a covariate in the DE model
- **Differential expression** — 1,970 DEGs (1,301 higher in CMEC, 669 higher in PMEC); GATA4, GATA5, HAND2 and MYL7 up in CMEC, ALDH1A2, FZD10 and CTHRC1 up in PMEC
- **Pathway enrichment** (GO Biological Process) — anterior/posterior pattern specification (HOX genes, higher in PMEC) and heart development (higher in CMEC) lead the list

`example_deg_results.csv` is the edgeR result for this contrast (cell type only). PPI, WGCNA, GRN and drug-target results on these counts are being regenerated with the current version.

To reproduce: open the platform → **Differential Expression** → **Load Example Counts**, then **Load Example Metadata** → **Run DEG Analysis**. The counts can also be regenerated from the raw data with **FASTQ Processing** → **Public data** → the run accessions above.

## TCGA-KIRP — kidney renal papillary cell carcinoma

The TCGA Kidney Renal Papillary Cell Carcinoma cohort demonstrates the clinical-validation arm of the platform: differential expression of primary tumour vs solid tissue normal, expression box plots, and survival analysis (one primary-tumour sample per patient).

- **Survival** — CCL18 high vs low expression (median split, 253 patients): hazard ratio 0.48 (95% CI 0.26–0.88), log-rank *P* = 0.015 — higher CCL18 is associated with **better** overall survival. (Versions before October 2026 reported the hazard ratio inverted.)

To reproduce: open the platform → **TCGA** tab → choose `TCGA-KIRP` → run differential expression on tumour vs normal → CCL18 box plot and survival.

## Adding your own examples

Pull requests welcome. Please include:

- The accession or data source (publicly available preferred)
- A short narrative of the analytical question
- Expected key outputs (top DEGs, master regulators, etc.)
- Approximate runtime
