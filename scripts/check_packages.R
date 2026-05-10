#!/usr/bin/env Rscript
# Check which packages are missing from PBC_Seurat.R

cat("=================================================\n")
cat("Checking Required Packages\n")
cat("=================================================\n\n")

# Read your R script and extract library() calls
script_file <- "app.R"

if (!file.exists(script_file)) {
  stop("PBC_Seurat.R not found in current directory")
}

script_content <- readLines(script_file)

# Extract all library() and require() calls
library_lines <- grep("^\\s*library\\(|^\\s*require\\(", script_content, value = TRUE)

# Extract package names
extract_package <- function(line) {
  # Remove comments
  line <- sub("#.*$", "", line)
  # Extract package name
  if (grepl("library", line)) {
    pkg <- sub(".*library\\s*\\(\\s*['\"]?([^)'\"]+)['\"]?.*", "\\1", line)
  } else {
    pkg <- sub(".*require\\s*\\(\\s*['\"]?([^)'\"]+)['\"]?.*", "\\1", line)
  }
  return(trimws(pkg))
}

packages <- unique(sapply(library_lines, extract_package))
packages <- packages[packages != ""]

cat("Found", length(packages), "unique packages in script\n\n")

# Check each package
missing_packages <- c()
installed_packages <- c()

for (pkg in packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat("✓", pkg, "\n")
    installed_packages <- c(installed_packages, pkg)
  } else {
    cat("✗", pkg, "- MISSING\n")
    missing_packages <- c(missing_packages, pkg)
  }
}

cat("\n=================================================\n")
cat("Summary:\n")
cat("  Installed:", length(installed_packages), "/", length(packages), "\n")
cat("  Missing:", length(missing_packages), "\n")
cat("=================================================\n\n")

if (length(missing_packages) > 0) {
  cat("Missing packages:\n")
  cat(paste("  -", missing_packages), sep = "\n")
  cat("\n")
  
  # Try to determine source
  cat("\nInstallation commands:\n")
  cat("---------------------------------------------------\n")
  
  bioc_packages <- c()
  cran_packages <- c()
  
  for (pkg in missing_packages) {
    # Check if it's a Bioconductor package
    is_bioc <- tryCatch({
      BiocManager::available(pkg)
      TRUE
    }, error = function(e) FALSE)
    
    if (is_bioc) {
      bioc_packages <- c(bioc_packages, pkg)
    } else {
      cran_packages <- c(cran_packages, pkg)
    }
  }
  
  if (length(bioc_packages) > 0) {
    cat("\n# Bioconductor packages:\n")
    cat("BiocManager::install(c(\n")
    cat(paste0("  '", bioc_packages, "'", collapse = ",\n"))
    cat("\n))\n")
  }
  
  if (length(cran_packages) > 0) {
    cat("\n# CRAN packages:\n")
    cat("install.packages(c(\n")
    cat(paste0("  '", cran_packages, "'", collapse = ",\n"))
    cat("\n))\n")
  }
  
  cat("\n")
  quit(status = 1)
} else {
  cat("\n✓ All packages are installed!\n\n")
  quit(status = 0)
}
