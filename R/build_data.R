args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]))
raiz <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/")
Sys.setenv(QUARTO_PROJECT_DIR = raiz)
source(file.path(raiz, "R", "00_utils.R"))

ano_base <- 2024L
ciclo_atual <- 2021L
janela_inicio <- 2021L
janela_fim <- 2024L
url_capes <- paste0(
  "https://dadosabertos.capes.gov.br/dataset/414275c0-2056-4a12-b1a6-b525b74850d5/",
  "resource/76ccbd76-7f3a-40c3-a4dc-7d6f65858db8/download/",
  "br-capes-colsucup-prog-2024-2025-12-01.csv"
)

dir.create(file.path(raiz, "data", "raw"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(raiz, "data", "processed"), recursive = TRUE, showWarnings = FALSE)
raw_path <- file.path(raiz, "data", "raw", "capes_programas_2024.csv")
csv_configurado <- Sys.getenv("CAPES_PROGRAMAS_CSV", unset = "")
forcar <- "--force" %in% args

if (nzchar(csv_configurado)) {
  if (!file.exists(csv_configurado)) {
    stop("CAPES_PROGRAMAS_CSV não existe: ", csv_configurado, call. = FALSE)
  }
  caminho_configurado <- normalizePath(csv_configurado, winslash = "/")
  if (!identical(caminho_configurado, normalizePath(raw_path, winslash = "/", mustWork = FALSE))) {
    if (!file.copy(caminho_configurado, raw_path, overwrite = TRUE)) {
      stop("Não foi possível copiar o CSV para data/raw/.", call. = FALSE)
    }
  }
} else if (!file.exists(raw_path) || forcar) {
  options(timeout = max(600, getOption("timeout")))
  ultimo_erro <- NULL
  for (tentativa in seq_len(3L)) {
    status <- tryCatch(
      utils::download.file(url_capes, raw_path, mode = "wb", quiet = FALSE, method = "libcurl"),
      error = function(e) {
        ultimo_erro <<- conditionMessage(e)
        -1L
      }
    )
    if (identical(status, 0L) && file.exists(raw_path)) break
    ultimo_erro <- if (is.null(ultimo_erro)) paste("Download CAPES terminou com código", status) else ultimo_erro
    if (tentativa < 3L) {
      message(sprintf("Tentativa %s/%s falhou ao baixar o CSV CAPES: %s", tentativa, 3L, ultimo_erro))
      Sys.sleep(5)
    }
  }
  if (!file.exists(raw_path) || !identical(status, 0L)) {
    stop(
      "Não foi possível baixar o CSV CAPES após 3 tentativas. ",
      "Use um CSV local e configure CAPES_PROGRAMAS_CSV=/caminho/arquivo.csv ou baixe a base manualmente.",
      call. = FALSE
    )
  }
}

programas_raw <- readr::read_delim(
  raw_path, delim = ";", quote = "\"", trim_ws = TRUE,
  locale = readr::locale(encoding = "ISO-8859-1"),
  col_types = readr::cols(.default = readr::col_character()),
  name_repair = "minimal", show_col_types = FALSE, progress = FALSE
)

campos_obrigatorios <- c(
  "AN_BASE", "NM_AREA_AVALIACAO", "CD_PROGRAMA_IES", "NM_PROGRAMA_IES",
  "SG_ENTIDADE_ENSINO", "NM_MUNICIPIO_PROGRAMA_IES", "SG_UF_PROGRAMA",
  "NM_GRAU_PROGRAMA", "NM_MODALIDADE_PROGRAMA", "CD_CONCEITO_PROGRAMA",
  "DS_SITUACAO_PROGRAMA"
)
ausentes <- setdiff(campos_obrigatorios, names(programas_raw))
if (length(ausentes)) {
  stop("O leiaute CAPES mudou; campos ausentes: ", paste(ausentes, collapse = ", "), call. = FALSE)
}

area_alvo <- "CIÊNCIA POLÍTICA E RELAÇÕES INTERNACIONAIS"
base_area <- programas_raw |>
  filter(AN_BASE == as.character(ano_base), NM_AREA_AVALIACAO == area_alvo) |>
  filter(DS_SITUACAO_PROGRAMA == "EM FUNCIONAMENTO")

if (!nrow(base_area)) stop("Nenhum programa ativo encontrado na área-alvo para ", ano_base, call. = FALSE)
if (anyDuplicated(base_area$CD_PROGRAMA_IES)) {
  stop("O CSV contém códigos CAPES duplicados na área-alvo; revise a granularidade antes de importar.", call. = FALSE)
}

grau <- stringr::str_to_upper(stringr::str_squish(base_area$NM_GRAU_PROGRAMA))
modalidade <- stringr::str_to_upper(stringr::str_squish(base_area$NM_MODALIDADE_PROGRAMA))
nome <- stringr::str_squish(base_area$NM_PROGRAMA_IES)
sugestao_subarea <- dplyr::case_when(
  stringr::str_detect(stringr::str_to_lower(nome), "rela[cç][õo]es internacionais|international") ~ "RI",
  stringr::str_detect(stringr::str_to_lower(nome), "ci[eê]ncia pol[ií]tica|pol[ií]ticas p[uú]blicas") ~ "CP",
  TRUE ~ "CP+RI"
)

subarea_manual <- readr::read_csv(
  file.path(raiz, "data", "manual", "subarea.csv"),
  col_types = readr::cols(.default = readr::col_character()),
  na = c("", "NA"), show_col_types = FALSE
)

programas <- tibble::tibble(
  id_capes = base_area$CD_PROGRAMA_IES,
  nome = nome,
  ies_sigla = base_area$SG_ENTIDADE_ENSINO,
  municipio = base_area$NM_MUNICIPIO_PROGRAMA_IES,
  uf = base_area$SG_UF_PROGRAMA,
  subarea_sugerida = sugestao_subarea,
  tem_mestrado = stringr::str_detect(grau, "MESTRADO") & modalidade == "ACADÊMICO",
  tem_mestrado_prof = stringr::str_detect(grau, "MESTRADO") & modalidade == "PROFISSIONAL",
  tem_doutorado = stringr::str_detect(grau, "DOUTORADO"),
  natureza = dplyr::case_when(
    modalidade == "ACADÊMICO" ~ "Acadêmico",
    modalidade == "PROFISSIONAL" ~ "Profissional",
    TRUE ~ "Não informado"
  ),
  url_programa = NA_character_,
  conceito = suppressWarnings(as.integer(base_area$CD_CONCEITO_PROGRAMA))
) |>
  left_join(subarea_manual |> select(id_capes, subarea), by = "id_capes") |>
  mutate(subarea = coalesce(subarea, subarea_sugerida)) |>
  select(-subarea_sugerida)

avaliacoes <- programas |>
  filter(!is.na(conceito)) |>
  transmute(id_capes, ciclo = ciclo_atual, conceito)

ler_manual <- function(nome) {
  readr::read_csv(
    file.path(raiz, "data", "manual", paste0(nome, ".csv")),
    col_types = readr::cols(.default = readr::col_character()),
    na = c("", "NA"), show_col_types = FALSE
  )
}

editais_manual <- ler_manual("editais")
editais <- editais_manual |>
  mutate(
    ano = suppressWarnings(as.integer(ano)),
    inscricao_inicio = as.Date(inscricao_inicio),
    inscricao_fim = as.Date(inscricao_fim),
    vagas = suppressWarnings(as.integer(vagas)),
    verificado_em = as.Date(verificado_em)
  )

linhas <- ler_manual("linhas_pesquisa") |>
  mutate(verificado_em = as.Date(verificado_em))

coordenadas <- ler_manual("coordenadas") |>
  mutate(
    latitude = suppressWarnings(as.numeric(latitude)),
    longitude = suppressWarnings(as.numeric(longitude)),
    verificado_em = as.Date(verificado_em)
  )

ranking_conceito <- programas |>
  select(id_capes, nome, ies_sigla, uf, subarea, tem_mestrado, tem_mestrado_prof, tem_doutorado) |>
  mutate(
    subarea_rotulo = recode(subarea, CP = "Ciência Política", RI = "Relações Internacionais",
                            `CP+RI` = "Ciência Política e Relações Internacionais"),
    niveis = purrr::pmap_chr(list(tem_mestrado, tem_mestrado_prof, tem_doutorado), function(M, MP, D) {
      paste(c(if (M) "Mestrado acadêmico", if (MP) "Mestrado profissional", if (D) "Doutorado"), collapse = ", ")
    })
  ) |>
  left_join(avaliacoes |> filter(ciclo == ciclo_atual) |> transmute(id_capes, conceito_atual = conceito), by = "id_capes") |>
  mutate(conceito_anterior = NA_integer_, variacao = NA_integer_) |>
  select(id_capes, nome, ies_sigla, uf, subarea_rotulo, niveis,
         conceito_atual, conceito_anterior, variacao)

ranking_produtividade <- programas |>
  transmute(
    id_capes, nome, ies_sigla, uf,
    subarea_rotulo = recode(subarea, CP = "Ciência Política", RI = "Relações Internacionais",
                            `CP+RI` = "Ciência Política e Relações Internacionais"),
    pub_por_docente_ano = NA_real_, titulados_por_docente_ano = NA_real_,
    docentes_medio = NA_real_, posicao = NA_integer_, elegivel = FALSE,
    motivo_exclusao = "Dados de produção ainda não integrados", n_anos = 0L
  )

producao <- tibble::tibble(
  id_capes = character(), ano = integer(), docentes_permanentes = numeric(),
  publicacoes = numeric(), titulados = numeric()
)

parametros <- tibble::tibble(
  janela_inicio = janela_inicio, janela_fim = janela_fim,
  min_anos_com_dados = 3L, min_docentes_medio = 3
)

subareas_revisar <- programas |>
  transmute(id_capes, programa = nome, subarea_atribuida = subarea,
            revisado_manualmente = id_capes %in% subarea_manual$id_capes)

metadados <- tibble::tibble(
  fonte = c("CAPES, Dados Abertos", "Editais (curadoria manual)",
            "Linhas de pesquisa (curadoria manual)", "Coordenadas (curadoria manual)"),
  atualizado_em = as.Date(c(Sys.Date(),
    if (nrow(editais)) max(editais$verificado_em, na.rm = TRUE) else NA,
    if (nrow(linhas)) max(linhas$verificado_em, na.rm = TRUE) else NA,
    if (nrow(coordenadas)) max(coordenadas$verificado_em, na.rm = TRUE) else NA
  ), origin = "1970-01-01"),
  arquivo = c("data/raw/capes_programas_2024.csv", "data/manual/editais.csv",
              "data/manual/linhas_pesquisa.csv", "data/manual/coordenadas.csv")
)

saidas <- list(
  programas = programas |> select(-conceito),
  avaliacoes = avaliacoes,
  editais = editais,
  linhas_pesquisa = linhas,
  coordenadas = coordenadas,
  producao = producao,
  metadados = metadados,
  ranking_conceito = ranking_conceito,
  ranking_produtividade = ranking_produtividade,
  ranking_produtividade_params = parametros,
  subareas_revisar = subareas_revisar
)

purrr::iwalk(saidas, function(tabela, nome) {
  readr::write_csv(tabela, file.path(raiz, "data", "processed", paste0(nome, ".csv")), na = "")
})

source(file.path(raiz, "R", "build_pages.R"), local = TRUE)

data_versao <- format(Sys.Date(), "%d/%m/%Y")
data_iso <- format(Sys.Date(), "%Y-%m-%d")
rodape <- c(
  '<footer class="site-data-footer" aria-label="Atualização dos dados">',
  sprintf('<p>Dados processados em <time datetime="%s">%s</time>. Consulte a metodologia e as datas de conferência de cada fonte.</p>', data_iso, data_versao),
  "</footer>"
)
writeLines(rodape, file.path(raiz, "_includes", "footer.html"), useBytes = TRUE)

validador_path <- file.path(raiz, "R", "validar_dados.R")
if (!file.exists(validador_path)) {
  stop("Arquivo de validação não encontrado: ", validador_path, call. = FALSE)
}
source(validador_path, local = FALSE)

cat(nrow(programas), "programas ativos importados para a área; arquivos gravados em data/processed/.\n")
cat("Fonte: CAPES, [Dados Abertos] (licença CC BY), base ", ano_base, ".\n", sep = "")
if (any(!subareas_revisar$revisado_manualmente)) {
  cat("Revise as classificações sugeridas em data/processed/subareas_revisar.csv e registre correções em data/manual/subarea.csv.\n")
}