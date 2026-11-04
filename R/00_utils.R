pacotes_base <- c("dplyr", "tidyr", "purrr", "stringr", "tibble", "readr", "jsonlite")
faltantes <- pacotes_base[!vapply(pacotes_base, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes)) {
  stop("Instale os pacotes R necessários: ", paste(faltantes, collapse = ", "), call. = FALSE)
}

invisible(lapply(pacotes_base, library, character.only = TRUE))

cfg <- list(ciclos = list(atual = 2021, anterior = 2017))
COR_CP <- "#1677C8"
COR_RI <- "#7A42A6"
COR_AMBAS <- "#7A42A6"
NOMES_NIVEL <- c(M = "Mestrado acadêmico", MP = "Mestrado profissional", D = "Doutorado")
TEMAS_AFINIDADE <- c(
  "instituicoes-politicas", "comportamento-eleitoral", "politicas-publicas",
  "teoria-politica", "politica-comparada", "politica-externa", "seguranca-defesa",
  "economia-politica-internacional", "organizacoes-internacionais", "integracao-regional"
)
METODOS_AFINIDADE <- c("quantitativo", "qualitativo", "misto", "teoria-normativa")

esquemas_processados <- list(
  programas = list(
    id_capes = character(), nome = character(), ies_sigla = character(),
    municipio = character(), uf = character(), subarea = character(),
    tem_mestrado = logical(), tem_mestrado_prof = logical(), tem_doutorado = logical(),
    natureza = character(), url_programa = character()
  ),
  avaliacoes = list(id_capes = character(), ciclo = integer(), conceito = integer()),
  editais = list(
    id_edital = character(), id_capes = character(), ano = integer(), nivel = character(),
    inscricao_inicio = as.Date(character()), inscricao_fim = as.Date(character()),
    vagas = integer(), url_edital = character(), verificado_em = as.Date(character()),
    previsao_texto = character()
  ),
  linhas_pesquisa = list(
    id_capes = character(), linha = character(), descricao = character(),
    url_fonte = character(), verificado_em = as.Date(character()),
    temas = character(), metodos = character()
  ),
  producao = list(
    id_capes = character(), ano = integer(), docentes_permanentes = numeric(),
    publicacoes = numeric(), titulados = numeric()
  ),
  coordenadas = list(
    id_capes = character(), latitude = numeric(), longitude = numeric(),
    fonte_url = character(), verificado_em = as.Date(character())
  ),
  metadados = list(fonte = character(), atualizado_em = as.Date(character()), arquivo = character()),
  ranking_conceito = list(
    id_capes = character(), nome = character(), ies_sigla = character(), uf = character(),
    subarea_rotulo = character(), niveis = character(), conceito_atual = integer(),
    conceito_anterior = integer(), variacao = integer()
  ),
  ranking_produtividade = list(
    id_capes = character(), nome = character(), ies_sigla = character(), uf = character(),
    subarea_rotulo = character(), pub_por_docente_ano = numeric(),
    titulados_por_docente_ano = numeric(), docentes_medio = numeric(), posicao = integer(),
    elegivel = logical(), motivo_exclusao = character(), n_anos = integer()
  ),
  ranking_produtividade_params = list(
    janela_inicio = integer(), janela_fim = integer(), min_anos_com_dados = integer(),
    min_docentes_medio = numeric()
  )
)

ler_tabela <- function(pasta, nome) {
  caminho <- file.path(raiz, "data", pasta, paste0(nome, ".csv"))
  esquema <- esquemas_processados[[nome]]
  if (!file.exists(caminho)) {
    if (!is.null(esquema)) {
      return(tibble::as_tibble(esquema))
    }
    stop("Tabela não encontrada: ", caminho, call. = FALSE)
  }

  tabela <- readr::read_csv(
    caminho, col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE, na = c("", "NA"), progress = FALSE
  )
  if (is.null(esquema)) return(tabela)

  faltantes <- setdiff(names(esquema), names(tabela))
  if (length(faltantes)) {
    stop("Tabela ", nome, " sem colunas obrigatórias: ", paste(faltantes, collapse = ", "), call. = FALSE)
  }
  for (campo in names(esquema)) {
    modelo <- esquema[[campo]]
    valores <- tabela[[campo]]
    if (inherits(modelo, "Date")) {
      tabela[[campo]] <- as.Date(valores)
    } else if (is.logical(modelo)) {
      tabela[[campo]] <- readr::parse_logical(valores, na = c("", "NA"))
    } else if (is.integer(modelo)) {
      tabela[[campo]] <- readr::parse_integer(valores, na = c("", "NA"))
    } else if (is.numeric(modelo)) {
      tabela[[campo]] <- readr::parse_double(valores, na = c("", "NA"))
    }
  }
  tabela
}

ler_processado <- function(nome) ler_tabela("processed", nome)

fmt_data <- function(x) {
  data <- suppressWarnings(as.Date(x))
  ifelse(is.na(data), "—", format(data, "%d/%m/%Y"))
}

fmt_num <- function(x, casas = 2) {
  ifelse(is.na(x), "—", formatC(x, format = "f", digits = casas, decimal.mark = ",", big.mark = "."))
}

md_escape <- function(x) {
  stringr::str_replace_all(as.character(x), "([\\\\`*_{}\\[\\]()#+.!|>])", "\\\\\\1")
}

html_escape <- function(x) htmltools::htmlEscape(as.character(x))

raiz <- Sys.getenv("QUARTO_PROJECT_DIR", unset = ".")
raiz <- normalizePath(raiz, winslash = "/", mustWork = FALSE)