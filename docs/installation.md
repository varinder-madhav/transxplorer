# Installation

> **The fastest path is to use the live service at [https://transxplorer.org](https://transxplorer.org).** No installation, no login, no usage cap.
> Local installation is only required if you need to run TransXplorer on private data behind a firewall, or if you want to develop / extend the platform.

## Local installation options

| Path | Best for | Time | Disk space |
|---|---|---|---|
| **Docker (recommended)** | Most users; reproducible deployment | 30 min build + reference data download | ~15 GB minimum, up to 200 GB if you mirror all reference indexes |
| **Native R Shiny** | Developers, contributors | 1-2 hours dependency install | depends on which reference data you fetch |
| **Web-only (transxplorer.org)** | Anyone who doesn't need local install | 0 min | 0 GB |

---

## Path 1: Docker (recommended)

### Prerequisites

- Linux server (tested on Ubuntu 22.04 / 24.04). macOS and Windows via Docker Desktop also work but are not the production target.
- **Docker** ≥ 24.0 and **Docker Compose** ≥ 2.20
- A user account with permission to run `docker` (member of the `docker` group)
- At least 16 GB RAM; **64 GB+ recommended** for production-scale analyses
- 8+ CPU cores recommended
- See [`docs/architecture.md`](architecture.md) for production hardware reference (32 threads, 125 GB RAM)

### Quick start

```bash
git clone https://github.com/varinder-madhav/transxplorer.git
cd transxplorer

# Optional: download reference data (~50-200 GB depending on selection).
# See "Reference data" section below for selective options.
bash scripts/02_download_references.sh

# Build and start
docker compose up -d --build
```

The app will be available at `http://localhost:3838`. First start takes 5-10 minutes for the R container to load all packages.

### Reverse proxy (production)

If you intend to expose this publicly, the included `docker/nginx.conf` configures an HTTPS reverse proxy in front of the Shiny container. SSL certificate setup via Let's Encrypt is described in [`scripts/06_setup_ssl.sh`](../scripts/06_setup_ssl.sh).

---

## Path 2: Native R Shiny

### Prerequisites

- **R ≥ 4.4** (R 4.5 also tested)
- BiocManager + ~60 R packages (Bioconductor + CRAN). The full list is checked by `scripts/check_packages.R`.
- For FASTQ processing: external tools `HISAT2`, `Salmon`, `featureCounts`, `FastQC`, `Trimmomatic` available in `$PATH`.
- For GRN inference: the `dorothea` R package and (for non-human/mouse) network connectivity to the TFLink download endpoints.
- For PPI: pre-downloaded STRING data or online API access.

### Install dependencies

```bash
# Verify and install all required R packages
Rscript scripts/check_packages.R

# Verify external tools (FASTQ pipeline only)
which hisat2 salmon featureCounts fastqc trimmomatic
```

### Run

```bash
Rscript -e 'options(shiny.maxRequestSize = 15000 * 1024^2); shiny::runApp("app/app.R", port = 3838, host = "0.0.0.0")'
```

The 15 GB upload limit allows large FASTQ files.

---

## Reference data

TransXplorer's analytical modules depend on several reference resources. Some are downloaded on demand by the app; others must be pre-staged.

| Resource | Modules | Size | Required? |
|---|---|---|---|
| **TCGA pre-computed expression** (33 cohorts) | TCGA boxplots, survival | ~30 GB | Required for TCGA module |
| **HISAT2 indexes** (hg38, mm10, rn6, etc.) | FASTQ alignment | 5-10 GB per genome | Required only for HISAT2 FASTQ path |
| **Salmon transcriptome indexes** | Salmon quantification | 1-3 GB per organism | Required only for Salmon FASTQ path |
| **GENCODE GTF annotations** | featureCounts, TPM | 1-2 GB | Required for FASTQ pipeline |
| **STRING-DB local mirrors** (human, mouse) | PPI without API limits | ~5 GB | Optional (API fallback works) |
| **OpenTargets local data** | Drug-target offline mode | ~10 GB | Optional (API fallback works) |
| **DoRothEA, dorothea_hs / dorothea_mm** | GRN | < 100 MB | Bundled with R package |
| **TFLink data** (rat, zebrafish, etc.) | Multi-organism GRN | ~500 MB per organism | Auto-downloaded on first use, cached |
| **AnnotationHub OrgDb** (~1,800 species) | Functional enrichment for non-standard organisms | varies | Auto-downloaded on demand |

### Selective download

Edit `scripts/02_download_references.sh` to comment-out resources you don't need (e.g., skip HISAT2 indexes if you'll only use Salmon, skip TCGA if you don't need clinical validation).

---

## Configuration

The main configuration knobs live in `docker-compose.yml` and the environment variables it sets. Key ones:

| Variable | Default | Purpose |
|---|---|---|
| `MAX_UPLOAD_SIZE` | `10737418240` (10 GB) | Maximum upload file size; raise for large FASTQ |
| `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS` | `4` | Per-process thread count for matrix ops |
| `R_MAX_NUM_DLLS` | `300` | Required because the app loads many packages |
| `HISAT2_*_INDEX`, `GENCODE_*_GTF` | (paths) | Reference-data mount points inside the container |
| `OPENTARGETS_DATA_PATH`, `STRING_DATA_PATH` | (paths) | Local-data paths, falls back to API if unset |

---

## Verifying installation

After `docker compose up -d`, check the health endpoint:

```bash
curl -fsS http://localhost:3838/ -o /dev/null && echo "OK"
```

For full verification, run the included example dataset:

1. Open the app in a browser
2. **Differential Expression** tab → upload `examples/cmec_pmec/example_counts.csv` (if included) or use **GEO Import** with accession `GSE151427`
3. The CMEC vs PMEC contrast should produce 212 DEGs at |log₂FC| > 2
4. Continue through the **Functional**, **Network**, and **Translational** tabs to verify each module

---

## Troubleshooting

### Build fails on `BiocManager::install()` for a specific package

The Bioconductor release cycle is twice yearly; some packages may not yet be available for very recent R versions. Pin to R 4.4.x for maximum compatibility, or use the Docker image which has a known-working R + Bioconductor combination baked in.

### Out of memory during WGCNA on large datasets

Increase the container's memory reservation in `docker-compose.yml` (`deploy.resources.limits.memory`). 64 GB minimum recommended for >10,000-gene WGCNA.

### TCGA boxplots are slow

If the `tcga_precomputed` mount is missing, the app falls back to live TCGAbiolinks queries which are slow. Pre-compute by running `scripts/04_download_tcga_data.R`.

### Trimmomatic-related errors during FASTQ processing

See `fix_if_trimmomatics_notwork.txt` in the deployment scripts for the specific JAR-path workaround.

---

## See also

- [`docs/quickstart.md`](quickstart.md) — 5-minute walkthrough with example data
- [`docs/architecture.md`](architecture.md) — production hardware and design choices
- [`docs/faq.md`](faq.md) — common questions
