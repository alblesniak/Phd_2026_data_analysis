# =============================================================================
# 03_evaluate_comparison.R - Evaluate and compare gender prediction models
# =============================================================================
# Compares:
#   1) Baseline (Python script) — stored in users.pred_gender
#   2) New R algorithm — from 02_predict_gender.R output
# Against Ground Truth — users.gender (where 'M' or 'K')
#
# Metrics: Accuracy, Precision, Recall, F1, Coverage
# Outputs: comparison tables, confusion matrix plots, coverage gain analysis
# =============================================================================

library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)
library(scales)
library(here)
library(DBI)

# --- Reuse shared helpers (theme, save_plot, save_table, fmt_number) ---
source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

# --- Database connection ---
source(here::here("00_basic_corpus_statistics", "scripts", "db_connection.R"))

message("\n=== EWALUACJA I POROWNANIE MODELI PREDYKCJI PLCI ===")
message("Start: ", Sys.time())

# =============================================================================
# 1) Load data
# =============================================================================

# Ground truth + baseline from database
users_db_raw <- dbGetQuery(con, "
  SELECT
    id AS user_id,
    gender AS ground_truth,
    pred_gender AS baseline_pred
  FROM users
") |> as_tibble()

# FIX: Convert integer64 to numeric to match CSV input type later
users_db <- users_db_raw |>
  mutate(user_id = as.numeric(user_id))

dbDisconnect(con)
message("Polaczenie z baza zamkniete.")

# New predictions
new_pred_path <- here::here("01_gender_prediction_improvement", "output",
                             "data", "new_gender_predictions.csv")
if (!file.exists(new_pred_path)) {
  stop("Brak pliku predykcji. Uruchom najpierw 02_predict_gender.R")
}

new_predictions <- read_csv(new_pred_path, show_col_types = FALSE) |>
  select(user_id, new_pred_gender)

# =============================================================================
# 2) Normalize labels and merge
# =============================================================================

# Standardize ground truth: keep only known genders (M, K)
# Standardize predictions to "male" / "female" / "unknown"
eval_data <- users_db |>
  left_join(new_predictions, by = "user_id") |>
  mutate(
    # Ground truth normalization
    gt = case_when(
      ground_truth == "M" ~ "male",
      ground_truth == "K" ~ "female",
      TRUE                ~ NA_character_   # no ground truth
    ),
    # Baseline normalization (from Python: "male"/"female"/"unknown"/NA)
    bl = case_when(
      baseline_pred %in% c("male", "M")      ~ "male",
      baseline_pred %in% c("female", "K")     ~ "female",
      TRUE                                    ~ "unknown"
    ),
    # New prediction (already standardized)
    nw = coalesce(new_pred_gender, "unknown")
  )

n_with_gt <- sum(!is.na(eval_data$gt))
message("Uzytkownikow z ground truth (gender = M lub K): ", n_with_gt)
message("Lacznie uzytkownikow: ", nrow(eval_data))

# =============================================================================
# 3) Metric computation helper
# =============================================================================

compute_metrics <- function(truth, predicted, model_name) {
  # Filter to users where we have ground truth AND the model made a prediction
  df <- tibble(truth = truth, pred = predicted) |>
    filter(!is.na(truth))

  n_gt       <- nrow(df)
  n_pred     <- sum(df$pred != "unknown")
  coverage   <- n_pred / n_gt

  # Among predicted users, compute binary metrics per class
  df_pred <- df |> filter(pred != "unknown")

  if (nrow(df_pred) == 0) {
    return(tibble(
      model     = model_name,
      coverage  = 0,
      accuracy  = NA_real_,
      precision_M = NA_real_, recall_M = NA_real_, f1_M = NA_real_,
      precision_K = NA_real_, recall_K = NA_real_, f1_K = NA_real_,
      macro_precision = NA_real_, macro_recall = NA_real_, macro_f1 = NA_real_
    ))
  }

  accuracy <- mean(df_pred$truth == df_pred$pred)

  # Per-class metrics
  calc_class <- function(class_label) {
    tp <- sum(df_pred$truth == class_label & df_pred$pred == class_label)
    fp <- sum(df_pred$truth != class_label & df_pred$pred == class_label)
    fn <- sum(df_pred$truth == class_label & df_pred$pred != class_label)
    precision <- if ((tp + fp) > 0) tp / (tp + fp) else NA_real_
    recall    <- if ((tp + fn) > 0) tp / (tp + fn) else NA_real_
    f1        <- if (!is.na(precision) && !is.na(recall) && (precision + recall) > 0)
                   2 * precision * recall / (precision + recall) else NA_real_
    list(precision = precision, recall = recall, f1 = f1)
  }

  m_M <- calc_class("male")
  m_K <- calc_class("female")

  tibble(
    model           = model_name,
    n_ground_truth  = n_gt,
    n_predicted     = n_pred,
    coverage        = round(coverage * 100, 2),
    accuracy        = round(accuracy * 100, 2),
    precision_M     = round(m_M$precision * 100, 2),
    recall_M        = round(m_M$recall * 100, 2),
    f1_M            = round(m_M$f1 * 100, 2),
    precision_K     = round(m_K$precision * 100, 2),
    recall_K        = round(m_K$recall * 100, 2),
    f1_K            = round(m_K$f1 * 100, 2),
    macro_precision = round(mean(c(m_M$precision, m_K$precision), na.rm = TRUE) * 100, 2),
    macro_recall    = round(mean(c(m_M$recall, m_K$recall), na.rm = TRUE) * 100, 2),
    macro_f1        = round(mean(c(m_M$f1, m_K$f1), na.rm = TRUE) * 100, 2)
  )
}

# =============================================================================
# 4) Compute metrics for both models
# =============================================================================

metrics_baseline <- compute_metrics(eval_data$gt, eval_data$bl, "Baseline (Python)")
metrics_new      <- compute_metrics(eval_data$gt, eval_data$nw, "New R Algorithm")

metrics_comparison <- bind_rows(metrics_baseline, metrics_new)

message("\n--- POROWNANIE METRYK (na uzytkownikach z ground truth) ---")
metrics_comparison |>
  mutate(across(where(is.numeric), ~ ifelse(is.na(.x), "N/A", paste0(.x)))) |>
  as.data.frame() |>
  print()

# =============================================================================
# 5) Coverage gain analysis
# =============================================================================

coverage_analysis <- eval_data |>
  mutate(
    bl_has_pred = bl != "unknown",
    nw_has_pred = nw != "unknown"
  ) |>
  summarise(
    total_users         = n(),
    baseline_predicted  = sum(bl_has_pred),
    new_predicted       = sum(nw_has_pred),
    coverage_gain       = sum(!bl_has_pred & nw_has_pred),
    coverage_lost       = sum(bl_has_pred & !nw_has_pred),
    both_predicted      = sum(bl_has_pred & nw_has_pred),
    agreement           = sum(bl_has_pred & nw_has_pred & bl == nw),
    disagreement        = sum(bl_has_pred & nw_has_pred & bl != nw)
  )

message("\n--- ANALIZA POKRYCIA ---")
message("Lacznie uzytkownikow:               ", coverage_analysis$total_users)
message("Baseline predykowane:                ", coverage_analysis$baseline_predicted)
message("Nowy algorytm predykowane:           ", coverage_analysis$new_predicted)
message("Przyrost pokrycia (gain):            ", coverage_analysis$coverage_gain,
        " uzytkownikow (baseline=unknown, nowy=znany)")
message("Utrata pokrycia:                     ", coverage_analysis$coverage_lost,
        " uzytkownikow (baseline=znany, nowy=unknown)")
message("Oba modele predykuja:                ", coverage_analysis$both_predicted)
message("  Zgodnosc:                          ", coverage_analysis$agreement)
message("  Niezgodnosc:                       ", coverage_analysis$disagreement)

# Coverage gain with ground truth check
gain_users <- eval_data |>
  filter(bl == "unknown", nw != "unknown")

gain_with_gt <- gain_users |>
  filter(!is.na(gt))

if (nrow(gain_with_gt) > 0) {
  gain_accuracy <- mean(gain_with_gt$gt == gain_with_gt$nw) * 100
  message("\nPrzyrost pokrycia z ground truth: ", nrow(gain_with_gt), " uzytkownikow")
  message("  Dokladnosc na tych uzytkownikach: ", round(gain_accuracy, 1), "%")
}

# =============================================================================
# 6) Confusion matrix data (for users with ground truth)
# =============================================================================

# Function to build confusion matrix tibble
build_confusion <- function(truth, predicted, model_name) {
  tibble(truth = truth, pred = predicted) |>
    filter(!is.na(truth), pred != "unknown") |>
    count(truth, pred) |>
    mutate(model = model_name)
}

cm_baseline <- build_confusion(eval_data$gt, eval_data$bl, "Baseline (Python)")
cm_new      <- build_confusion(eval_data$gt, eval_data$nw, "Nowy algorytm R")

cm_combined <- bind_rows(cm_baseline, cm_new) |>
  mutate(
    truth_label = case_match(truth, "male" ~ "Mezczyzna", "female" ~ "Kobieta"),
    pred_label  = case_match(pred,  "male" ~ "Mezczyzna", "female" ~ "Kobieta")
  )

# =============================================================================
# 7) Confusion matrix visualization
# =============================================================================

p_confusion <- ggplot(
  cm_combined,
  aes(x = pred_label, y = truth_label, fill = n)
) +
  geom_tile(color = "white", linewidth = 1.2) +
  geom_text(aes(label = format(n, big.mark = " ")),
            size = 5, fontface = "bold", color = "white") +
  facet_wrap(~ model, ncol = 2) +
  scale_fill_gradient(low = "#85C1E9", high = "#1A5276",
                      labels = label_number(big.mark = " ")) +
  labs(
    title    = "Macierz pomylek: porownanie modeli predykcji plci",
    subtitle = "Na podstawie uzytkownikow z deklarowana plcia (ground truth)",
    x        = "Predykcja",
    y        = "Rzeczywista plec (ground truth)",
    fill     = "Liczba\nuzytkownikow",
    caption  = "Zrodlo: users.gender vs predykcje"
  ) +
  theme_academic() +
  theme(
    panel.grid = element_blank(),
    axis.line  = element_blank()
  ) +
  coord_equal()

# Save using the shared helper (outputs to 01_... directory)
plots_dir <- here::here("01_gender_prediction_improvement", "output", "plots")
dir.create(plots_dir, recursive = TRUE, showWarnings = FALSE)

ggsave(
  filename = file.path(plots_dir, "01_confusion_matrix_comparison.png"),
  plot     = p_confusion,
  width    = 12,
  height   = 6,
  dpi      = 300,
  bg       = "white"
)
ggsave(
  filename = file.path(plots_dir, "01_confusion_matrix_comparison.pdf"),
  plot     = p_confusion,
  width    = 12,
  height   = 6
)
message("Zapisano: 01_confusion_matrix_comparison (.png + .pdf)")

# =============================================================================
# 8) Coverage comparison bar chart
# =============================================================================

coverage_bar_data <- tibble(
  model = c("Baseline (Python)", "Nowy algorytm R"),
  predicted   = c(coverage_analysis$baseline_predicted,
                  coverage_analysis$new_predicted),
  unpredicted = c(coverage_analysis$total_users - coverage_analysis$baseline_predicted,
                  coverage_analysis$total_users - coverage_analysis$new_predicted)
) |>
  pivot_longer(cols = c(predicted, unpredicted),
               names_to = "status", values_to = "n_users") |>
  mutate(
    status_label = case_match(status,
      "predicted"   ~ "Predykcja dokonana",
      "unpredicted" ~ "Brak predykcji"
    )
  )

p_coverage <- ggplot(
  coverage_bar_data,
  aes(x = model, y = n_users, fill = status_label)
) +
  geom_col(width = 0.6) +
  geom_text(
    aes(label = format(n_users, big.mark = " ")),
    position = position_stack(vjust = 0.5),
    size     = 4,
    fontface = "bold",
    color    = "white"
  ) +
  scale_fill_manual(values = c(
    "Predykcja dokonana" = "#27AE60",
    "Brak predykcji"     = "#95A5A6"
  )) +
  scale_y_continuous(labels = label_number(big.mark = " ")) +
  labs(
    title    = "Pokrycie predykcji plci: porownanie modeli",
    subtitle = paste0("Lacznie: ",
                      format(coverage_analysis$total_users, big.mark = " "),
                      " uzytkownikow"),
    x        = "Model",
    y        = "Liczba uzytkownikow",
    fill     = "Status",
    caption  = "Zrodlo: users.pred_gender vs nowy algorytm R"
  ) +
  theme_academic()

ggsave(
  filename = file.path(plots_dir, "02_coverage_comparison.png"),
  plot     = p_coverage,
  width    = 9,
  height   = 6,
  dpi      = 300,
  bg       = "white"
)
ggsave(
  filename = file.path(plots_dir, "02_coverage_comparison.pdf"),
  plot     = p_coverage,
  width    = 9,
  height   = 6
)
message("Zapisano: 02_coverage_comparison (.png + .pdf)")

# =============================================================================
# 9) Metrics comparison bar chart
# =============================================================================

metrics_long <- metrics_comparison |>
  select(model, accuracy, macro_precision, macro_recall, macro_f1, coverage) |>
  pivot_longer(cols = -model, names_to = "metric", values_to = "value") |>
  mutate(
    metric_label = case_match(
      metric,
      "accuracy"        ~ "Dokladnosc",
      "macro_precision"  ~ "Precyzja (macro)",
      "macro_recall"     ~ "Czulosc (macro)",
      "macro_f1"         ~ "F1 (macro)",
      "coverage"         ~ "Pokrycie"
    ),
    metric_label = factor(metric_label,
                          levels = c("Pokrycie", "Dokladnosc",
                                     "Precyzja (macro)", "Czulosc (macro)",
                                     "F1 (macro)"))
  )

p_metrics <- ggplot(
  metrics_long,
  aes(x = metric_label, y = value, fill = model)
) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_text(
    aes(label = ifelse(is.na(value), "N/A", paste0(round(value, 1), "%"))),
    position = position_dodge(width = 0.7),
    vjust    = -0.5,
    size     = 3.5,
    fontface = "bold"
  ) +
  scale_fill_manual(values = c(
    "Baseline (Python)" = "#E74C3C",
    "New R Algorithm"    = "#2980B9"
  )) +
  scale_y_continuous(
    limits = c(0, 105),
    labels = label_percent(scale = 1)
  ) +
  labs(
    title    = "Porownanie metryk predykcji plci",
    subtitle = "Ewaluacja na uzytkownikach z deklarowana plcia (ground truth)",
    x        = "Metryka",
    y        = "Wartosc (%)",
    fill     = "Model",
    caption  = "Zrodlo: users.gender jako ground truth"
  ) +
  theme_academic() +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))

ggsave(
  filename = file.path(plots_dir, "03_metrics_comparison.png"),
  plot     = p_metrics,
  width    = 11,
  height   = 6,
  dpi      = 300,
  bg       = "white"
)
ggsave(
  filename = file.path(plots_dir, "03_metrics_comparison.pdf"),
  plot     = p_metrics,
  width    = 11,
  height   = 6
)
message("Zapisano: 03_metrics_comparison (.png + .pdf)")

# =============================================================================
# 10) Save tables
# =============================================================================

tables_dir <- here::here("01_gender_prediction_improvement", "output", "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

# Metrics comparison
write_csv(metrics_comparison,
          file.path(tables_dir, "01_metrics_comparison.csv"))
message("Zapisano: 01_metrics_comparison.csv")

# Coverage analysis
write_csv(coverage_analysis,
          file.path(tables_dir, "02_coverage_analysis.csv"))
message("Zapisano: 02_coverage_analysis.csv")

# Disagreement details (where both models predicted but disagree)
disagreements <- eval_data |>
  filter(bl != "unknown", nw != "unknown", bl != nw) |>
  select(user_id, ground_truth, gt, baseline = bl, new_algorithm = nw)

write_csv(disagreements,
          file.path(tables_dir, "03_disagreements.csv"))
message("Zapisano: 03_disagreements.csv (", nrow(disagreements), " niezgodnosci)")

# Coverage gain details
gain_details <- gain_users |>
  select(user_id, ground_truth, gt, new_prediction = nw)

write_csv(gain_details,
          file.path(tables_dir, "04_coverage_gain_users.csv"))
message("Zapisano: 04_coverage_gain_users.csv (", nrow(gain_details), " uzytkownikow)")

message("\n03_evaluate_comparison.R zakonczone: ", Sys.time())
