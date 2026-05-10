#!/usr/bin/env Rscript
# Download and prepare TCGA data for all cancer types
# Run this on the server: Rscript 04_download_tcga_data.R

library(TCGAbiolinks)
library(SummarizedExperiment)

# Set output directory
data_dir <- "/srv/transxplorer/data/tcga"
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

# All TCGA cancer types from your app
cancer_types <- c(
  "TCGA-ACC", "TCGA-BLCA", "TCGA-BRCA", "TCGA-CESC", "TCGA-CHOL",
  "TCGA-COAD", "TCGA-DLBC", "TCGA-ESCA", "TCGA-GBM", "TCGA-HNSC",
  "TCGA-KICH", "TCGA-KIRC", "TCGA-KIRP", "TCGA-LAML", "TCGA-LGG",
  "TCGA-LIHC", "TCGA-LUAD", "TCGA-LUSC", "TCGA-MESO", "TCGA-OV",
  "TCGA-PAAD", "TCGA-PCPG", "TCGA-PRAD", "TCGA-READ", "TCGA-SARC",
  "TCGA-SKCM", "TCGA-STAD", "TCGA-TGCT", "TCGA-THCA", "TCGA-THYM",
  "TCGA-UCEC", "TCGA-UCS", "TCGA-UVM"
)

cat("=================================================\n")
cat("Downloading TCGA Data for", length(cancer_types), "cancer types\n")
cat("This will take several hours and ~50-80GB of space\n")
cat("=================================================\n\n")

# Function to download and save TCGA data
download_tcga <- function(project) {
  cat("\n[", which(cancer_types == project), "/", length(cancer_types), "] Processing:", project, "\n")
  
  output_file <- file.path(data_dir, paste0(project, ".RDS"))
  
  # Skip if already exists
  if (file.exists(output_file)) {
    cat("  -> Already exists, skipping\n")
    return(TRUE)
  }
  
  tryCatch({
    # Query TCGA data
    cat("  -> Querying data...\n")
    query <- GDCquery(
      project = project,
      data.category = "Transcriptome Profiling",
      data.type = "Gene Expression Quantification",
      workflow.type = "STAR - Counts"
    )
    
    # Download data
    cat("  -> Downloading (this may take a while)...\n")
    GDCdownload(query, method = "api", files.per.chunk = 10)
    
    # Prepare data
    cat("  -> Preparing SummarizedExperiment...\n")
    data <- GDCprepare(query)
    
    # Save as RDS
    cat("  -> Saving to", output_file, "\n")
    saveRDS(data, file = output_file, compress = "xz")
    
    cat("  -> ✓ Success!\n")
    cat("  -> Size:", round(file.size(output_file) / 1e9, 2), "GB\n")
    
    return(TRUE)
    
  }, error = function(e) {
    cat("  -> ✗ ERROR:", e$message, "\n")
    return(FALSE)
  })
}

# Download all cancer types
successful <- 0
failed <- 0

for (project in cancer_types) {
  if (download_tcga(project)) {
    successful <- successful + 1
  } else {
    failed <- failed + 1
  }
}

# Summary
cat("\n=================================================\n")
cat("Download Complete!\n")
cat("=================================================\n")
cat("Successful:", successful, "/", length(cancer_types), "\n")
cat("Failed:", failed, "\n")
cat("\nTotal disk usage:\n")
system(paste("du -sh", data_dir))
cat("=================================================\n")
