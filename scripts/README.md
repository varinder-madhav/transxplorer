# Scripts

Shell and R helper scripts for server provisioning, reference-data acquisition, and operational maintenance. Most users running TransXplorer via Docker won't need these — the Docker container handles its own setup.

## Server provisioning

| Script | Purpose |
|---|---|
| `01_server_initial_setup.sh` | Base Ubuntu setup (Docker install, user setup, firewall) |
| `05_deploy_app.sh` | One-shot reference deploy — clone, build, start |
| `06_setup_ssl.sh` | Let's Encrypt certificate acquisition + nginx wiring |

## Reference data

| Script | Purpose | Approx. download size |
|---|---|---|
| `02_download_references.sh` | HISAT2 indexes, GENCODE GTFs, Salmon indexes for all 7 reference genomes | 100–200 GB (selective comments allow you to skip individual genomes) |
| `04_download_tcga_data.R` | Pre-compute TCGA expression matrices across 33 cohorts using TCGAbiolinks | ~30 GB |

Comment out blocks in `02_download_references.sh` if you only need a subset of genomes (e.g., you only need human → keep hg38 block, comment the rest).

## Maintenance

| Script | Purpose |
|---|---|
| `monitor_transxplorer.sh` | Service / container / disk / memory health snapshot |
| `check_packages.R` | Verify all required R packages are installed; install missing ones |

## Notes

- All shell scripts assume Ubuntu 22.04+ and `bash`.
- Reference-data scripts require network connectivity to NCBI, Ensembl, and the relevant database mirrors.
- `04_download_tcga_data.R` requires R ≥ 4.4 and the `TCGAbiolinks` Bioconductor package.
