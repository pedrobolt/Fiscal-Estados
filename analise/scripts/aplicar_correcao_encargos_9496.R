# =============================================================================
# scripts/aplicar_correcao_encargos_9496.R
# Gera panel_slim_v2_CORRIGIDO.csv com encargos_sobre_rcl_ext recalculado:
#   2002-2014: soma das linhas "1.1.1.1.11 - Lei 9.496/97" e
#              "3.1.1.1.11 - Lei 9.496/97" do arquivo bruto STN
#              (data/raw/siconfi/stn_servico_divida.rds), em vez da linha
#              "DIVIDA TOTAL (Adm. Direta e Indireta)" usada por engano.
#   2015+:     inalterado (SICONFI RREO Anexo 6 nao permite segregar por
#              credor — limitacao documentada, sem correcao possivel).
#
# NAO sobrescreve data/processed/panel_slim_v2.csv nem output/tables/*.
# Gera arquivos *_corrigido separados para revisao antes de qualquer
# substituicao definitiva.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(purrr); library(fixest); library(plm)
})

# ---- 1. Ler arquivo bruto STN e extrair Lei 9.496/97 -----------------------
x <- readRDS("data/raw/siconfi/stn_servico_divida.rds")
lines <- strsplit(x, "\r\n", fixed = TRUE, useBytes = TRUE)[[1]]

hdr_fields <- strsplit(lines[3], ";", fixed = TRUE, useBytes = TRUE)[[1]]
state_seq  <- hdr_fields[-c(1,2)]; state_seq <- state_seq[state_seq != ""]
uf_order   <- state_seq[seq(1, length(state_seq), by = 2)]

alvo <- lines[str_detect(lines, fixed("1.1.1.1.11 - Lei 9.496/97")) |
              str_detect(lines, fixed("3.1.1.1.11 - Lei 9.496/97"))]

parse_row <- function(ln) {
  f <- strsplit(ln, ";", fixed = TRUE, useBytes = TRUE)[[1]]
  ano  <- suppressWarnings(as.integer(f[2]))
  vals <- suppressWarnings(as.numeric(str_replace(
            str_replace_all(f[3:(2 + length(uf_order)*2)], "\\.", ""), ",", ".")))
  tibble(year = ano, uf = uf_order, encargos = vals[seq(1, length(vals), by = 2)])
}

encargos_9496 <- map_dfr(alvo, parse_row) %>%
  filter(!is.na(year)) %>%
  group_by(uf, year) %>%
  summarise(encargos_9496 = sum(encargos, na.rm = TRUE) / 1000, .groups = "drop")

cat("encargos_9496 extraido:", nrow(encargos_9496), "obs\n")

# ---- 2. Recalcular encargos_sobre_rcl_ext no painel completo ---------------
painel_full <- read_csv("data/processed/panel_final_v5.csv", show_col_types = FALSE)

painel_full <- painel_full %>%
  left_join(encargos_9496, by = c("uf", "year")) %>%
  mutate(
    encargos_sobre_rcl_ext_CORR = if_else(
      year <= 2014,
      encargos_9496 / rcl_ext,
      encargos_ext / rcl_ext   # 2015+: inalterado — sem segregacao possivel na fonte SICONFI
    )
  ) %>%
  select(uf, year, encargos_sobre_rcl_ext_CORR)

# ---- 3. Aplicar a correcao no panel_slim_v2 (so a coluna de encargos) ------
slim <- read_csv("data/processed/panel_slim_v2.csv", show_col_types = FALSE)

slim_corrigido <- slim %>%
  left_join(painel_full, by = c("uf", "year")) %>%
  mutate(encargos_sobre_rcl_ext = coalesce(encargos_sobre_rcl_ext_CORR, encargos_sobre_rcl_ext)) %>%
  select(-encargos_sobre_rcl_ext_CORR)

stopifnot(nrow(slim_corrigido) == nrow(slim))
write_csv(slim_corrigido, "data/processed/panel_slim_v2_CORRIGIDO.csv")
cat("OK data/processed/panel_slim_v2_CORRIGIDO.csv gerado (", nrow(slim_corrigido), "obs )\n")
cat("  (panel_slim_v2.csv original NAO foi alterado)\n\n")

# ---- 4. Regenerar tabela_final (mesma logica de scripts/06_tables.R), ------
#         so trocando a fonte de dados e o nome do arquivo de saida ----------
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
set.seed(2025)

run_tabela_final <- function(panel, sufixo) {
  panel <- panel %>%
    arrange(uf, year) %>% group_by(uf) %>%
    mutate(dcl_lag1 = dplyr::lag(dcl_sobre_rcl_ext, 1)) %>% ungroup() %>%
    mutate(
      teto_frac = teto / 100,
      binding   = as.integer(!is.na(encargos_sobre_rcl_ext) & !is.na(teto_frac) &
                              (encargos_sobre_rcl_ext / teto_frac) > 0.70),
      d_lag1_teto_binding = d_lag1 * teto * binding,
      d_lag2_teto_binding = d_lag2 * teto * binding
    )

  m_ols <- feols(primario_sobre_rcl_ext ~ d_lag1 + d_lag1_teto + yvar | uf + year,
                 data = panel, cluster = ~uf)
  m_iv  <- feols(primario_sobre_rcl_ext ~ yvar | uf + year |
                   d_lag1 + d_lag1_teto ~ d_lag2 + d_lag2_teto,
                 data = panel, cluster = ~uf)
  fs_iv <- fitstat(m_iv, "ivf"); wh_iv <- fitstat(m_iv, "wh")[[1]]$p

  m_dk  <- feols(dcl_sobre_rcl_ext ~ dcl_lag1 + primario_sobre_rcl_ext +
                   crescimento_pib_pct | uf + year,
                 data = panel, panel.id = ~uf + year, vcov = "DK")

  panel_rob3 <- panel %>%
    filter(!is.na(primario_sobre_rcl_ext), !is.na(d_lag1), !is.na(d_lag2),
           !is.na(d_lag1_teto), !is.na(d_lag2_teto),
           !is.na(d_lag1_teto_binding), !is.na(d_lag2_teto_binding), !is.na(yvar))
  m_rob3 <- feols(
    primario_sobre_rcl_ext ~ yvar | uf + year |
      d_lag1 + d_lag1_teto + d_lag1_teto_binding ~
      d_lag2 + d_lag2_teto + d_lag2_teto_binding,
    data = panel_rob3, cluster = ~uf)
  fs_r3 <- fitstat(m_rob3, "ivf"); wh_r3 <- fitstat(m_rob3, "wh")[[1]]$p

  run_lsdvc <- function(panel_l, third_var, B = 500) {
    panel_p <- plm::pdata.frame(panel_l, index = c("uf", "year"))
    N <- n_distinct(panel_l$uf); T_bar <- nrow(panel_l) / N
    fml    <- as.formula(paste0("dcl_sobre_rcl_ext ~ lag(dcl_sobre_rcl_ext,1) + primario_sobre_rcl_ext + ", third_var))
    fml_iv <- as.formula(paste0("dcl_sobre_rcl_ext ~ lag(dcl_sobre_rcl_ext,1) + primario_sobre_rcl_ext + ", third_var,
                                 " | lag(dcl_sobre_rcl_ext,2:3) + lag(primario_sobre_rcl_ext,2:3)"))
    m_w  <- plm::plm(fml, data = panel_p, model = "within", effect = "individual")
    b_w  <- coef(m_w)
    m_ab <- suppressWarnings(plm::pgmm(fml_iv, data = panel_p, effect = "individual",
                                   model = "onestep", transformation = "d", collapse = TRUE))
    rho_AB <- coef(summary(m_ab, robust = TRUE))["lag(dcl_sobre_rcl_ext, 1)", "Estimate"]
    b_c  <- b_w
    b_c["lag(dcl_sobre_rcl_ext, 1)"] <- b_w["lag(dcl_sobre_rcl_ext, 1)"] + (1 + rho_AB) / (T_bar - 1)
    states <- unique(panel_l$uf); vn <- names(b_c)
    boot <- matrix(NA_real_, B, 3, dimnames = list(NULL, vn))
    for (b in seq_len(B)) {
      s_b  <- sample(states, N, replace = TRUE)
      df_b <- lapply(seq_along(s_b), function(i)
        panel_l[panel_l$uf == s_b[i], ] %>% mutate(uf = paste0("g", i))) %>% bind_rows()
      pp_b <- plm::pdata.frame(df_b, index = c("uf", "year"))
      ft   <- tryCatch(plm::plm(fml, data = pp_b, model = "within", effect = "individual"), error = function(e) NULL)
      if (is.null(ft) || length(coef(ft)) != 3) next
      rho_b <- tryCatch({
        ab_b <- suppressWarnings(plm::pgmm(fml_iv, data = pp_b, effect = "individual",
                                       model = "onestep", transformation = "d", collapse = TRUE))
        coef(ab_b)["lag(dcl_sobre_rcl_ext, 1)"]
      }, error = function(e) rho_AB)
      cb <- coef(ft)
      cb["lag(dcl_sobre_rcl_ext, 1)"] <- cb["lag(dcl_sobre_rcl_ext, 1)"] + (1 + rho_b) / (T_bar - 1)
      boot[b, ] <- cb
    }
    boot <- boot[complete.cases(boot), ]; bse <- apply(boot, 2, sd)
    dof  <- nrow(panel_l) - N - 3
    pv   <- function(v) 2 * pt(-abs(b_c[v] / bse[v]), df = dof)
    list(coef = b_c, se = bse, pval = pv, nobs = nrow(panel_l), nboot = nrow(boot))
  }

  cat("  [", sufixo, "] LSDVC baseline (B=500)...\n")
  lsdvc3 <- run_lsdvc(panel %>% filter(!is.na(dcl_sobre_rcl_ext), !is.na(primario_sobre_rcl_ext), !is.na(crescimento_pib_pct)), "crescimento_pib_pct")
  cat("  [", sufixo, "] LSDVC Rob1/yvar (B=500)...\n")
  lsdvc5 <- run_lsdvc(panel %>% filter(!is.na(dcl_sobre_rcl_ext), !is.na(primario_sobre_rcl_ext), !is.na(yvar)), "yvar")

  mk_stars <- function(p) ifelse(p<0.01,"***",ifelse(p<0.05,"**",ifelse(p<0.10,"*","")))
  fc    <- function(est,se,p) list(coef=sprintf("%.3f%s",est,mk_stars(p)), se=sprintf("(%.3f)",se))
  fc4   <- function(est,se,p) list(coef=sprintf("%.4f%s",est,mk_stars(p)), se=sprintf("(%.4f)",se))
  blank <- list(coef="", se="")
  gf    <- function(mod,var) { if (!var %in% names(coef(mod))) return(blank); fc(coef(mod)[var],se(mod)[var],pvalue(mod)[var]) }
  gf4   <- function(mod,var) { if (!var %in% names(coef(mod))) return(blank); fc4(coef(mod)[var],se(mod)[var],pvalue(mod)[var]) }
  gl    <- function(ls,var)  { b<-ls$coef; s<-ls$se; pv<-ls$pval; if (!var %in% names(b)) return(blank); fc(b[var],s[var],pv(var)) }

  cn <- c(" ","I-A: MQO-EF","I-B: 2SLS","II-A: LSDVC","II-B: EF+DK",
          "Rob1: LSDVC-yvar","Rob3: Binding")

  rows <- list(
    list(label="DCL/RCL (t-1)",
         c1=gf(m_ols,"d_lag1"),       c2=gf(m_iv,"fit_d_lag1"),
         c3=gl(lsdvc3,"lag(dcl_sobre_rcl_ext, 1)"),
         c4=gf(m_dk,"dcl_lag1"),
         c5=gl(lsdvc5,"lag(dcl_sobre_rcl_ext, 1)"),
         c6=gf(m_rob3,"fit_d_lag1")),
    list(label="DCL/RCL (t-1) x Teto",
         c1=gf(m_ols,"d_lag1_teto"),  c2=gf(m_iv,"fit_d_lag1_teto"),
         c3=blank, c4=blank, c5=blank,
         c6=gf(m_rob3,"fit_d_lag1_teto")),
    list(label="DCL/RCL (t-1) x Teto x Binding",
         c1=blank, c2=blank, c3=blank, c4=blank, c5=blank,
         c6=gf4(m_rob3,"fit_d_lag1_teto_binding")),
    list(label="Hiato do produto",
         c1=gf(m_ols,"yvar"),         c2=gf(m_iv,"yvar"),
         c3=blank, c4=blank,          c5=gl(lsdvc5,"yvar"),
         c6=gf(m_rob3,"yvar")),
    list(label="Primario/RCL",
         c1=blank, c2=blank,
         c3=gl(lsdvc3,"primario_sobre_rcl_ext"),
         c4=gf(m_dk,"primario_sobre_rcl_ext"),
         c5=gl(lsdvc5,"primario_sobre_rcl_ext"),
         c6=blank),
    list(label="Crescimento PIB (%)",
         c1=blank, c2=blank,
         c3=gl(lsdvc3,"crescimento_pib_pct"),
         c4=gf(m_dk,"crescimento_pib_pct"),
         c5=blank, c6=blank)
  )

  build_df <- function(rows, cn) {
    out <- list()
    for (r in rows) {
      out[[length(out)+1]] <- setNames(c(r$label,r$c1$coef,r$c2$coef,r$c3$coef,r$c4$coef,r$c5$coef,r$c6$coef), cn)
      out[[length(out)+1]] <- setNames(c("",r$c1$se,r$c2$se,r$c3$se,r$c4$se,r$c5$se,r$c6$se), cn)
    }
    as.data.frame(do.call(rbind, out), stringsAsFactors=FALSE)
  }
  df_coef <- build_df(rows, cn)

  df_gof <- tribble(
    ~` `,~`I-A: MQO-EF`,~`I-B: 2SLS`,~`II-A: LSDVC`,~`II-B: EF+DK`,
          ~`Rob1: LSDVC-yvar`,~`Rob3: Binding`,
    "Obs.",
      as.character(m_ols$nobs), as.character(m_iv$nobs),
      as.character(lsdvc3$nobs), as.character(m_dk$nobs),
      as.character(lsdvc5$nobs), as.character(m_rob3$nobs),
    "R2 within",
      as.character(round(r2(m_ols,"wr2"),3)), "-", "-",
      as.character(round(r2(m_dk,"wr2"),3)), "-", "-",
    "F-stat 1o estagio",
      "-",
      sprintf("%.0f/%.0f", fs_iv[[1]]$stat, fs_iv[[2]]$stat),
      "-", "-", "-",
      sprintf("%.0f/%.0f/%.0f", fs_r3[[1]]$stat, fs_r3[[2]]$stat, fs_r3[[3]]$stat),
    "Wu-Hausman (p)",
      "-", sprintf("%.4f",wh_iv), "-", "-", "-",
      sprintf("%.4f",wh_r3),
    "Bootstrap B=500",
      "-","-","Sim","-","Sim","-",
    "Correcao Nickell",
      "-","-","Sim","-","Sim","-",
    "EF Estado",  "Sim","Sim","Sim","Sim","Sim","Sim",
    "EF Ano",     "Sim","Sim","Nao","Sim","Nao","Sim"
  )

  df_full <- bind_rows(df_coef, df_gof); names(df_full)[1] <- " "

  note <- paste(
    "Erros padrao clusterizados por estado entre parenteses (Modelos I e Rob).",
    "Bootstrap com B=500 replicacoes (Modelos II LSDVC).",
    "System-GMM two-way FE inviavel com N=25 - substituido por LSDVC (Bruno, 2005).",
    "Rob3: binding=1 se encargos/(teto/100)>0,70; inclui tripla interacao d x teto x binding.",
    "encargos_sobre_rcl_ext CORRIGIDO (2002-2014: linha Lei 9.496/97 da fonte STN, nao mais DIVIDA TOTAL).",
    "Amostra: 25 estados brasileiros (excl. AP e TO), 2002-2024.",
    "* p<0,1  ** p<0,05  *** p<0,01.")

  tex_out <- df_full %>%
    kableExtra::kbl(format="latex",booktabs=TRUE,escape=TRUE,linesep="",
        caption=paste("Sustentabilidade Fiscal e Regras de Endividamento",
                      "--- Painel de Estados Brasileiros (2002--2024) [encargos CORRIGIDO]"),
        label="tab:resultados6corrigido") %>%
    kableExtra::kable_styling(latex_options=c("hold_position","scale_down")) %>%
    kableExtra::add_header_above(c(" "=1,"Dep.: Primario/RCL"=2,"Dep.: DCL/RCL"=3,
                       "Dep.: Primario/RCL"=1)) %>%
    kableExtra::add_header_above(c(" "=1,"Modelos Principais"=4,"Verificacoes de Robustez"=2)) %>%
    kableExtra::footnote(general=note,general_title="",footnote_as_chunk=TRUE,threeparttable=TRUE)

  out_path <- sprintf("output/tables/tabela_final_%s.tex", sufixo)
  writeLines(as.character(tex_out), out_path)
  cat("OK", out_path, "\n")

  list(m_rob3 = m_rob3, panel_rob3 = panel_rob3, path = out_path)
}

cat("\n=== Regenerando tabela_final ORIGINAL (para diff, mesma logica) ===\n")
res_orig <- run_tabela_final(slim, "ATUAL_reproduzida")

cat("\n=== Regenerando tabela_final CORRIGIDA (encargos = Lei 9.496/97) ===\n")
res_corr <- run_tabela_final(slim_corrigido, "corrigido")

cat("\n================================================================\n")
cat(" Rob3/Binding - beta3 ATUAL(reproduzida) vs CORRIGIDA\n")
cat("================================================================\n")
b3a <- coef(res_orig$m_rob3)["fit_d_lag1_teto_binding"]; p3a <- pvalue(res_orig$m_rob3)["fit_d_lag1_teto_binding"]
b3c <- coef(res_corr$m_rob3)["fit_d_lag1_teto_binding"]; p3c <- pvalue(res_corr$m_rob3)["fit_d_lag1_teto_binding"]
cat(sprintf("ATUAL     : beta3=%.4f p=%.4f N=%d\n", b3a, p3a, res_orig$m_rob3$nobs))
cat(sprintf("CORRIGIDO : beta3=%.4f p=%.4f N=%d\n", b3c, p3c, res_corr$m_rob3$nobs))
cat("\nNenhum arquivo original (panel_slim_v2.csv, output/tables/tabela_final.tex,\n")
cat("tabela_rob4_dummy_teto.tex) foi sobrescrito.\n")
