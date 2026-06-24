suppressMessages(library(httr))
idxp <- "/srv/shiny-server/transxplorer/data/tx_species_index.rds"
idx <- readRDS(idxp)
r <- GET("https://rest.kegg.jp/list/genome", timeout(60), user_agent("Mozilla/5.0"))
stopifnot(status_code(r) == 200)
ln <- strsplit(content(r, "text", encoding = "UTF-8"), "\n")[[1]]
ln <- ln[nzchar(ln)]
# parse "T01001\thsa; Homo sapiens (human)"  -> code, scientific name
m <- regmatches(ln, regexec("^[^\t]+\t([A-Za-z0-9]+);\\s*(.+)$", ln))
code <- vapply(m, function(x) if (length(x) == 3) x[2] else NA_character_, character(1))
nm   <- vapply(m, function(x) if (length(x) == 3) x[3] else NA_character_, character(1))
sci  <- sub("\\s*\\(.*$", "", nm)                       # drop " (common name)"
sci  <- trimws(sci)
kegg_df <- data.frame(kegg_code = code, sci = sci, stringsAsFactors = FALSE)
kegg_df <- kegg_df[!is.na(kegg_df$kegg_code) & nzchar(kegg_df$sci), ]
kegg_df <- kegg_df[!duplicated(kegg_df$sci), ]
# exact match by scientific name
idx$kegg_code <- kegg_df$kegg_code[match(idx$scientific_name, kegg_df$sci)]
# prefix fallback (KEGG name may carry strain/subspecies)
na_i <- which(is.na(idx$kegg_code))
for (i in na_i) {
  hit <- kegg_df$kegg_code[startsWith(kegg_df$sci, idx$scientific_name[i])]
  if (length(hit)) idx$kegg_code[i] <- hit[1]
}
saveRDS(idx, idxp)
# also save the raw KEGG genome table as a shipped static asset (offline source of truth)
saveRDS(kegg_df, "/srv/shiny-server/transxplorer/data/tx_kegg_genomes.rds")
cat("KEGG codes populated:", sum(!is.na(idx$kegg_code)), "of", nrow(idx), "species\n")
print(idx[grepl("Cicer arietinum", idx$scientific_name), ])
