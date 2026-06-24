suppressMessages({library(AnnotationHub); library(dplyr)})
ah <- AnnotationHub()
orgs <- query(ah, "OrgDb")
md <- mcols(orgs)
idx <- data.frame(
  ah_accession    = names(orgs),
  scientific_name = as.character(md$species),
  taxid           = suppressWarnings(as.integer(md$taxonomyid)),
  title           = as.character(md$title),
  stringsAsFactors = FALSE
)
idx <- idx[!is.na(idx$scientific_name) & idx$scientific_name != "", ]
# keep the newest OrgDb per species (titles carry a version date -> last after sort)
idx <- idx[order(idx$scientific_name, idx$title), ]
idx <- idx[!duplicated(idx$scientific_name, fromLast = TRUE), ]
# KEGG organism list: scientific name -> 3-letter code
kg <- tryCatch(readLines("https://rest.kegg.jp/list/organism"), error = function(e) character(0))
if (length(kg)) {
  kg <- do.call(rbind, strsplit(kg, "\t"))            # Tnum, code, name, lineage
  kegg_df <- data.frame(kegg_code = kg[,2], kegg_name = kg[,3], stringsAsFactors = FALSE)
  idx$kegg_code <- vapply(idx$scientific_name, function(sn) {
    hit <- kegg_df$kegg_code[startsWith(kegg_df$kegg_name, sn)]
    if (length(hit)) hit[1] else NA_character_
  }, character(1))
} else {
  idx$kegg_code <- NA_character_
}
idx <- idx[, c("scientific_name","ah_accession","taxid","kegg_code")]
out <- "/srv/shiny-server/transxplorer/data/tx_species_index.rds"
saveRDS(idx, out)
cat("Built index:", nrow(idx), "species;",
    sum(!is.na(idx$kegg_code)), "with KEGG codes ->", out, "\n")
print(idx[grepl("Cicer arietinum", idx$scientific_name), ])
