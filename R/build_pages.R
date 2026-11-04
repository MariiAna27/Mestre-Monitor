args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]))
raiz <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/")
Sys.setenv(QUARTO_PROJECT_DIR = raiz)
source(file.path(raiz, "R", "00_utils.R"))
source(file.path(raiz, "R", "funcoes_site.R"))

programas <- ler_processado("programas")
pasta_paginas <- file.path(raiz, "programas")
dir.create(pasta_paginas, recursive = TRUE, showWarnings = FALSE)

for (i in seq_len(nrow(programas))) {
  programa <- programas[i, ]
  slug <- slug_programa(programa$id_capes)
  titulo <- jsonlite::toJSON(programa$nome, auto_unbox = TRUE, null = "null")
  subtitulo <- jsonlite::toJSON(
    paste(programa$ies_sigla, programa$municipio, programa$uf, sep = " · "),
    auto_unbox = TRUE, null = "null"
  )
  id <- jsonlite::toJSON(as.character(programa$id_capes), auto_unbox = TRUE)
  pagina <- c(
    "---",
    paste0("title: ", titulo),
    paste0("subtitle: ", subtitulo),
    "params:",
    paste0("  id_programa: ", id),
    "---",
    "",
    "```{r}",
    "id_programa <- params$id_programa",
    "```",
    "",
    "{{< include ../_programa_corpo.qmd >}}",
    ""
  )
  writeLines(pagina, file.path(pasta_paginas, paste0(slug, ".qmd")), useBytes = TRUE)
}

cat(nrow(programas), "páginas individuais geradas em programas/.\n")