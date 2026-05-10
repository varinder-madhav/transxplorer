# Quickstart — 5-minute walkthrough

This guide reproduces the first use case from the manuscript using the live service. No installation required.

## Goal

In the next 5 minutes, you will:

1. Import a public RNA-seq dataset directly from GEO
2. Run automated batch-effect detection and correction
3. Identify differentially expressed genes
4. Generate a master regulator network
5. Surface a ranked list of FDA-approved drug candidates

The dataset is **GSE151427** — cardiac (CMEC) vs paraxial-mesoderm-derived (PMEC) endothelial cells from iPSC differentiation, 22 samples.

---

## Step 1 — Open the platform (10 seconds)

Visit [https://transxplorer.org](https://transxplorer.org) and click **Begin Your Analysis** (or **Differential Expression** in the navbar).

## Step 2 — Import the GEO dataset (1 minute)

In the **Input data** panel:

- Select **"Import from GEO"**
- Enter accession: `GSE151427`
- Click **Fetch**

The platform retrieves the count matrix and parses sample metadata from GEO's structured fields. You'll see a clean experimental-variable table appear; select **"condition"** as the primary grouping variable (CMEC vs PMEC).

## Step 3 — Run automated batch detection (30 seconds)

The platform automatically:

- Computes PVCA, kBET, Silhouette for every metadata column
- Combines into a composite score (0.4 × PVCA + 0.4 × kBET + 0.2 × Silhouette)
- Flags **"Time"** (differentiation day 6 vs 8) as a confounder (composite = 0.559, threshold = 0.25)
- Applies `limma::removeBatchEffect` automatically and re-runs PCA / UMAP

You'll see PCA before/after panels; post-correction, samples cluster by biological condition along PC1.

## Step 4 — Differential expression (30 seconds)

In the **DEG analysis** panel, defaults work:

- Method: **edgeR** (TMM normalization)
- Contrast: CMEC vs PMEC
- Thresholds: |log₂FC| > 2, adjusted *P* < 0.05

Click **Run DEG**. You should obtain ~212 DEGs.

## Step 5 — Pathway enrichment (30 seconds)

Switch to **Functional → Pathway Enrichment**. Click **Run**.

Top enriched terms include **Heart Development (GO:0007507)**, ECM organization, focal adhesion — consistent with cardiac mesoderm-derived endothelial specification.

## Step 6 — Master regulator inference (1 minute)

Switch to **Regulatory → GRN Analysis**.

- Organism: **Human**
- Database: **Hybrid** (DoRothEA + TFLink)
- Confidence threshold: **0.6**
- Click **Run GRN Analysis**

The platform identifies master regulators: **MYC, E2F1, EGR1, ETS2, SMAD3** lead the 10-TF master-regulator set. The network plot supports click-to-focus on any TF; edges are colour-coded by activation (green) vs repression (red).

## Step 7 — Drug-target prioritization (1 minute)

Switch to **Translational → Drug Discovery**.

- Mode: **Comprehensive (DGIdb + OpenTargets)**
- Click **Run**

The priority-ranked table includes **Mavacamten** (FDA-approved cardiac myosin inhibitor for hypertrophic cardiomyopathy), recovered directly from the CMEC vs PMEC contrast. This is the translational anchor of the use case — a known cardiac therapeutic surfaced from an unbiased differential expression analysis.

---

## What you've just done

You have run the end-to-end TransXplorer workflow:

> **GEO accession → automated batch-corrected DEGs → enriched pathways → master regulators → drug candidates** — without leaving the browser, without writing code, in under 5 minutes.

This is the workflow that, in conventional pipelines, requires assembling 6-8 separate command-line tools, each with its own input format, dependencies, and output schema.

---

## Save and share your run

In the top-right of any analysis tab, click **Save Session**. You'll be issued a unique **Run ID** (e.g. `tx-7a8b9c2d`). Bookmark the URL or share it with a collaborator — sessions persist for 7 days and can be resumed across browsers.

## Next steps

- See [`docs/modules.md`](modules.md) for module-by-module reference and parameter tuning
- Try the second use case: **TCGA-KIRP** (kidney renal papillary cell carcinoma) — see the **TCGA** tab and search for `KIRP`
- For your own data, prepare a count matrix (genes × samples) as CSV/TSV/XLSX, or upload paired/single-end FASTQ
