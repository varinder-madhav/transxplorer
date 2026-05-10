#!/bin/bash
# Download Reference Genomes and Build HISAT2 Indexes
# Run this AFTER Phase 1 setup

set -e

BASE_DIR="/srv/transxplorer/data"
cd $BASE_DIR

echo "==================================================="
echo "Downloading Reference Data - This will take time!"
echo "==================================================="

# Ensure directories exist
mkdir -p ${BASE_DIR}/genomes
mkdir -p ${BASE_DIR}/annotations

# ==========================================
# HUMAN (hg38) REFERENCES
# ==========================================
echo "[1/13] Downloading Human hg38 genome..."
cd ${BASE_DIR}/genomes
if [ ! -f "GRCh38.primary_assembly.genome.fa" ]; then
    wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_47/GRCh38.primary_assembly.genome.fa.gz
    gunzip GRCh38.primary_assembly.genome.fa.gz
fi

echo "[2/13] Downloading Human hg38 GTF..."
cd ${BASE_DIR}/annotations
if [ ! -f "gencode.v47.annotation.gtf" ]; then
    wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_47/gencode.v47.annotation.gtf.gz
    gunzip gencode.v47.annotation.gtf.gz
fi

# ==========================================
# MOUSE (mm10) REFERENCES
# ==========================================
echo "[3/13] Downloading Mouse mm10 genome..."
cd ${BASE_DIR}/genomes
if [ ! -f "GRCm39.primary_assembly.genome.fa" ]; then
    wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M36/GRCm39.primary_assembly.genome.fa.gz
    gunzip GRCm39.primary_assembly.genome.fa.gz
fi

echo "[4/13] Downloading Mouse mm10 GTF..."
cd ${BASE_DIR}/annotations
if [ ! -f "gencode.vM36.annotation.gtf" ]; then
    wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M36/gencode.vM36.annotation.gtf.gz
    gunzip gencode.vM36.annotation.gtf.gz
fi

# ==========================================
# RAT (rn6) REFERENCES
# ==========================================
echo "[5/13] Downloading Rat rn6 genome..."
cd ${BASE_DIR}/genomes
if [ ! -f "Rattus_norvegicus.mRatBN7.2.dna.toplevel.fa" ]; then
    wget http://ftp.ensembl.org/pub/release-111/fasta/rattus_norvegicus/dna/Rattus_norvegicus.mRatBN7.2.dna.toplevel.fa.gz
    gunzip Rattus_norvegicus.mRatBN7.2.dna.toplevel.fa.gz
fi

echo "[6/13] Downloading Rat rn6 GTF..."
cd ${BASE_DIR}/annotations
if [ ! -f "Rattus_norvegicus.mRatBN7.2.111.gtf" ]; then
    wget http://ftp.ensembl.org/pub/release-111/gtf/rattus_norvegicus/Rattus_norvegicus.mRatBN7.2.111.gtf.gz
    gunzip Rattus_norvegicus.mRatBN7.2.111.gtf.gz
fi

# ==========================================
# DROSOPHILA (fly)
# ==========================================
echo "[7/13] Downloading Drosophila (fly) genome..."
cd ${BASE_DIR}/genomes
if [ ! -f "Drosophila_melanogaster.BDGP6.32.dna.toplevel.fa" ]; then
    wget http://ftp.ensembl.org/pub/release-111/fasta/drosophila_melanogaster/dna/Drosophila_melanogaster.BDGP6.32.dna.toplevel.fa.gz
    gunzip Drosophila_melanogaster.BDGP6.32.dna.toplevel.fa.gz
fi

echo "[8/13] Downloading Drosophila (fly) GTF..."
cd ${BASE_DIR}/annotations
if [ ! -f "Drosophila_melanogaster.BDGP6.32.111.gtf" ]; then
    wget http://ftp.ensembl.org/pub/release-111/gtf/drosophila_melanogaster/Drosophila_melanogaster.BDGP6.32.111.gtf.gz
    gunzip Drosophila_melanogaster.BDGP6.32.111.gtf.gz
fi

# ==========================================
# ZEBRAFISH
# ==========================================
echo "[9/13] Downloading Zebrafish genome..."
cd ${BASE_DIR}/genomes
if [ ! -f "Danio_rerio.GRCz11.dna.toplevel.fa" ]; then
    wget http://ftp.ensembl.org/pub/release-111/fasta/danio_rerio/dna/Danio_rerio.GRCz11.dna.toplevel.fa.gz
    gunzip Danio_rerio.GRCz11.dna.toplevel.fa.gz
fi

echo "[10/13] Downloading Zebrafish GTF..."
cd ${BASE_DIR}/annotations
if [ ! -f "Danio_rerio.GRCz11.111.gtf" ]; then
    wget http://ftp.ensembl.org/pub/release-111/gtf/danio_rerio/Danio_rerio.GRCz11.111.gtf.gz
    gunzip Danio_rerio.GRCz11.111.gtf.gz
fi

# ==========================================
# C. ELEGANS
# ==========================================
echo "[11/13] Downloading C. elegans genome..."
cd ${BASE_DIR}/genomes
if [ ! -f "Caenorhabditis_elegans.WBcel235.dna.toplevel.fa" ]; then
    wget http://ftp.ensembl.org/pub/release-111/fasta/caenorhabditis_elegans/dna/Caenorhabditis_elegans.WBcel235.dna.toplevel.fa.gz
    gunzip Caenorhabditis_elegans.WBcel235.dna.toplevel.fa.gz
fi

echo "[12/13] Downloading C. elegans GTF..."
cd ${BASE_DIR}/annotations
if [ ! -f "Caenorhabditis_elegans.WBcel235.111.gtf" ]; then
    wget http://ftp.ensembl.org/pub/release-111/gtf/caenorhabditis_elegans/Caenorhabditis_elegans.WBcel235.111.gtf.gz
    gunzip Caenorhabditis_elegans.WBcel235.111.gtf.gz
fi

# ==========================================
# YEAST
# ==========================================
echo "[13/13] Downloading Yeast genome and annotation..."
cd ${BASE_DIR}/genomes
if [ ! -f "Saccharomyces_cerevisiae.R64-1-1.dna.toplevel.fa" ]; then
    wget http://ftp.ensembl.org/pub/release-111/fasta/saccharomyces_cerevisiae/dna/Saccharomyces_cerevisiae.R64-1-1.dna.toplevel.fa.gz
    gunzip Saccharomyces_cerevisiae.R64-1-1.dna.toplevel.fa.gz
fi

cd ${BASE_DIR}/annotations
if [ ! -f "Saccharomyces_cerevisiae.R64-1-1.111.gtf" ]; then
    wget http://ftp.ensembl.org/pub/release-111/gtf/saccharomyces_cerevisiae/Saccharomyces_cerevisiae.R64-1-1.111.gtf.gz
    gunzip Saccharomyces_cerevisiae.R64-1-1.111.gtf.gz
fi

# ==========================================
# ARABIDOPSIS
# ==========================================
echo "[14/13] Downloading Arabidopsis genome and annotation..."
cd ${BASE_DIR}/genomes
if [ ! -f "Arabidopsis_thaliana.TAIR10.dna.toplevel.fa" ]; then
    wget http://ftp.ensemblgenomes.org/pub/plants/release-58/fasta/arabidopsis_thaliana/dna/Arabidopsis_thaliana.TAIR10.dna.toplevel.fa.gz
    gunzip Arabidopsis_thaliana.TAIR10.dna.toplevel.fa.gz
fi

cd ${BASE_DIR}/annotations
if [ ! -f "Arabidopsis_thaliana.TAIR10.58.gtf" ]; then
    wget http://ftp.ensemblgenomes.org/pub/plants/release-58/gtf/arabidopsis_thaliana/Arabidopsis_thaliana.TAIR10.58.gtf.gz
    gunzip Arabidopsis_thaliana.TAIR10.58.gtf.gz
fi

# ==========================================
# CHICKEN
# ==========================================
echo "[15/13] Downloading Chicken genome and annotation..."
cd ${BASE_DIR}/genomes
if [ ! -f "Gallus_gallus.bGalGal1.mat.broiler.GRCg7b.dna.toplevel.fa" ]; then
    wget http://ftp.ensembl.org/pub/release-111/fasta/gallus_gallus/dna/Gallus_gallus.bGalGal1.mat.broiler.GRCg7b.dna.toplevel.fa.gz
    gunzip Gallus_gallus.bGalGal1.mat.broiler.GRCg7b.dna.toplevel.fa.gz
fi

cd ${BASE_DIR}/annotations
if [ ! -f "Gallus_gallus.bGalGal1.mat.broiler.GRCg7b.111.gtf" ]; then
    wget http://ftp.ensembl.org/pub/release-111/gtf/gallus_gallus/Gallus_gallus.bGalGal1.mat.broiler.GRCg7b.111.gtf.gz
    gunzip Gallus_gallus.bGalGal1.mat.broiler.GRCg7b.111.gtf.gz
fi

# ==========================================
# PIG
# ==========================================
echo "[16/13] Downloading Pig genome and annotation..."
cd ${BASE_DIR}/genomes
if [ ! -f "Sus_scrofa.Sscrofa11.1.dna.toplevel.fa" ]; then
    wget http://ftp.ensembl.org/pub/release-111/fasta/sus_scrofa/dna/Sus_scrofa.Sscrofa11.1.dna.toplevel.fa.gz
    gunzip Sus_scrofa.Sscrofa11.1.dna.toplevel.fa.gz
fi

cd ${BASE_DIR}/annotations
if [ ! -f "Sus_scrofa.Sscrofa11.1.111.gtf" ]; then
    wget http://ftp.ensembl.org/pub/release-111/gtf/sus_scrofa/Sus_scrofa.Sscrofa11.1.111.gtf.gz
    gunzip Sus_scrofa.Sscrofa11.1.111.gtf.gz
fi

# ==========================================
# DONE
# ==========================================
echo ""
echo "==================================================="
echo "✓ Reference downloads complete!"
echo "==================================================="
echo "Next: Build HISAT2 indexes using Docker"
echo "Run: ./03_build_hisat2_indexes.sh"
echo "==================================================="
