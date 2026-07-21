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
│   │   └── 06_conclusao.tex
│   ├── pretextuais/
│   ├── referencias.bib
│   └── abntex2-alf.bst
└── apresentacao/
    └── apresentacao_defesa_tcc.pdf
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
