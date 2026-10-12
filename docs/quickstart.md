# Quickstart — 5-minute walkthrough

This guide reproduces the first use case from the manuscript using the live service. No installation required.

## Goal

In the next 5 minutes, you will:

1. Load a public RNA-seq dataset (bundled as raw counts)
2. Run automated batch-effect detection
3. Identify differentially expressed genes
4. Generate a master regulator network
5. Surface a ranked list of FDA-approved drug candidates

The dataset is **GSE151427** — cardiac (CMEC) vs paraxial-mesoderm-derived (PMEC) endothelial cells from iPSC differentiation, 22 samples.

---

## Step 1 — Open the platform (10 seconds)

Visit [https://transxplorer.org](https://transxplorer.org) and click **Begin Your Analysis** (or **Differential Expression** in the navbar).

## Step 2 — Load the example dataset (1 minute)

In the **Input data** panel:

- Click **Load Example Counts** — raw read counts for the 22 samples, produced by TransXplorer's own FASTQ pipeline from the public runs (see [`examples/README.md`](../examples/README.md))
- Accept the auto-detected groups (11 CMEC, 11 PMEC)
- Click **Load Example Metadata** and confirm — this adds the differentiation and timepoint columns used for batch detection

(**Import from GEO** with `GSE151427` also works, but GEO holds the authors' RPKM table rather than counts; TransXplorer then analyses it with limma on log₂ expression.)

## Step 3 — Run automated batch detection (30 seconds)

Click **Run Exploratory QC**. The platform:

- Computes PVCA, kBET and silhouette for every metadata column, and flags a variable when at least two criteria are met
- Flags the differentiation **timepoint** (day 6 vs 8): PVCA 32.7%, silhouette 0.188
- Adds the timepoint as a covariate in the differential-expression model; `limma::removeBatchEffect` is used only for the before/after PCA and UMAP plots

## Step 4 — Differential expression (30 seconds)

In the **DEG analysis** panel, defaults work:

- Method: **edgeR** (TMM normalization)
- Contrast: PMEC vs CMEC (CMEC as reference)
- Thresholds: |log₂FC| > 2, adjusted *P* < 0.05

Click **Run DEG Analysis**. You should obtain about 1,970 DEGs (1,301 higher in CMEC, 669 higher in PMEC), with GATA4, GATA5, HAND2 and MYL7 up in CMEC and ALDH1A2, FZD10 and CTHRC1 up in PMEC.

## Step 5 — Pathway enrichment (30 seconds)

Switch to **Pathway Enrichment** and click **Run**.

Top GO Biological Process terms include **Anterior/Posterior Pattern Specification** (HOX genes, higher in PMEC) and **Heart Development** (higher in CMEC) — the paraxial and cardiac identities of the two cell types.

## Step 6 — Master regulator inference (1 minute)

Switch to **Advanced Analysis → Gene Regulatory Network** (or the standalone GRN tab with **Use my DEGs**).

TransXplorer builds a TF–target network from DoRothEA for your DEGs, ranks master regulators by how many of the listed genes they regulate, and scores TF activity with VIPER on full DoRothEA regulons. The network plot supports click-to-focus on any TF; edges are colour-coded by activation (green) vs repression (red).

## Step 7 — Drug-target prioritization (1 minute)

Switch to **Advanced Analysis → Drug Targets** and click **Run**.

TransXplorer matches the DEGs to drugs in OpenTargets (local release) and DGIdb and ranks them by number of DEG targets, database evidence and clinical phase.

Expected master regulators and drug candidates for this dataset are being regenerated with the current version.

---

## What you've just done

You have run the end-to-end TransXplorer workflow:

> **Raw counts → batch-aware DEGs → enriched pathways → master regulators → drug candidates** — without leaving the browser, without writing code, in under 5 minutes.

This is the workflow that, in conventional pipelines, requires assembling 6-8 separate command-line tools, each with its own input format, dependencies, and output schema.

---

## Save and share your run

In the top-right of any analysis tab, click **Save Session**. You'll be issued a unique **Run ID** (e.g. `tx-7a8b9c2d`). Bookmark the URL or share it with a collaborator — sessions persist for 7 days and can be resumed across browsers.

## Next steps

- See [`docs/modules.md`](modules.md) for module-by-module reference and parameter tuning
- Try the second use case: **TCGA-KIRP** (kidney renal papillary cell carcinoma) — see the **TCGA** tab and search for `KIRP`
- For your own data, prepare a count matrix (genes × samples) as CSV/TSV/XLSX, or upload paired/single-end FASTQ
