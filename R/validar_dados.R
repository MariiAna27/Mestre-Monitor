args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]))
raiz <- normalizePath(file.path(dirname(script_path), ".."))

esquemas <- list(
  subarea = c("id_capes", "subarea", "justificativa", "verificado_em"),
  coordenadas = c("id_capes", "latitude", "longitude", "fonte_url", "verificado_em"),
  editais = c(
    "id_edital", "id_capes", "ano", "nivel", "inscricao_inicio",
    "inscricao_fim", "vagas", "url_edital", "verificado_em", "previsao_texto"
  ),
  linhas_pesquisa = c("id_capes", "linha", "descricao", "url_fonte", "verificado_em", "temas", "metodos")
)

erros <- character()
avisos <- character()
tabelas <- list()

adicionar_erro <- function(mensagem) {
  erros <<- c(erros, mensagem)
}

ler_csv <- function(nome, colunas) {
  caminho <- file.path(raiz, "data", "manual", paste0(nome, ".csv"))
  if (!file.exists(caminho)) {
    adicionar_erro(paste0("Arquivo ausente: ", caminho))
    return(NULL)
  }

  tabela <- tryCatch(
    read.csv(caminho, colClasses = "character", check.names = FALSE,
             na.strings = c("", "NA"), stringsAsFactors = FALSE),
    error = function(e) {
      adicionar_erro(paste0(nome, ".csv: ", conditionMessage(e)))
      NULL
    }
  )
  if (is.null(tabela)) return(NULL)

  faltantes <- setdiff(colunas, names(tabela))
  if (length(faltantes)) {
    adicionar_erro(paste0(nome, ".csv: colunas ausentes: ", paste(faltantes, collapse = ", ")))
    return(NULL)
  }
  tabela
}

validar_obrigatorios <- function(tabela, campos, nome) {
  if (is.null(tabela) || !nrow(tabela)) return(invisible(NULL))
  for (campo in campos) {
    vazios <- is.na(tabela[[campo]]) | !nzchar(trimws(tabela[[campo]]))
    if (any(vazios)) {
      adicionar_erro(sprintf("%s.csv: %s vazio nas linhas %s", nome, campo,
                             paste(which(vazios) + 1L, collapse = ", ")))
    }
  }
}

validar_chave <- function(tabela, campos, nome) {
  if (is.null(tabela) || !nrow(tabela)) return(invisible(NULL))
  repetidas <- duplicated(tabela[campos]) | duplicated(tabela[campos], fromLast = TRUE)
  if (any(repetidas)) {
    adicionar_erro(sprintf("%s.csv: chave duplicada (%s) nas linhas %s", nome,
                           paste(campos, collapse = ", "),
                           paste(which(repetidas) + 1L, collapse = ", ")))
  }
}

validar_data <- function(tabela, campo, nome) {
  if (is.null(tabela) || !nrow(tabela)) return(invisible(NULL))
  valores <- tabela[[campo]]
  preenchidos <- !is.na(valores) & nzchar(trimws(valores))
  datas <- suppressWarnings(as.Date(valores, format = "%Y-%m-%d"))
  invalidas <- preenchidos & (is.na(datas) | format(datas, "%Y-%m-%d") != valores)
  if (any(invalidas)) {
    adicionar_erro(sprintf("%s.csv: %s deve usar AAAA-MM-DD (linhas %s)", nome, campo,
                           paste(which(invalidas) + 1L, collapse = ", ")))
  }
  datas
}

validar_url <- function(tabela, campo, nome) {
  if (is.null(tabela) || !nrow(tabela)) return(invisible(NULL))
  valores <- tabela[[campo]]
  preenchidos <- !is.na(valores) & nzchar(trimws(valores))
  invalidos <- preenchidos & !grepl("^https?://[^[:space:]]+$", valores, ignore.case = TRUE)
  if (any(invalidos)) {
    adicionar_erro(sprintf("%s.csv: %s deve ser uma URL http(s) (linhas %s)", nome, campo,
                           paste(which(invalidos) + 1L, collapse = ", ")))
  }
}

validar_etiquetas <- function(tabela, campo, permitidos, nome) {
  if (is.null(tabela) || !nrow(tabela)) return(invisible(NULL))
  invalidas <- vapply(seq_len(nrow(tabela)), function(i) {
    valor <- tabela[[campo]][i]
    if (is.na(valor) || !nzchar(trimws(valor))) return(FALSE)
    etiquetas <- trimws(strsplit(valor, ";", fixed = TRUE)[[1]])
    any(!etiquetas %in% permitidos)
  }, logical(1))
  if (any(invalidas)) {
    adicionar_erro(sprintf("%s.csv: etiqueta inválida em %s nas linhas %s; separe múltiplas etiquetas com ponto e vírgula",
                           nome, campo, paste(which(invalidas) + 1L, collapse = ", ")))
  }
}

for (nome in names(esquemas)) {
  tabelas[[nome]] <- ler_csv(nome, esquemas[[nome]])
}

validar_obrigatorios(tabelas$subarea,
                     c("id_capes", "subarea", "justificativa", "verificado_em"), "subarea")
validar_chave(tabelas$subarea, "id_capes", "subarea")
validar_data(tabelas$subarea, "verificado_em", "subarea")
if (!is.null(tabelas$subarea) && nrow(tabelas$subarea)) {
  valores <- toupper(trimws(tabelas$subarea$subarea))
  invalidos <- !is.na(valores) & !valores %in% c("CP", "RI", "CP+RI")
  if (any(invalidos)) {
    adicionar_erro(sprintf("subarea.csv: subárea inválida nas linhas %s",
                           paste(which(invalidos) + 1L, collapse = ", ")))
  }
}

validar_obrigatorios(tabelas$coordenadas,
                     c("id_capes", "latitude", "longitude", "fonte_url", "verificado_em"), "coordenadas")
validar_chave(tabelas$coordenadas, "id_capes", "coordenadas")
validar_url(tabelas$coordenadas, "fonte_url", "coordenadas")
validar_data(tabelas$coordenadas, "verificado_em", "coordenadas")
if (!is.null(tabelas$coordenadas) && nrow(tabelas$coordenadas)) {
  lat <- suppressWarnings(as.numeric(tabelas$coordenadas$latitude))
  lon <- suppressWarnings(as.numeric(tabelas$coordenadas$longitude))
  invalidas <- is.na(lat) | lat < -90 | lat > 90 | is.na(lon) | lon < -180 | lon > 180
  if (any(invalidas)) {
    adicionar_erro(sprintf("coordenadas.csv: latitude/longitude inválida nas linhas %s",
                           paste(which(invalidas) + 1L, collapse = ", ")))
  }
  fora_do_brasil <- !is.na(lat) & !is.na(lon) & (lat < -34 | lat > 6 | lon < -75 | lon > -32)
  if (any(fora_do_brasil)) {
    adicionar_erro(sprintf("coordenadas.csv: ponto fora dos limites aproximados do Brasil nas linhas %s",
                           paste(which(fora_do_brasil) + 1L, collapse = ", ")))
  }
}

validar_obrigatorios(tabelas$editais,
                     c("id_edital", "id_capes", "ano", "nivel", "verificado_em"), "editais")
validar_chave(tabelas$editais, "id_edital", "editais")
validar_url(tabelas$editais, "url_edital", "editais")
if (!is.null(tabelas$editais) && nrow(tabelas$editais)) {
  edital <- tabelas$editais
  nivel_invalido <- !is.na(edital$nivel) & !edital$nivel %in% c("M", "MP", "D")
  if (any(nivel_invalido)) {
    adicionar_erro(sprintf("editais.csv: nivel deve ser M, MP ou D (linhas %s)",
                           paste(which(nivel_invalido) + 1L, collapse = ", ")))
  }
  ano_invalido <- is.na(edital$ano) | !grepl("^[0-9]{4}$", edital$ano)
  if (any(ano_invalido)) {
    adicionar_erro(sprintf("editais.csv: ano inválido nas linhas %s",
                           paste(which(ano_invalido) + 1L, collapse = ", ")))
  }
  inicio <- validar_data(edital, "inscricao_inicio", "editais")
  fim <- validar_data(edital, "inscricao_fim", "editais")
  validar_data(edital, "verificado_em", "editais")
  vagas <- suppressWarnings(as.numeric(edital$vagas))
  vagas_invalidas <- !is.na(edital$vagas) & nzchar(trimws(edital$vagas)) & (is.na(vagas) | vagas < 0)
  if (any(vagas_invalidas)) {
    adicionar_erro(sprintf("editais.csv: vagas deve ser número não negativo (linhas %s)",
                           paste(which(vagas_invalidas) + 1L, collapse = ", ")))
  }
  inicio_preenchido <- !is.na(edital$inscricao_inicio) & nzchar(trimws(edital$inscricao_inicio))
  fim_preenchido <- !is.na(edital$inscricao_fim) & nzchar(trimws(edital$inscricao_fim))
  datas_incompletas <- inicio_preenchido != fim_preenchido
  if (any(datas_incompletas)) {
    adicionar_erro(sprintf("editais.csv: informe as duas datas de inscrição ou nenhuma (linhas %s)",
                           paste(which(datas_incompletas) + 1L, collapse = ", ")))
  }
  fora_de_ordem <- !is.na(inicio) & !is.na(fim) & inicio > fim
  if (any(fora_de_ordem)) {
    adicionar_erro(sprintf("editais.csv: início posterior ao fim nas linhas %s",
                           paste(which(fora_de_ordem) + 1L, collapse = ", ")))
  }
}

validar_obrigatorios(tabelas$linhas_pesquisa,
                     c("id_capes", "linha", "url_fonte", "verificado_em"), "linhas_pesquisa")
validar_chave(tabelas$linhas_pesquisa, c("id_capes", "linha"), "linhas_pesquisa")
validar_url(tabelas$linhas_pesquisa, "url_fonte", "linhas_pesquisa")
validar_data(tabelas$linhas_pesquisa, "verificado_em", "linhas_pesquisa")
validar_etiquetas(tabelas$linhas_pesquisa, "temas",
                  c("instituicoes-politicas", "comportamento-eleitoral", "politicas-publicas",
                    "teoria-politica", "politica-comparada", "politica-externa", "seguranca-defesa",
                    "economia-politica-internacional", "organizacoes-internacionais", "integracao-regional"),
                  "linhas_pesquisa")
validar_etiquetas(tabelas$linhas_pesquisa, "metodos",
                  c("quantitativo", "qualitativo", "misto", "teoria-normativa"), "linhas_pesquisa")

programas_path <- file.path(raiz, "data", "processed", "programas.csv")
if (file.exists(programas_path)) {
  programas <- tryCatch(
    read.csv(programas_path, colClasses = "character", check.names = FALSE,
             na.strings = c("", "NA"), stringsAsFactors = FALSE),
    error = function(e) {
      adicionar_erro(paste0("programas.csv: ", conditionMessage(e)))
      NULL
    }
  )
  if (!is.null(programas) && !"id_capes" %in% names(programas)) {
    adicionar_erro("data/processed/programas.csv: coluna id_capes ausente")
  } else if (!is.null(programas) && nrow(programas)) {
    validar_chave(programas, "id_capes", "processed/programas")
    ids_programas <- unique(programas$id_capes[!is.na(programas$id_capes)])
    for (nome in names(tabelas)) {
      tabela <- tabelas[[nome]]
      if (is.null(tabela) || !nrow(tabela)) next
      ids <- unique(tabela$id_capes[!is.na(tabela$id_capes)])
      sem_programa <- setdiff(ids, ids_programas)
      if (length(sem_programa)) {
        adicionar_erro(sprintf("%s.csv: id_capes sem correspondência em programas.csv: %s",
                               nome, paste(sem_programa, collapse = ", ")))
      }
    }
  }
} else {
  avisos <- c(avisos, "data/processed/programas.csv ausente; vínculos por id_capes ainda não foram verificados.")
}

if (length(avisos)) cat(paste0("AVISO: ", avisos, collapse = "\n"), "\n")
if (length(erros)) {
  cat(paste0("ERRO: ", erros, collapse = "\n"), "\n")
  quit(status = 1L)
}

cat("Validação estrutural concluída.\n")