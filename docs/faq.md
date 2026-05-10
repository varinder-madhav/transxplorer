# FAQ

## General

### Is the hosted service free? Forever?

Yes. The platform at [https://transxplorer.org](https://transxplorer.org) is free, requires no login, and has no usage cap. It's hosted on academic infrastructure at the University of Alberta. There are no plans to introduce paid tiers, but reasonable use is appreciated — please don't abuse it as a free compute back-end for unrelated workloads.

### Can I use TransXplorer for commercial work?

Yes. The code is MIT-licensed (see [`LICENSE`](../LICENSE)) and the hosted service is free for any use. We ask that you cite the paper (forthcoming on bioRxiv) in any publications.

### Will my data be private?

Yes. Uploaded data is stored under a per-session run ID and is not visible to other users. Data is automatically purged after 7 days unless you save the run. The platform performs no telemetry or tracking beyond standard server logs (nginx access logs, retained 30 days).

For sensitive data (e.g., protected health information, unpublished proprietary results), we strongly recommend running TransXplorer locally via Docker rather than uploading to the public service. Local installation gives you full data sovereignty.

### Which web browsers are supported?

Modern Chrome, Firefox, Safari, and Edge. Mobile is not supported (Shiny apps are desktop-class).

---

## Data and inputs

### What input formats are accepted?

| Input type | Formats |
|---|---|
| **Count matrix** | CSV, TSV, TXT, XLSX (genes × samples) |
| **Sample metadata** | CSV, TSV (rows = samples, columns = annotations) |
| **FASTQ** | `.fastq`, `.fastq.gz`, paired or single-end |
| **GEO accession** | `GSEnnnnnn` directly |

### How big a dataset can I upload?

Hosted service: up to 10 GB per file, ~100 GB per session. Local installation: configurable in `docker-compose.yml` (`MAX_UPLOAD_SIZE`).

For practical guidance:
- A 22-sample × 60,000-gene count matrix is ~10 MB
- A FASTQ file at 30M reads is ~3-5 GB compressed
- WGCNA on >20,000 genes / >50 samples may exhaust the default 16 GB memory limit; raise the container limit in `docker-compose.yml`

### Can I import my own GEO accession?

Yes — any GEO Series accession (`GSEnnnnnn`) with available count data works. The platform will:
1. Try NCBI-precomputed RNA-seq counts first
2. Fall back to supplementary count files
3. Fall back to the GEO expression matrix

If none exist (e.g., very old or non-RNA-seq series), the import will fail with a descriptive error message. In that case, download the raw data manually and upload as a count matrix.

### Does it handle single-cell RNA-seq?

No. TransXplorer is designed for bulk RNA-seq. Single-cell analysis is fundamentally different (zero-inflation, dropout, clustering at cell level) and is well-served by Seurat, scanpy, etc. We may add scRNA-seq deconvolution-style features in future versions but full single-cell pipelines are out of scope.

---

## Analytical modules

### How does the batch-effect detection differ from other tools?

Most tools either:
- Require you to manually identify the batch variable (assumes you already know what's confounding)
- Skip batch correction entirely
- Apply correction without flagging whether it's needed

TransXplorer instead computes a **quantitative composite score** combining PVCA, kBET, and Silhouette across every metadata column, and only applies correction when the composite exceeds 0.25. The threshold was empirically calibrated on benchmark datasets with known batch structure. This means non-experts get principled batch detection without needing to understand the underlying statistics.

See [`modules.md`](modules.md) and the manuscript for full methodology.

### Why does the GRN module support 11 organisms when other tools support only human and mouse?

The hybrid DoRothEA + TFLink approach. DoRothEA covers human and mouse with high-quality curation; TFLink extends coverage to rat, zebrafish, *Drosophila*, *C. elegans*, *S. cerevisiae*, *Arabidopsis*, chicken, pig, and bovine via predicted associations from literature mining and computational inference. Most other web platforms haven't bothered to integrate TFLink, so they default to human/mouse only.

### Are the DGIdb and OpenTargets queries real-time or pre-computed?

Real-time. Each drug-target query hits the live DGIdb and OpenTargets APIs (with optional local caching). This guarantees you see the most current clinical-trial and approval data. The latency cost is ~1-2 seconds per gene, but the freshness benefit is significant — drug-target landscapes move fast.

### Why does WGCNA pick a soft power lower than my dataset's R² > 0.8 cutoff suggests?

The auto-power algorithm follows the **Langfelder–Horvath sample-size table**: for n < 20 unsigned networks, default power 9; for 20 ≤ n < 30, power 8; etc. This is the canonical recommendation when scale-free fit alone doesn't yield a clear answer, particularly for smaller datasets. You can override the auto-pick in the Advanced Options panel.

---

## Performance and limits

### How many concurrent users can the hosted service handle?

The production server (32 threads, 125 GB RAM) handles ~20-30 concurrent active sessions comfortably. If you experience slowdowns at peak times, please consider running locally — Docker installation takes 30 minutes and gives you full performance for your workload.

### Why does my FASTQ analysis take so long?

FASTQ processing is the most resource-intensive operation. A 30M-read sample takes ~5-10 minutes to align with HISAT2 or ~1-2 minutes with Salmon. Multiple samples run in parallel up to the available CPU pool. For very large cohorts (>20 FASTQs), local Docker installation is strongly recommended.

### Can I get my analysis results offline?

Yes. Every module has a download button. The "Full Report (HTML)" download (in the GRN module's Summary & Export tab) gives a self-contained HTML document with all stats, plots, and tables — open in any browser, no server connection required.

---

## Source code, contributing, support

### Where is the source code?

This repository: [https://github.com/varinder-madhav/transxplorer](https://github.com/varinder-madhav/transxplorer). MIT license.

### Can I contribute?

Pull requests are welcome. For substantial features, please open an issue first to discuss scope. Bug reports and use-case suggestions are equally valuable.

### Where do I report bugs?

GitHub Issues: [https://github.com/varinder-madhav/transxplorer/issues](https://github.com/varinder-madhav/transxplorer/issues)

For confidential issues (e.g., security concerns), email [varinde2@ualberta.ca](mailto:varinde2@ualberta.ca).

### How do I cite TransXplorer?

A bioRxiv preprint is in preparation. Until then, please cite as:

> Verma VM, Mason AL, Wishart D, Wong GK. TransXplorer: an integrated RNA-seq analysis platform with translational drug-target mapping and multi-organism regulatory network inference. *Manuscript in preparation*. https://transxplorer.org

This README will be updated with the bioRxiv DOI when it's posted.

---

## Acknowledgements

TransXplorer integrates many open-source bioinformatics resources. Please also cite the underlying tools when relevant — see the `Reference databases and external resources` section in [`README.md`](../README.md).
