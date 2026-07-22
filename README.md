# Sustentabilidade Fiscal dos Estados Brasileiros

TCC — Bacharelado em Economia, Universidade de Brasília (UnB), 2026
**Autor:** Pedro Leite Tunholi
**Orientador:** Prof. Dr. Vander Mendes Lucas

## Sobre o trabalho

Este trabalho investiga se os estados brasileiros apresentam
reação fiscal sistemática ao endividamento, no sentido de
Bohn (1998), e se essa reação é condicionada pelo grau de
permissividade dos contratos de refinanciamento firmados sob
a Lei nº 9.496/1997. Adaptando a função de reação fiscal de
Abubakar, McCausland e Theodossiou (2025) ao contexto
subnacional brasileiro, estima-se por 2SLS uma especificação
que interage a dívida defasada com o teto contratual de
comprometimento da Receita Corrente Líquida (RCL), em painel
de 25 unidades federativas (2002–2023).

## Estrutura do repositório

```
├── manuscrito/
│   ├── main.tex
│   ├── main.pdf
│   ├── preambulo.tex
│   ├── capitulos/
│   │   ├── 01_introducao.tex
│   │   ├── 02_literatura.tex
│   │   ├── 03_contexto_institucional.tex
│   │   ├── 04_dados_metodologia.tex
│   │   ├── 05_resultados.tex
│   │   ├── 06_conclusao.tex
│   │   └── geral/            # elementos pre-textuais (resumo, epigrafe, etc.)
│   ├── referencias.bib
│   └── abntex2-alf.bst
├── apresentacao/
│   └── apresentacao_defesa_tcc.pdf
└── analise/
    ├── R/                     # funcoes auxiliares e setup
    ├── scripts/               # pipeline (coleta, painel, Modelo I, robustez)
    ├── data/
    │   ├── raw/               # fontes brutas coletadas manualmente
    │   │                        (tetos contratuais, FINBRA historico,
    │   │                         STN Servico da Divida) — demais fontes
    │   │                        (API SICONFI, IBGE, BCB) devem ser
    │   │                        re-obtidas rodando os scripts de coleta
    │   └── processed/
    │       └── panel_slim.csv  # painel final utilizado na estimacao
    ├── output/
    │   ├── figures/           # figuras 1-6 do manuscrito
    │   └── tables/            # tabelas oficiais (descritivas, ROB4)
    └── docs/                  # notas metodologicas
```

## Resultados principais

Estimação por 2SLS com efeitos fixos bidirecionais
(estado e ano):

| Coeficiente | Estimativa | Interpretação |
|---|---|---|
| β1 (DCL/RCL defasada) | 0,644*** | Condição de sustentabilidade de Bohn |
| β2 (DCL/RCL × Teto) | −0,041*** | Teto contratual condiciona a reação |
| N | 500 | |
| F 1º estágio | 972 / 1130 | Instrumentos fortes |

A reação fiscal líquida varia de aproximadamente 0,15 p.p.
(teto de 12%) a 0,03 p.p. (teto de 15%), permanecendo positiva
em todos os grupos.

## Compilando o documento

    cd manuscrito
    pdflatex main.tex
    bibtex main
    pdflatex main.tex
    pdflatex main.tex

Requer distribuição LaTeX com pacote abntex2. O arquivo
`abntex2-alf.bst` incluído está ajustado para exibir citações
conforme a NBR 10520:2023 (inicial maiúscula, não sobrenome
em caixa alta).

## Pipeline de análise (analise/)

Ver a árvore completa em "Estrutura do repositório", acima.
O dicionário de variáveis (`analise/docs/dicionario_variaveis.txt`)
descreve cada coluna de `panel_slim.csv` em detalhe.

### Reproduzindo a análise

    cd analise
    # 1. Rodar scripts de coleta (API) se os dados brutos de
    #    SICONFI/IBGE/BCB não estiverem presentes localmente
    # 2. Rodar os scripts em R/ e scripts/ na ordem numerada
    # 3. O painel final (panel_slim.csv) já está incluído no
    #    repositório para reprodutibilidade imediata dos
    #    resultados sem precisar re-coletar tudo

**Limitações conhecidas:**

- A reconstrução completa do painel a partir de `data/raw/`
  depende de arquivos intermediários (`output/panel_estados_brasil.csv`,
  `output/panel_final_v4.csv`, `output/panel_final_v5.csv`) e de
  uma etapa de montagem de lags/interações que não foram
  versionados neste repositório. `panel_slim.csv` já reflete o
  resultado final dessa transformação — os scripts a partir de
  `03_model1_2sls.R` rodam normalmente sobre ele. Pelo mesmo
  motivo, `scripts/fig1_dcl_rcl_2000_2025.R` (que lê esses
  arquivos intermediários diretamente) também não roda sem essa
  etapa.

### Nota sobre correção de dados

A variável `encargos_sobre_rcl_ext` teve uma correção aplicada
para o período 2002–2014: a extração original utilizava
inadvertidamente a rubrica agregada "Dívida Total" do relatório
de Serviço da Dívida da STN, quando o conceito relevante para
o indicador de *binding* (Capítulo 5) é especificamente o
serviço da dívida federalizada pela Lei nº 9.496/1997. A
correção foi aplicada e está refletida em `panel_slim.csv` —
ver nota 2 em `analise/docs/dicionario_variaveis.txt` para o
detalhamento da extração.
