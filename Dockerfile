# TransXplorer Shiny App Dockerfile
# Based on your exact R environment (R 4.4.1 with Bioconductor 3.20)

FROM rocker/shiny-verse:4.4.1

# Verify R version and set Bioconductor version
RUN R --version | grep "4.4.1"

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies (matching your local environment)
RUN apt-get update && apt-get install -y \
    # Health check requirement
    curl \
    # Core build tools
    build-essential \
    gfortran \
    # XML and SSL
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    # Image processing
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libcairo2-dev \
    # Genomics tools
    libbz2-dev \
    liblzma-dev \
    zlib1g-dev \
    libhdf5-dev \
    # Font rendering
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    # Additional dependencies
    libicu-dev \
    libgit2-dev \
    libssh2-1-dev \
    libgsl-dev \
    libgmp-dev \
    libglpk-dev \
    libmagick++-dev \
    cmake \
    # Networking
    libsodium-dev \
    # Java for rJava/xlsx
    default-jdk \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# INSTALL BIOINFORMATICS COMMAND-LINE TOOLS
# =============================================================================

# Add bioinformatics repositories
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install FastQC
RUN cd /tmp && \
    wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.12.1.zip && \
    unzip fastqc_v0.12.1.zip && \
    chmod +x FastQC/fastqc && \
    mv FastQC /opt/ && \
    ln -s /opt/FastQC/fastqc /usr/local/bin/fastqc && \
    rm fastqc_v0.12.1.zip

# Install Trimmomatic
RUN cd /opt && \
    wget http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/Trimmomatic-0.39.zip && \
    unzip Trimmomatic-0.39.zip && \
    rm Trimmomatic-0.39.zip && \
    echo '#!/bin/bash\njava -jar /opt/Trimmomatic-0.39/trimmomatic-0.39.jar "$@"' > /usr/local/bin/trimmomatic && \
    chmod +x /usr/local/bin/trimmomatic && \
    mkdir -p /usr/share/java && \
    ln -s /opt/Trimmomatic-0.39/trimmomatic-0.39.jar /usr/share/java/trimmomatic.jar

# Install SAMtools from source
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    libbz2-dev \
    liblzma-dev \
    libncurses5-dev \
    libncursesw5-dev \
    && cd /tmp && \
    wget https://github.com/samtools/samtools/releases/download/1.19/samtools-1.19.tar.bz2 && \
    tar -xjf samtools-1.19.tar.bz2 && \
    cd samtools-1.19 && \
    ./configure --prefix=/usr/local && \
    make && \
    make install && \
    cd / && rm -rf /tmp/samtools-1.19* && \
    rm -rf /var/lib/apt/lists/*

# Install HISAT2
RUN cd /opt && \
    wget https://cloud.biohpc.swmed.edu/index.php/s/oTtGWbWjaxsQ2Ho/download -O hisat2-2.2.1-Linux_x86_64.zip && \
    unzip hisat2-2.2.1-Linux_x86_64.zip && \
    rm hisat2-2.2.1-Linux_x86_64.zip && \
    ln -s /opt/hisat2-2.2.1/hisat2* /usr/local/bin/

# Install Subread (includes featureCounts)
RUN cd /tmp && \
    wget https://sourceforge.net/projects/subread/files/subread-2.0.6/subread-2.0.6-Linux-x86_64.tar.gz && \
    tar -xzf subread-2.0.6-Linux-x86_64.tar.gz && \
    mv subread-2.0.6-Linux-x86_64/bin/* /usr/local/bin/ && \
    rm -rf subread-2.0.6-Linux-x86_64*

# Install Salmon for pseudo-alignment quantification
RUN apt-get update && apt-get install -y --no-install-recommends \
    salmon libboost-iostreams-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python3 and pip, then MultiQC
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* && \
    pip3 install --no-cache-dir multiqc==1.21

RUN ln -s /usr/bin/python3 /usr/bin/python

# Verify all installations
RUN fastqc --version && \
    trimmomatic -version && \
    hisat2 --version && \
    samtools --version && \
    featureCounts -v && \
    multiqc --version

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure Java
RUN R CMD javareconf

# Install BiocManager with exact version
RUN R -e "install.packages('BiocManager', version='1.30.26')"

# Set Bioconductor version (3.20 for R 4.4.1)
RUN R -e "BiocManager::install(version='3.20', ask=FALSE, update=FALSE)"

# Install CRAN packages (matching your sessionInfo)
RUN R -e "install.packages(c( \
    'shiny', 'shinyjs', 'shinyWidgets', 'shinyBS', 'shinythemes', 'shinycssloaders', \
    'DT', 'plotly', 'ggplot2', 'ggrepel', 'ggfortify', 'ggpubr', 'gplots', 'pheatmap', \
    'dplyr', 'tidyr', 'purrr', 'tibble', 'tidyverse', 'readr', \
    'openxlsx', 'xlsx', 'readxl', \
    'survival', 'survminer', 'caret', 'glmnet', \
    'FactoMineR', 'factoextra', 'umap', \
    'jsonlite', 'httr', 'curl', 'rentrez', \
    'orca', 'visNetwork', 'RColorBrewer', 'Cairo', \
    'memoise', 'promises', 'future', 'future.apply', \
    'reticulate', 'processx', \
    'patchwork', 'gridExtra', 'ggdendro', 'gridGraphics', 'ggplotify', \
    'stringr', 'lubridate', 'forcats', \
    'igraph', 'viper', 'magick', 'svglite', 'webshot' , 'webshot2', \
    'chromote' \
), dependencies=TRUE)"

RUN R -e "install.packages('ggtangle', repos = c('https://guangchuangyu.r-universe.dev', 'https://cloud.r-project.org'))"

# Install system dependencies AND the browser itself in one step
RUN apt-get update && apt-get install -y \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libgdk-pixbuf2.0-0 \
    libgtk-3-0 \
    libgbm-dev \
    libasound2 \
    libxss1 \
    chromium-browser \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Set the environment variable for R to find the browser
# This uses a simple shell command 'which' to find the path, which is more reliable.
RUN echo "CHROMOTE_CHROME=$(which chromium-browser)" >> /usr/local/lib/R/etc/Renviron.site

# Install Bioconductor packages (core genomics)
RUN R -e "BiocManager::install(c( \
    'BiocGenerics', 'S4Vectors', 'IRanges', 'GenomeInfoDb', 'GenomicRanges', \
    'Biobase', 'SummarizedExperiment', 'MatrixGenerics', 'matrixStats', \
    'DESeq2', 'edgeR', 'limma', 'biomaRt', 'gProfileR', 'clusterProfiler', \
    'AnnotationDbi', 'org.Hs.eg.db', 'org.Mm.eg.db', 'org.Rn.eg.db', 'viper', \
    'org.Dr.eg.db', 'org.Dm.eg.db', 'org.Ce.eg.db', 'org.Sc.sgd.db', \
    'org.Ss.eg.db', 'org.Gg.eg.db', 'org.Bt.eg.db', 'org.At.tair.db', \
    'clusterProfiler', 'enrichplot', 'DOSE', 'ReactomePA', 'GOSemSim', \
    'TCGAbiolinks', 'GenomicFeatures', 'rtracklayer', \
    'Rsubread', 'Rsamtools', 'GenomicAlignments', 'ShortRead', 'Biostrings', 'XVector', \
    'BiocParallel', 'genefilter', 'sva', \
    'ComplexHeatmap', 'EnhancedVolcano' \
), ask=FALSE, update=FALSE)"

# Install additional Bioconductor packages
RUN R -e "BiocManager::install(c( \
    'dorothea', 'impute', 'preprocessCore', 'STRINGdb', 'rWikiPathways', 'GEOquery', 'tximport', \
    'GSEABase', 'GSVA', 'fgsea', 'qvalue' \
), ask=FALSE, update=FALSE)"

# Install specialized CRAN packages
RUN R -e "install.packages(c( \
    'enrichR', 'WGCNA', 'dynamicTreeCut', 'flashClust', \
    'circlize', 'reshape2', 'msigdbr', 'arrow', 'data.table', 'uwot' \
))"

# Install ggtangle from r-universe
RUN R -e "install.packages('ggtangle', repos = c('https://guangchuangyu.r-universe.dev', 'https://cloud.r-project.org'))"

# Install devtools for GitHub packages
RUN R -e "install.packages('devtools')"

# Install GitHub-only packages (EPIC, MCPcounter, xCell, immunedeconv)
RUN R -e "devtools::install_github('GfellerLab/EPIC', quiet=TRUE, upgrade='never')"
RUN R -e "devtools::install_github('ebecht/MCPcounter', ref='master', subdir='Source', quiet=TRUE, upgrade='never')"
RUN R -e "devtools::install_github('dviraran/xCell', quiet=TRUE, upgrade='never')"
RUN R -e "devtools::install_github('omnideconv/immunedeconv', quiet=TRUE, upgrade='never')"

# Install drugTargetInteractions and disgenet2r
RUN R -e "BiocManager::install('drugTargetInteractions', ask=FALSE, update=FALSE)"
RUN R -e "devtools::install_gitlab('medbio/disgenet2r', force=TRUE)"

# Copy custom Shiny Server configuration
COPY docker/shiny-server.conf /etc/shiny-server/shiny-server.conf

# Increase max upload size and timeout
RUN echo "options(shiny.maxRequestSize=10*1024^3)" >> /usr/local/lib/R/etc/Rprofile.site && \
    echo "options(shiny.usecairographics=TRUE)" >> /usr/local/lib/R/etc/Rprofile.site

# Create app directory structure
RUN mkdir -p /srv/shiny-server/transxplorer && \
    mkdir -p /srv/shiny-server/transxplorer/www && \
    mkdir -p /var/log/shiny-server && \
    mkdir -p /srv/shinydata && \
    mkdir -p /srv/transxplorer/uploads && \
    mkdir -p /srv/transxplorer/results

# Copy your application
COPY app/app.R /srv/shiny-server/transxplorer/app.R
COPY docker/queue_manager.R /srv/shiny-server/transxplorer/queue_manager.R
# Optional static assets — uncomment if you have a www/ folder for app static files:
# COPY www/ /srv/shiny-server/transxplorer/www/
# Optional bundled data — uncomment if you ship reference data inside the image:
# COPY data/ /srv/shiny-server/transxplorer/data/

# Set permissions
RUN chown -R shiny:shiny /srv/shiny-server && \
    chown -R shiny:shiny /var/log/shiny-server && \
    chown -R shiny:shiny /srv/transxplorer && \
    chmod -R 755 /srv/shiny-server && \
    chmod -R 755 /srv/transxplorer

# Expose Shiny port
EXPOSE 3838

# IMPORTANT: Remove Dockerfile healthcheck - let docker-compose handle it
# This prevents conflicts between the two healthcheck configurations

# Install tini - a tiny init system that properly reaps zombie processes
RUN apt-get update && apt-get install -y --no-install-recommends tini \
    && rm -rf /var/lib/apt/lists/*

# Use tini as the init process - this automatically cleans up zombies
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/usr/bin/shiny-server"]
