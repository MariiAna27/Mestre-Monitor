pacotes <- c(
  "dplyr", "tidyr", "purrr", "stringr", "tibble", "readr",
  "jsonlite",
  "ggplot2",
  "leaflet", "crosstalk",
  "DT", "htmltools", "htmlwidgets",
  "png", "raster", "sf",
  "knitr", "rmarkdown"
)

faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]

if (length(faltantes)) {
  install.packages(faltantes, repos = "https://cloud.r-project.org")
} else {
  message("Todos os pacotes R necessários já estão instalados.")
}

nao_instalados <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(nao_instalados)) {
  stop("Não foi possível instalar os pacotes R necessários: ",
       paste(nao_instalados, collapse = ", "), call. = FALSE)
}