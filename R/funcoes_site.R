carregar_dados <- function() {
  list(
    programas = ler_processado("programas"),
    avaliacoes = ler_processado("avaliacoes"),
    editais = ler_processado("editais"),
    linhas = ler_processado("linhas_pesquisa"),
    producao = ler_processado("producao"),
    coordenadas = ler_processado("coordenadas")
  )
}

hoje <- function() Sys.Date()

slug_programa <- function(id_capes) {
  paste0("p-", stringr::str_replace_all(as.character(id_capes), "[^A-Za-z0-9_-]", "-"))
}

rotulo_status <- function(status) {
  dplyr::recode(status, aberta = "Aberta", em_breve = "Abre em breve",
                encerrada = "Encerrada", sem_edital = "Sem edital divulgado", .default = "Sem informação")
}

cor_subarea <- function(subarea) {
  dplyr::case_when(subarea == "CP" ~ COR_CP, subarea == "RI" ~ COR_RI,
                   subarea == "CP+RI" ~ COR_AMBAS, TRUE ~ "#777777")
}

edital_vigente <- function(editais, referencia = hoje()) {
  if (!nrow(editais)) return(mutate(editais, status = character()))

  editais |>
    mutate(
      inscricao_inicio = as.Date(inscricao_inicio),
      inscricao_fim = as.Date(inscricao_fim),
      status = case_when(
        !is.na(inscricao_inicio) & !is.na(inscricao_fim) &
          inscricao_inicio <= referencia & inscricao_fim >= referencia ~ "aberta",
        !is.na(inscricao_inicio) & inscricao_inicio > referencia ~ "em_breve",
        !is.na(inscricao_fim) & inscricao_fim < referencia ~ "encerrada",
        TRUE ~ "sem_edital"
      )
    ) |>
    arrange(desc(status %in% c("aberta", "em_breve")), desc(ano), desc(verificado_em)) |>
    distinct(id_capes, nivel, .keep_all = TRUE)
}

previsoes <- function(editais) {
  if (!nrow(editais)) return(editais)
  editais |>
    filter(!is.na(previsao_texto), nzchar(previsao_texto),
           is.na(inscricao_inicio), is.na(inscricao_fim)) |>
    arrange(desc(ano), desc(verificado_em)) |>
    distinct(id_capes, nivel, .keep_all = TRUE)
}

resumo_programas <- function(dados) {
  programas <- dados$programas
  if (!nrow(programas)) {
    return(tibble::as_tibble(c(esquemas_processados$programas, list(
      niveis = character(), subarea_rotulo = character(), conceito = integer(),
      conceito_anterior = integer(), status = character(), status_rotulo = character(),
      inscricao_inicio = as.Date(character()), inscricao_fim = as.Date(character()),
      vagas = integer(), verificado_em = as.Date(character())
    ))))
  }

  ofertas <- programas |>
    mutate(
      tem_mestrado = coalesce(tem_mestrado, FALSE),
      tem_mestrado_prof = coalesce(tem_mestrado_prof, FALSE),
      tem_doutorado = coalesce(tem_doutorado, FALSE),
      niveis = purrr::pmap_chr(list(tem_mestrado, tem_mestrado_prof, tem_doutorado), function(M, MP, D) {
        paste(c(if (M) "Mestrado acadêmico", if (MP) "Mestrado profissional", if (D) "Doutorado"), collapse = ", ")
      }),
      nivel_foco = case_when(tem_mestrado ~ "M", tem_mestrado_prof ~ "MP", tem_doutorado ~ "D", TRUE ~ NA_character_),
      subarea_rotulo = recode(subarea, CP = "Ciência Política", RI = "Relações Internacionais",
                              `CP+RI` = "Ciência Política e Relações Internacionais", .default = "Não classificada")
    )

  avaliacoes <- dados$avaliacoes
  atual <- avaliacoes |>
    filter(ciclo == cfg$ciclos$atual) |>
    select(id_capes, conceito_atual = conceito)
  anterior <- avaliacoes |>
    filter(ciclo == cfg$ciclos$anterior) |>
    select(id_capes, conceito_anterior = conceito)

  foco <- edital_vigente(dados$editais) |>
    select(all_of(c("id_capes", "nivel", "inscricao_inicio", "inscricao_fim",
                    "vagas", "verificado_em", "status")))

  ofertas |>
    left_join(atual, by = "id_capes") |>
    left_join(anterior, by = "id_capes") |>
    left_join(foco, by = c("id_capes", "nivel_foco" = "nivel")) |>
    mutate(
      conceito = conceito_atual,
      status = coalesce(status, "sem_edital"),
      status_rotulo = rotulo_status(status)
    )
}

dados_mapa <- function(dados) {
  resumo_programas(dados) |>
    inner_join(dados$coordenadas, by = "id_capes") |>
    mutate(
      lat_plot = latitude,
      lon_plot = longitude,
      cor_fill = cor_subarea(subarea),
      cor_borda = if_else(subarea == "CP+RI", COR_CP, cor_fill),
      espessura = if_else(subarea == "CP+RI", 3, 1),
      raio = case_when(status == "aberta" ~ 10, status == "em_breve" ~ 8,
                       status == "encerrada" ~ 6, TRUE ~ 5),
      opac = case_when(status == "aberta" ~ 0.95, status == "em_breve" ~ 0.8,
                       status == "encerrada" ~ 0.55, TRUE ~ 0.35),
      status_rotulo = rotulo_status(status),
      hover = paste(nome, ies_sigla, sep = " — "),
      popup = paste0(
        "<strong>", html_escape(nome), "</strong><br>", html_escape(ies_sigla), " · ",
        html_escape(municipio), "/", html_escape(uf), "<br>", html_escape(subarea_rotulo),
        "<br>Inscrições: ", html_escape(status_rotulo),
        "<br><a href='programas/", slug_programa(id_capes), ".html'>Ver programa</a>"
      )
    )
}