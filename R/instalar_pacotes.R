pacotes <- c(
  "dplyr", "tidyr", "purrr", "stringr", "tibble", "readr",
  "jsonlite", "ggplot2", "leaflet", "crosstalk", "DT",
  "htmltools", "knitr"
)

faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]

if (length(faltantes)) {
  repos <- getOption("repos")
  if (is.null(repos) || !length(repos)) repos <- character()
  if (is.null(repos[["CRAN"]]) || is.na(repos[["CRAN"]]) || repos[["CRAN"]] == "@CRAN@") {
    repos["CRAN"] <- "https://cloud.r-project.org"
  }
  install.packages(faltantes, repos = repos)
} else {
  message("Todos os pacotes R necessários já estão instalados.")
}

nao_instalados <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(nao_instalados)) {
  stop("Não foi possível instalar os pacotes R necessários: ",
       paste(nao_instalados, collapse = ", "), call. = FALSE)
}