# Monitor de Pós-graduação em Ciência Política e Relações Internacionais

Site estático em Quarto. Os dados CAPES são processados localmente e as
informações de editais, linhas de pesquisa e coordenadas são curadas a partir
das fontes oficiais dos programas.

## Preparar e renderizar

1. Instale o [Quarto](https://quarto.org/docs/get-started/) e o R.
2. Na raiz do projeto, instale os pacotes R necessários:

   ```sh
   Rscript R/instalar_pacotes.R
   ```

3. Gere os CSVs processados e as páginas individuais a partir da publicação CAPES 2024:

   ```sh
   Rscript R/build_data.R
   ```

   Se o CSV já foi baixado manualmente, informe seu caminho:

   ```sh
   CAPES_PROGRAMAS_CSV=/caminho/br-capes-colsucup-prog-2024-2025-12-01.csv Rscript R/build_data.R
   ```

4. Revise as sugestões de subárea em `data/processed/subareas_revisar.csv` e
   registre correções em `data/manual/subarea.csv`. Preencha coordenadas,
   editais e linhas de pesquisa nos demais CSVs de `data/manual/`.
5. Valide e renderize:

   ```sh
   Rscript R/validar_dados.R
   quarto render
   quarto preview
   ```

O CSV CAPES é publicado sob licença CC BY e mantido em `data/raw/` para
reprodutibilidade. O pipeline ainda não integra docentes, produção ou
titulados; por isso, o ranking de produtividade aparece sem classificação
até que essa fonte seja incorporada. O mapa só mostra programas com
coordenadas verificadas.

## Publicar no GitHub Pages

Envie o projeto para um repositório GitHub usando a branch `main`, habilite
Pages com a origem **GitHub Actions** e faça push. O workflow em
`.github/workflows/publish.yml` instala as dependências, atualiza os dados,
valida e publica o site. O processo também pode ser iniciado manualmente pela
aba Actions.