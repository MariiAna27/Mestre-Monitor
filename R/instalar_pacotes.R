pacotes <- c(
  "dplyr", "purrr", "stringr", "tibble", "readr",
  "jsonlite",
  "ggplot2",
  "leaflet", "crosstalk",
  "DT", "htmltools",
  "knitr", "rmarkdown"
)

faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]

if (length(faltantes)) {
  install.packages(faltantes, repos = "https://cloud.r-project.org")
} else {
  message("Todos os pacotes R necessários já estão instalados.")
}