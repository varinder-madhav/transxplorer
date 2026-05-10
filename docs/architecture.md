# Architecture

## Production deployment

The reference deployment at [https://transxplorer.org](https://transxplorer.org) runs on:

| Component | Spec |
|---|---|
| Server | AMD EPYC 7351P, 32 threads, 125 GB RAM |
| OS | Ubuntu 22.04 LTS |
| Container runtime | Docker + Docker Compose |
| Reverse proxy | Nginx with Let's Encrypt SSL (auto-renewal via certbot deploy hook) |
| Application | R Shiny single-page app, 3 GB working memory per session, lazy-loaded modules |
| Job queue | Redis-backed worker pool for FASTQ processing |
| Storage | Bind-mounted host volumes for reference data (read-only) and user uploads/results (read-write) |

## Service topology

```
Internet  ──HTTPS──▶  nginx (reverse proxy, SSL termination)
                          │
                          ├──▶  shiny-server (TransXplorer)
                          │       ├── R Shiny app.R (UI + server)
                          │       ├── Lazy-loaded module dlls (300 max)
                          │       ├── Bind mounts: reference data (ro), uploads (rw)
                          │       └── Spawns Docker workers for FASTQ jobs
                          │
                          └──▶  Redis (session/job state)
```

User uploads, analysis results, and session data live in three host volumes (`uploads/`, `results/`, `sessions/`). Reference data — TCGA pre-computed matrices, HISAT2 indexes, GENCODE annotations, OpenTargets / STRING local mirrors — is mounted read-only.

## Application architecture

The app is a single `app.R` (a deliberate choice for atomic deployment) organized internally into:

- **UI scaffold** — `bslib`-based navbarPage with tabs for each analytical branch
- **Module servers** — each analytical capability has its own observer/render block, lazy-loaded on tab activation to keep idle memory low
- **Pipeline functions** — DEG, enrichment, PPI, WGCNA, GRN, drug-target, TCGA, FASTQ — implemented as standalone R functions that take in/out data frames so they're individually testable
- **Reactive value stores** — per-tab `reactiveValues` namespaces (e.g., `grn_standalone_rv`, `wgcna_rv`) keep state isolated between modules
- **Async background workers** — long-running FASTQ jobs spawn Docker worker containers via the host Docker socket (mounted into the app container at `/var/run/docker.sock`)
- **Session save/restore** — every module's `reactiveValues` are serialized to disk under a per-run ID; resumable for 7 days

## Performance benchmarks

Benchmarks on the production server, GSE151427 (22 samples, ~25,000 genes after filtering):

| Operation | Time |
|---|---|
| GEO import + metadata parse | ~30 s |
| Differential expression (edgeR, 22 samples × 25k genes) | ~15 s |
| Pathway enrichment (clusterProfiler ORA, GO+KEGG+Reactome) | ~45 s |
| PPI network construction + 11-algorithm CytoHubba | ~90 s |
| WGCNA (auto-power, 7 modules from 5,000 genes) | < 8 min |
| GRN inference (DoRothEA, 778 DEGs, 27 input TFs, 2,758 edges) | ~2 min |
| Drug-target query (DGIdb + OpenTargets, 500 DEGs) | < 90 s |

For larger datasets:

| Operation | Time |
|---|---|
| TCGA-KIRP differential expression (584 samples × 41,553 genes, edgeR) | < 3 min |
| TCGA boxplot / survival per gene (pre-computed) | < 1 s |

## Design choices

### Why single `app.R` instead of modularized Shiny modules?

For a research tool with frequent iteration, atomic deployment beats architectural purity. A single file means: one place to grep for any logic, no cross-file `source()` ordering issues, simple Docker COPY, simple version-pinning. The cost is editor performance on a 100k+-line file, accepted as a known tradeoff.

### Why both Salmon and HISAT2?

Salmon is faster and sufficient for most differential-expression use cases. HISAT2 is required when downstream analyses depend on splice-aware alignment — variant calling, fusion detection, novel transcript assembly. Offering both lets users pick based on their downstream needs.

### Why Docker socket mount for FASTQ workers?

FASTQ pipelines need substantial isolated resources (CPU, RAM, scratch disk) and are I/O-bound. Spawning a separate worker container per job lets each FASTQ run claim full resources without competing with the live Shiny session. Risk: the Docker socket grants effective root on the host, mitigated by the worker-spawn code path being the only socket consumer (no user-driven container creation).

### Why three batch-detection metrics combined, not just one?

PVCA captures global variance attribution but misses local mixing failures. kBET captures local mixing but is sensitive to k. Silhouette is geometric and over-flags imbalanced groups. Each individually misses confounding the others detect; the weighted composite (0.4/0.4/0.2) and threshold (0.25) were calibrated on benchmark datasets with known batch structure (GSE49712, GSE115736) to maximize sensitivity while controlling false positives from biological covariates.

### Why hybrid DoRothEA + TFLink for GRN, not just one?

DoRothEA has the highest-quality curation but only covers human and mouse. TFLink extends to 9 additional model organisms via predicted associations. Hybrid prioritizes DoRothEA when both are available (human, mouse) and falls back to TFLink for non-traditional model organisms. This is the only published web platform that infers regulatory networks across all 11 of our supported model organisms.

### Why CytoHubba consensus (11 algorithms) instead of degree alone?

Single-metric hub ranking is sensitive to network topology artefacts. Eleven complementary metrics (MCC, MNC, DMNC, EPC, BottleNeck, EcCentricity, Closeness, Radiality, Betweenness, Stress, Degree) give consensus ranking that's robust to topology biases. A node ranking high across 9+ algorithms is a true hub; a node ranking high in only one is suspicious.

## Hardware recommendations for self-hosted

| Use case | CPU | RAM | Disk |
|---|---|---|---|
| **Solo researcher, count-matrix only** | 4 cores | 16 GB | 50 GB |
| **Small lab, multi-user, no FASTQ** | 8 cores | 32 GB | 200 GB |
| **Multi-user with FASTQ pipeline** | 16+ cores | 64 GB | 500 GB + reference data |
| **Production scale (transxplorer.org-equivalent)** | 32 threads | 128 GB | 2 TB SSD + reference data |

FASTQ processing is by far the most resource-intensive module. If you only need analytical modules (DEG, pathway, GRN, drug-target), you can run TransXplorer comfortably on a 16 GB workstation.
