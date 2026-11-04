# Dados manuais

Preencha os CSVs desta pasta sem alterar seus nomes de coluna. Use UTF-8,
separador vírgula e datas no formato `AAAA-MM-DD`. Não inclua dados pessoais.

- `subarea.csv`: classificação do projeto (`CP`, `RI` ou `CP+RI`) para cada
  `id_capes`; ao preencher uma classificação, informe também justificativa e
  `verificado_em`.
- `coordenadas.csv`: latitude e longitude em graus decimais; latitude sul e
  longitude oeste são negativas. Informe a fonte usada para localizar o
  programa e a data `verificado_em`.
- `editais.csv`: uma linha por processo seletivo. `id_edital` deve ser único;
  `nivel` aceita `M`, `MP` ou `D`. Para uma previsão sem datas confirmadas,
  deixe as duas datas de inscrição vazias e preencha `previsao_texto`. Toda
  linha precisa de `verificado_em`.
- `linhas_pesquisa.csv`: uma linha por linha de pesquisa. Registre a página
  consultada em `url_fonte` e a data da verificação em `verificado_em`.

O identificador `id_capes` deve corresponder ao cadastro processado de
programas. Rode `Rscript R/build_data.R` na raiz do projeto para importar a
base oficial da CAPES e combinar os CSVs manuais. Depois rode
`Rscript R/validar_dados.R` antes de renderizar. O validador verifica
estrutura, valores, datas e vínculos.

A classificação de subárea produzida pelo importador é uma sugestão baseada
no nome do programa, não uma classificação oficial da CAPES. Confira
`data/processed/subareas_revisar.csv` e registre cada revisão em
`subarea.csv`.

O arquivo CAPES usado é o conjunto [Programas da Pós-Graduação Stricto Sensu
no Brasil](https://dadosabertos.capes.gov.br/dataset/2021-a-2024-programas-da-pos-graduacao-stricto-sensu-no-brasil),
base 2024, publicado em 01/12/2025 sob licença CC BY. O importador salva a
cópia original em `data/raw/` para manter o processamento reproduzível. O
ranking de produtividade permanece sem classificação até que docentes,
produção e titulados sejam integrados e validados.